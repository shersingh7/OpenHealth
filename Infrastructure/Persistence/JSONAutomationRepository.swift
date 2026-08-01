import Foundation

actor JSONAutomationRepository: AutomationRepository {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, directory: URL? = nil) throws {
        self.fileManager = fileManager
        let base = try directory ?? Self.applicationSupportDirectory(fileManager: fileManager)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("automations.json")
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadAll() async throws -> [Automation] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let envelope = try decoder.decode(AutomationEnvelope.self, from: data)
        return envelope.automations
    }

    func saveAll(_ automations: [Automation]) async throws {
        let envelope = AutomationEnvelope(schemaVersion: 1, automations: automations, migratedAt: nil)
        try atomicWrite(envelope)
    }

    func upsert(_ automation: Automation) async throws {
        var all = try await loadAll()
        if let idx = all.firstIndex(where: { $0.id == automation.id }) {
            all[idx] = automation
        } else {
            all.append(automation)
        }
        try await saveAll(all)
    }

    func delete(id: UUID) async throws {
        var all = try await loadAll()
        all.removeAll { $0.id == id }
        try await saveAll(all)
    }

    func automation(id: UUID) async throws -> Automation? {
        try await loadAll().first { $0.id == id }
    }

    private func atomicWrite(_ envelope: AutomationEnvelope) throws {
        let data = try encoder.encode(envelope)
        try ProtectedFileIO.writeAtomically(data, to: fileURL)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = fileURL
        try? mutable.setResourceValues(values)
    }

    static func applicationSupportDirectory(fileManager: FileManager) throws -> URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let base = urls.first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return base.appendingPathComponent("OpenHealth", isDirectory: true)
    }
}
