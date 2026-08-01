import Foundation

public protocol AutomationRepository: Sendable {
    func loadAll() async throws -> [Automation]
    func saveAll(_ automations: [Automation]) async throws
    func upsert(_ automation: Automation) async throws
    func delete(id: UUID) async throws
    func automation(id: UUID) async throws -> Automation?
}
