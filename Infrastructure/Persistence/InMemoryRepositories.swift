import Foundation

/// Non-crashing fallback when Application Support / temporary storage is unavailable.
actor InMemoryAutomationRepository: AutomationRepository {
    private var items: [Automation] = []

    func loadAll() async throws -> [Automation] { items }

    func saveAll(_ automations: [Automation]) async throws {
        items = automations
    }

    func upsert(_ automation: Automation) async throws {
        if let idx = items.firstIndex(where: { $0.id == automation.id }) {
            items[idx] = automation
        } else {
            items.append(automation)
        }
    }

    func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    func automation(id: UUID) async throws -> Automation? {
        items.first { $0.id == id }
    }
}

actor InMemoryExportHistoryRepository: ExportHistoryRepository {
    private var entries: [ExportHistoryEntry] = []
    private let maxEntries: Int

    init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }

    func loadRecent(limit: Int) async throws -> [ExportHistoryEntry] {
        Array(entries.suffix(limit).reversed())
    }

    func append(_ entry: ExportHistoryEntry) async throws {
        entries.append(entry)
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }
    }

    func clear() async throws {
        entries.removeAll()
    }

    func count() async throws -> Int { entries.count }
}
