import Foundation

@MainActor
final class AutomationEditorViewModel: ObservableObject {
    @Published var automation: Automation
    @Published var errors: [String] = []
    @Published var isSaving = false
    @Published var isRunningDraft = false
    @Published var draftReport: ExportReport?
    @Published var notificationStatusText: String = ""
    /// Set when save succeeds so the view can skip discarding staged secrets.
    private(set) var didCommitSecrets = false

    private let container: AppContainer
    private let isNew: Bool
    /// Stages Keychain writes until parent Save; discarded on Cancel.
    let secretStaging: StagedSecretStore

    init(container: AppContainer, automation: Automation?) {
        self.container = container
        self.secretStaging = StagedSecretStore(underlying: container.secretStore)
        if let automation {
            self.automation = automation
            self.isNew = false
        } else {
            self.automation = Automation(
                name: "New Automation",
                exportConfig: AutomationExportConfig(
                    destinations: [ExportDestination.defaultLocal()]
                ),
                schedule: AutomationSchedule(frequency: .daily, hour: 2, minute: 0)
            )
            self.isNew = true
        }
    }

    /// Secret store for child destination editors/pickers (staged, not live Keychain).
    var secretStore: any SecretStore { secretStaging }

    var canSave: Bool {
        validate()
        return errors.isEmpty
    }

    @discardableResult
    func validate() -> Bool {
        errors = []
        let name = automation.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { errors.append("Name is required.") }
        if name.count > 80 { errors.append("Name must be 80 characters or fewer.") }
        do {
            try ScheduleCalculator.validate(automation.schedule)
        } catch {
            errors.append(error.localizedDescription)
        }
        let request = automation.exportConfig.asExportRequest(name: name)
        let destErrors = ExportRequestValidator.validate(
            request,
            destinations: automation.exportConfig.destinations,
            now: container.clock.now(),
            calendar: .current
        )
        errors.append(contentsOf: destErrors.map(\.localizedDescription))
        for dest in automation.exportConfig.destinations {
            #if DEBUG
            let allow = true
            #else
            let allow = false
            #endif
            errors.append(contentsOf: dest.validate(allowLoopbackHTTP: allow))
        }
        return errors.isEmpty
    }

    func save() async -> Bool {
        guard validate() else { return false }
        isSaving = true
        defer { isSaving = false }
        automation.name = automation.name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if automation.notifyOnCompletion {
                var settings = await container.settingsStore.load()
                if !settings.preferNotifications {
                    settings.preferNotifications = true
                    try await container.settingsStore.save(settings)
                }
                let status = await container.notifications.authorizationStatus()
                if status == .notDetermined {
                    _ = try await container.notifications.requestAuthorization()
                }
            }
            // Commit staged secrets, retaining compensation state until the
            // parent automation is durably persisted.
            let receipt = try await secretStaging.commitWithReceipt()
            // Prune Keychain for destinations removed from this automation.
            do {
                try await container.automationCoordinator.save(
                    automation,
                    secretStore: container.secretStore
                )
                didCommitSecrets = true
                return true
            } catch AutomationCoordinator.CoordinatorError.savedWithWarnings(let warnings) {
                // The repository upsert succeeded. Keep committed credentials
                // aligned with it, but hold the editor open to report warnings.
                didCommitSecrets = true
                errors.append(contentsOf: warnings)
                return false
            } catch {
                // The durable upsert failed before completion. Compensate the
                // Keychain mutation and keep edits staged for retry/cancel.
                do {
                    try await secretStaging.rollback(receipt)
                } catch {
                    errors.append("Automation was not saved and the previous Keychain state could not be fully restored.")
                    return false
                }
                throw error
            }
        } catch {
            errors.append(error.localizedDescription)
            return false
        }
    }

    /// Drop staged Keychain mutations. Safe when Save never committed.
    func discardSecretStaging() async {
        guard !didCommitSecrets else { return }
        await secretStaging.discard()
    }

    func runDraftNow() async {
        guard validate() else { return }
        isRunningDraft = true
        defer { isRunningDraft = false }
        // Use a pipeline that reads staged secrets without committing them.
        let pipeline = container.makeExportPipeline(secretStore: secretStaging)
        draftReport = await pipeline.run(
            request: automation.exportConfig.asExportRequest(name: automation.name),
            destinations: automation.exportConfig.destinations,
            automationID: nil,
            automationName: automation.name
        )
    }

    func refreshNotificationStatus() async {
        let status = await container.notifications.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            notificationStatusText = "Notifications allowed"
        case .denied:
            notificationStatusText = "Notifications denied — enable in Settings"
        case .notDetermined:
            notificationStatusText = "Not requested yet"
        @unknown default:
            notificationStatusText = "Unknown"
        }
    }
}
