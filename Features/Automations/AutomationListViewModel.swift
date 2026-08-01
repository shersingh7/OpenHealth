import Foundation

@MainActor
final class AutomationListViewModel: ObservableObject {
    @Published var automations: [Automation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var schedulingError: String?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            automations = try await container.automationCoordinator.loadAutomations()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let settings = await container.settingsStore.load()
            schedulingError = settings.lastSchedulingError
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ automation: Automation) async {
        do {
            try await container.automationCoordinator.setEnabled(id: automation.id, enabled: !automation.isEnabled)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ automation: Automation) async {
        do {
            try await container.automationCoordinator.delete(id: automation.id, secretStore: container.secretStore)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            // The automation may already be gone when post-delete Keychain
            // cleanup is the operation that failed.
            await refresh()
        }
    }

    func runNow(_ automation: Automation) async {
        do {
            _ = try await container.automationCoordinator.runSaved(id: automation.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectionLabel(_ config: AutomationExportConfig) -> String {
        switch config.selection {
        case .allDetected: return "All supported"
        case .explicit(let ids): return "\(ids.count) types"
        }
    }
}
