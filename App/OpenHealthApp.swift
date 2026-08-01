import SwiftUI
import BackgroundTasks

@main
struct OpenHealthApp: App {
    @StateObject private var container = AppContainer.live()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register background task handler early. Live container attaches itself in AppContainer.live().
        BackgroundTaskRegistration.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Task {
                    try? await container.automationCoordinator.reconcileBackgroundRequest()
                }
            } else if phase == .active {
                Task {
                    await container.automationCoordinator.executeDueAutomations()
                }
            }
        }
    }
}

/// Thin registration bridge — does not construct services.
@MainActor
enum BackgroundTaskRegistration {
    private static weak var container: AppContainer?

    static func attach(container: AppContainer) {
        self.container = container
    }

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AutomationCoordinator.taskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                guard let refresh = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                handle(refresh)
            }
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        guard let container else {
            task.setTaskCompleted(success: false)
            return
        }

        let work = Task { @MainActor in
            // Hydrate schedules and run due work even when UI never appears.
            try? await container.automationCoordinator.hydrateMissingScheduleDates()
            await container.automationCoordinator.executeDueAutomations()
            try? await container.automationCoordinator.reconcileBackgroundRequest()
        }

        task.expirationHandler = {
            Task { @MainActor in
                await container.automationCoordinator.handleExpiration()
            }
            work.cancel()
        }

        Task {
            await work.value
            // Truthful completion: cancelled work should not be marked pure success.
            task.setTaskCompleted(success: !work.isCancelled)
        }
    }
}
