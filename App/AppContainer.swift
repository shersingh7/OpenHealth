import Foundation
import HealthKit

/// Single composition root. Exactly one live dependency graph.
@MainActor
final class AppContainer: ObservableObject {
    let healthDataSource: any HealthDataSource
    let exportPipeline: ExportPipeline
    let automationRepository: any AutomationRepository
    let historyRepository: any ExportHistoryRepository
    let automationCoordinator: AutomationCoordinator
    let settingsStore: any SettingsStore
    let secretStore: any SecretStore
    let notifications: any NotificationClienting
    let backgroundScheduler: any BackgroundTaskScheduling
    let clock: any Clock

    @Published var migrationMessage: String?
    @Published private(set) var didFinishLaunchSetup = false
    /// When true, storage fell back to in-memory repositories (non-persistent).
    @Published private(set) var isUsingEphemeralStorage = false
    @Published var storageWarning: String?

    private static var liveInstanceCount = 0

    private init(
        healthDataSource: any HealthDataSource,
        exportPipeline: ExportPipeline,
        automationRepository: any AutomationRepository,
        historyRepository: any ExportHistoryRepository,
        automationCoordinator: AutomationCoordinator,
        settingsStore: any SettingsStore,
        secretStore: any SecretStore,
        notifications: any NotificationClienting,
        backgroundScheduler: any BackgroundTaskScheduling,
        clock: any Clock,
        isUsingEphemeralStorage: Bool = false
    ) {
        self.healthDataSource = healthDataSource
        self.exportPipeline = exportPipeline
        self.automationRepository = automationRepository
        self.historyRepository = historyRepository
        self.automationCoordinator = automationCoordinator
        self.settingsStore = settingsStore
        self.secretStore = secretStore
        self.notifications = notifications
        self.backgroundScheduler = backgroundScheduler
        self.clock = clock
        self.isUsingEphemeralStorage = isUsingEphemeralStorage
        if isUsingEphemeralStorage {
            self.storageWarning = "Storage is unavailable. Automations and history will not persist until storage is restored."
        }
    }

    static func live() -> AppContainer {
        #if DEBUG
        liveInstanceCount += 1
        assert(liveInstanceCount == 1, "Only one live AppContainer should be composed")
        #endif

        let settingsStore = UserDefaultsSettingsStore()
        let secretStore = KeychainSecretStore()
        let clock = SystemClock()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        #if DEBUG
        let allowLoopback = true
        #else
        let allowLoopback = false
        #endif

        let automationRepository: any AutomationRepository
        let historyRepository: any ExportHistoryRepository
        var ephemeral = false

        if let diskAuto = try? JSONAutomationRepository(),
           let diskHistory = try? JSONExportHistoryRepository() {
            automationRepository = diskAuto
            historyRepository = diskHistory
        } else {
            // Non-crashing in-memory fallback — app must launch even if Application Support is unavailable.
            AppLogger.general.error("Failed to create disk repositories; using in-memory fallback")
            automationRepository = InMemoryAutomationRepository()
            historyRepository = InMemoryExportHistoryRepository()
            ephemeral = true
        }

        let healthDataSource = LiveHealthDataSource(settingsStore: settingsStore)
        let exportPipeline = ExportPipeline.live(
            healthDataSource: healthDataSource,
            secretStore: secretStore,
            historyRepository: historyRepository,
            clock: clock,
            appVersion: appVersion,
            allowLoopbackHTTP: allowLoopback
        )
        let notifications = NotificationClient()
        let backgroundScheduler = BGTaskSchedulerClient()
        let coordinator = AutomationCoordinator(
            repository: automationRepository,
            pipeline: exportPipeline,
            scheduler: backgroundScheduler,
            notifications: notifications,
            settingsStore: settingsStore,
            clock: clock
        )
        let container = AppContainer(
            healthDataSource: healthDataSource,
            exportPipeline: exportPipeline,
            automationRepository: automationRepository,
            historyRepository: historyRepository,
            automationCoordinator: coordinator,
            settingsStore: settingsStore,
            secretStore: secretStore,
            notifications: notifications,
            backgroundScheduler: backgroundScheduler,
            clock: clock,
            isUsingEphemeralStorage: ephemeral
        )
        // Attach before any background launch can fire — do not rely on UI appear.
        BackgroundTaskRegistration.attach(container: container)
        return container
    }

    /// Build an export pipeline that resolves secrets from the given store.
    /// Used by draft/export UIs that stage credentials until parent commit.
    func makeExportPipeline(secretStore: any SecretStore) -> ExportPipeline {
        #if DEBUG
        let allowLoopback = true
        #else
        let allowLoopback = false
        #endif
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return ExportPipeline.live(
            healthDataSource: healthDataSource,
            secretStore: secretStore,
            historyRepository: historyRepository,
            clock: clock,
            appVersion: appVersion,
            allowLoopbackHTTP: allowLoopback
        )
    }

    func performLaunchSetup() async {
        let migrator = LegacyAutomationMigrator(
            secretStore: secretStore,
            repository: automationRepository
        )
        let outcome = await migrator.migrateIfNeeded()
        switch outcome {
        case .migrated(let count, let warnings):
            var message = "Migrated \(count) automation(s) to secure storage."
            if !warnings.isEmpty {
                message += " " + warnings.prefix(3).joined(separator: " ")
                if warnings.count > 3 {
                    message += " (+\(warnings.count - 3) more)"
                }
            }
            migrationMessage = message
        case .failed(let message):
            migrationMessage = "Automation migration needs attention: \(message)"
        case .alreadyMigrated, .nothingToMigrate:
            break
        }

        try? await automationCoordinator.hydrateMissingScheduleDates()
        try? await automationCoordinator.reconcileBackgroundRequest()
        await automationCoordinator.executeDueAutomations()
        didFinishLaunchSetup = true
    }
}
