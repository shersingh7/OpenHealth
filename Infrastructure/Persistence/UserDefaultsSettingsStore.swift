import Foundation

/// App settings in standard UserDefaults (app-container CA92.1). No secrets.
actor UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults
    private let key = "openhealth.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() async -> AppSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            AppLogger.persistence.error("Settings decode failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
            return .default
        }
    }

    func save(_ settings: AppSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: key)
    }
}
