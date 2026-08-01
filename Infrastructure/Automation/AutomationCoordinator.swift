import Foundation

/// Single coordinator for manual, saved, and background automation paths.
/// Maintains exactly one pending BG request for the earliest enabled job.
actor AutomationCoordinator {
    static let taskIdentifier = BGTaskSchedulerClient.taskIdentifier

    private let repository: any AutomationRepository
    private let pipeline: ExportPipeline
    private let scheduler: any BackgroundTaskScheduling
    private let notifications: any NotificationClienting
    private let settingsStore: any SettingsStore
    private let clock: any Clock
    private let calendar: Calendar

    /// Real export task — cancelled on BG expiration (not a void wrapper).
    private var activeExportTask: Task<ExportReport, Never>?
    private var isExecuting = false

    init(
        repository: any AutomationRepository,
        pipeline: ExportPipeline,
        scheduler: any BackgroundTaskScheduling,
        notifications: any NotificationClienting,
        settingsStore: any SettingsStore,
        clock: any Clock = SystemClock(),
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.pipeline = pipeline
        self.scheduler = scheduler
        self.notifications = notifications
        self.settingsStore = settingsStore
        self.clock = clock
        self.calendar = calendar
    }

    // MARK: - CRUD + reconcile

    func loadAutomations() async throws -> [Automation] {
        try await repository.loadAll()
    }

    /// Persist an automation. When `secretStore` is provided, secrets referenced
    /// only by destinations that were removed from this automation (and unused
    /// elsewhere) are deleted after the durable upsert succeeds.
    func save(_ automation: Automation, secretStore: (any SecretStore)? = nil) async throws {
        var item = automation
        item.lastModified = clock.now()
        if item.isEnabled, item.schedule.frequency != .manual {
            item.nextEligibleAt = try ScheduleCalculator.nextEligibleDate(
                for: item.schedule,
                after: clock.now(),
                calendar: calendar
            )
        } else if !item.isEnabled || item.schedule.frequency == .manual {
            item.nextEligibleAt = nil
        }

        let previous = try await repository.automation(id: item.id)
        try await repository.upsert(item)

        var postSaveWarnings: [String] = []
        if let secretStore, let previous {
            do {
                try await pruneUnreferencedSecrets(
                    previous: previous,
                    secretStore: secretStore
                )
            } catch {
                postSaveWarnings.append("Automation saved, but one or more removed Keychain credentials could not be cleaned up.")
            }
        }

        do {
            try await reconcileBackgroundRequest()
        } catch {
            postSaveWarnings.append("Automation saved, but its background refresh request could not be updated.")
        }

        if !postSaveWarnings.isEmpty {
            throw CoordinatorError.savedWithWarnings(postSaveWarnings)
        }
    }

    /// Delete Keychain refs that belonged to `previous` but are no longer
    /// referenced by any automation after the latest upsert.
    private func pruneUnreferencedSecrets(
        previous: Automation,
        secretStore: any SecretStore
    ) async throws {
        let all = try await repository.loadAll()
        let remainingRefs = Set(all.flatMap { auto in
            auto.exportConfig.destinations.flatMap { $0.config.secretReferences.map(\.id) }
        })
        var cleanupFailed = false
        for dest in previous.exportConfig.destinations {
            for ref in dest.config.secretReferences where !remainingRefs.contains(ref.id) {
                do {
                    try await secretStore.delete(reference: ref)
                } catch {
                    cleanupFailed = true
                    AppLogger.persistence.error("Automation saved but Keychain cleanup failed for a removed destination secret")
                }
            }
        }
        if cleanupFailed {
            throw CoordinatorError.secretCleanupFailed
        }
    }

    func delete(id: UUID, secretStore: any SecretStore) async throws {
        var refsToDelete: [SecretReference] = []
        if let existing = try await repository.automation(id: id) {
            // Remove orphaned secrets only when no other automation destination references them
            let all = try await repository.loadAll().filter { $0.id != id }
            let remainingRefs = Set(all.flatMap { auto in
                auto.exportConfig.destinations.flatMap { $0.config.secretReferences.map(\.id) }
            })
            for dest in existing.exportConfig.destinations {
                for ref in dest.config.secretReferences where !remainingRefs.contains(ref.id) {
                    refsToDelete.append(ref)
                }
            }
        }
        // Delete durable configuration first. Cleanup failure can leave an
        // orphan, but cannot leave a saved automation pointing at a deleted key.
        try await repository.delete(id: id)

        var cleanupFailed = false
        for ref in refsToDelete {
            do {
                try await secretStore.delete(reference: ref)
            } catch {
                cleanupFailed = true
                AppLogger.persistence.error("Automation deleted but Keychain cleanup failed")
            }
        }
        try await reconcileBackgroundRequest()
        if cleanupFailed {
            throw CoordinatorError.secretCleanupFailed
        }
    }

    func setEnabled(id: UUID, enabled: Bool) async throws {
        guard var item = try await repository.automation(id: id) else { return }
        item.isEnabled = enabled
        item.lastModified = clock.now()
        if enabled, item.schedule.frequency != .manual {
            item.nextEligibleAt = try ScheduleCalculator.nextEligibleDate(
                for: item.schedule,
                after: clock.now(),
                calendar: calendar
            )
            item.executionStatus = .pending
        } else {
            item.nextEligibleAt = nil
        }
        try await repository.upsert(item)
        try await reconcileBackgroundRequest()
    }

    // MARK: - Execution

    /// Run a saved automation by id.
    func runSaved(id: UUID) async throws -> ExportReport {
        guard var automation = try await repository.automation(id: id) else {
            throw CoordinatorError.notFound
        }
        return await execute(automation: &automation, persist: true)
    }

    /// Run a draft configuration without requiring persistence (Test/Run Draft Now).
    func runDraft(
        name: String,
        config: AutomationExportConfig
    ) async -> ExportReport {
        let request = config.asExportRequest(name: name)
        return await pipeline.run(
            request: request,
            destinations: config.destinations,
            automationID: nil,
            automationName: name
        )
    }

    func executeDueAutomations() async {
        guard !isExecuting else { return }
        isExecuting = true
        defer { isExecuting = false }

        let now = clock.now()
        do {
            try await hydrateMissingScheduleDates()
            let all = try await repository.loadAll()
            let due = all.filter { automation in
                guard automation.isEnabled else { return false }
                guard let next = automation.nextEligibleAt else { return false }
                return next <= now
            }
            for var automation in due {
                _ = await execute(automation: &automation, persist: true)
            }
            try await reconcileBackgroundRequest()
        } catch {
            await recordSchedulingError(error.localizedDescription)
        }
    }

    /// Called when BG task expires — cancel the active export task truthfully.
    func handleExpiration() {
        activeExportTask?.cancel()
    }

    // MARK: - Background reconciliation

    /// Persist computed nextEligibleAt for enabled non-manual jobs missing a date.
    func hydrateMissingScheduleDates() async throws {
        let now = clock.now()
        let all = try await repository.loadAll()
        let (hydrated, changed) = try ScheduleHydration.hydrateMissingDates(
            all,
            now: now,
            calendar: calendar
        )
        guard !changed.isEmpty else { return }
        try await repository.saveAll(hydrated)
    }

    /// Cancel existing request and submit exactly one for the earliest enabled job.
    func reconcileBackgroundRequest() async throws {
        try await hydrateMissingScheduleDates()

        let enabled = try await repository.loadAll().filter {
            $0.isEnabled && $0.schedule.frequency != .manual
        }
        guard !enabled.isEmpty else {
            scheduler.cancel(identifier: Self.taskIdentifier)
            return
        }

        guard let earliest = ScheduleHydration.earliestEligibleDate(in: enabled) else {
            scheduler.cancel(identifier: Self.taskIdentifier)
            return
        }

        // Only cancel after repository reads/calculation succeed. BGTaskScheduler
        // has no atomic replace operation, but this avoids losing a valid pending
        // request merely because persistence was temporarily unreadable.
        scheduler.cancel(identifier: Self.taskIdentifier)
        do {
            try scheduler.submit(
                BackgroundTaskRequest(identifier: Self.taskIdentifier, earliestBeginDate: earliest)
            )
            await recordSchedulingError(nil)
        } catch {
            await recordSchedulingError(error.localizedDescription)
            throw error
        }
    }

    func nextEligibleSummary() async -> (name: String, date: Date)? {
        let all = (try? await repository.loadAll()) ?? []
        let candidates = all.compactMap { auto -> (String, Date)? in
            guard auto.isEnabled, let date = auto.nextEligibleAt else { return nil }
            return (auto.name, date)
        }
        return candidates.min(by: { $0.1 < $1.1 })
    }

    // MARK: - Private

    private func execute(automation: inout Automation, persist: Bool) async -> ExportReport {
        automation.executionStatus = .running
        automation.lastModified = clock.now()
        if persist {
            try? await repository.upsert(automation)
        }

        // Copy all values the escaping Task needs out of the inout parameter
        // before creating the task (Swift forbids capturing inout in escaping closures).
        let request = automation.exportConfig.asExportRequest(name: automation.name)
        let destinations = automation.exportConfig.destinations
        let automationID = automation.id
        let automationName = automation.name

        let task = Task {
            await pipeline.run(
                request: request,
                destinations: destinations,
                automationID: automationID,
                automationName: automationName
            )
        }
        // Store the real export task so BG expiration cancels pipeline work.
        activeExportTask = task
        let report = await task.value
        activeExportTask = nil

        let now = clock.now()
        automation.lastRun = now
        automation.runCount += 1

        switch report.outcome {
        case .completeSuccess, .partialSuccess:
            automation.retryCount = 0
            automation.executionStatus = .completed
            automation.lastError = nil
            automation.nextEligibleAt = try? ScheduleCalculator.nextEligibleDate(
                for: automation.schedule,
                after: now,
                calendar: calendar
            )
        case .cancelled:
            automation.executionStatus = .cancelled
            automation.lastError = "Cancelled or expired"
            // Keep nextEligibleAt so it can retry later without permanent due loop on cancel mid-run
            if automation.nextEligibleAt == nil || automation.nextEligibleAt! <= now {
                automation.nextEligibleAt = ScheduleCalculator.retryDate(retryCount: 1, after: now)
            }
        case .failure:
            automation.retryCount += 1
            automation.lastError = report.errorDescription ?? "Export failed"
            if automation.retryCount >= automation.maxRetries {
                automation.executionStatus = .failed
                automation.nextEligibleAt = try? ScheduleCalculator.nextEligibleDate(
                    for: automation.schedule,
                    after: now,
                    calendar: calendar
                )
            } else {
                automation.executionStatus = .pending
                automation.nextEligibleAt = ScheduleCalculator.retryDate(
                    retryCount: automation.retryCount,
                    after: now
                )
            }
        }
        automation.lastModified = now
        if persist {
            try? await repository.upsert(automation)
        }

        if automation.notifyOnCompletion {
            let settings = await settingsStore.load()
            if settings.preferNotifications {
                let status = await notifications.authorizationStatus()
                if status == .authorized || status == .provisional {
                    notifications.postCompletion(
                        automationName: automation.name,
                        success: report.outcome == .completeSuccess || report.outcome == .partialSuccess,
                        recordCount: report.serializedRecordCount
                    )
                }
            }
        }

        return report
    }

    private func recordSchedulingError(_ message: String?) async {
        var settings = await settingsStore.load()
        settings.lastSchedulingError = message
        try? await settingsStore.save(settings)
    }

    enum CoordinatorError: LocalizedError {
        case notFound
        case secretCleanupFailed
        case savedWithWarnings([String])

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Automation not found."
            case .secretCleanupFailed:
                return "Automation was deleted, but one or more Keychain credentials could not be removed."
            case .savedWithWarnings(let warnings):
                return warnings.joined(separator: " ")
            }
        }
    }
}
