import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step: Int = 0
    @Published var isRequesting = false
    @Published var errorMessage: String?

    private let healthDataSource: any HealthDataSource
    private let settingsStore: any SettingsStore

    let steps: [(title: String, body: String, image: String)] = [
        (
            "Private by design",
            "OpenHealth does not collect your data. Exports stay on your device or go only to destinations you choose.",
            "lock.shield.fill"
        ),
        (
            "What we read",
            "OpenHealth can read Apple Health data you allow — quantities, categories, workouts, routes, ECG, and activity summaries — solely to build export files.",
            "heart.text.square.fill"
        ),
        (
            "You control destinations",
            "Supported destinations: Local Files, iCloud Drive, and REST API. Planned destinations stay disabled until implemented.",
            "externaldrive.fill.badge.checkmark"
        )
    ]

    init(healthDataSource: any HealthDataSource, settingsStore: any SettingsStore) {
        self.healthDataSource = healthDataSource
        self.settingsStore = settingsStore
    }

    func completeWithoutAccess() async {
        var settings = await settingsStore.load()
        settings.hasCompletedOnboarding = true
        try? await settingsStore.save(settings)
    }

    /// Returns true when access was requested successfully and onboarding may finish.
    @discardableResult
    func requestHealthAccess() async -> Bool {
        isRequesting = true
        errorMessage = nil
        defer { isRequesting = false }
        do {
            _ = try await healthDataSource.requestReadAccess()
            var settings = await settingsStore.load()
            settings.hasCompletedOnboarding = true
            try? await settingsStore.save(settings)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
