import Foundation
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings = .default
    @Published var accessState: HealthAccessState?
    @Published var historyCount = 0
    @Published var notificationStatus = ""
    @Published var message: String?
    @Published var isBusy = false

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    func refresh() async {
        settings = await container.settingsStore.load()
        accessState = await container.healthDataSource.accessState()
        historyCount = (try? await container.historyRepository.count()) ?? 0
        let status = await container.notifications.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral: notificationStatus = "Allowed"
        case .denied: notificationStatus = "Denied"
        case .notDetermined: notificationStatus = "Not requested"
        @unknown default: notificationStatus = "Unknown"
        }
    }

    func save() async {
        do {
            try await container.settingsStore.save(settings)
            message = "Settings saved."
        } catch {
            message = error.localizedDescription
        }
    }

    func requestAccess() async {
        isBusy = true
        defer { isBusy = false }
        do {
            accessState = try await container.healthDataSource.requestReadAccess()
        } catch {
            message = error.localizedDescription
        }
    }

    func clearHistory() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await container.historyRepository.clear()
            historyCount = 0
            message = "Export history cleared."
        } catch {
            message = error.localizedDescription
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
