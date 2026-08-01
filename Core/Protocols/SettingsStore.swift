import Foundation

public protocol SettingsStore: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async throws
}
