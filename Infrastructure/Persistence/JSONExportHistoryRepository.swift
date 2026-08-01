import Foundation

actor JSONExportHistoryRepository: ExportHistoryRepository {
    private let fileURL: URL
    private let fileManager: FileManager
    private let maxEntries: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, directory: URL? = nil, maxEntries: Int = 100) throws {
        self.fileManager = fileManager
        self.maxEntries = maxEntries
        let base = try directory ?? JSONAutomationRepository.applicationSupportDirectory(fileManager: fileManager)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("export_history.json")
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadRecent(limit: Int) async throws -> [ExportHistoryEntry] {
        let all = try loadEnvelope().entries
        return Array(all.suffix(limit).reversed())
    }

    func append(_ entry: ExportHistoryEntry) async throws {
        var envelope = try loadEnvelope()
        envelope.entries.append(entry)
        if envelope.entries.count > maxEntries {
            envelope.entries = Array(envelope.entries.suffix(maxEntries))
        }
        try atomicWrite(envelope)
    }

    func clear() async throws {
        try atomicWrite(ExportHistoryEnvelope(schemaVersion: 1, entries: []))
    }

    func count() async throws -> Int {
        try loadEnvelope().entries.count
    }

    private func loadEnvelope() throws -> ExportHistoryEnvelope {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ExportHistoryEnvelope()
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(ExportHistoryEnvelope.self, from: data)
    }

    private func atomicWrite(_ envelope: ExportHistoryEnvelope) throws {
        let data = try encoder.encode(envelope)
        try ProtectedFileIO.writeAtomically(data, to: fileURL)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = fileURL
        try? mutable.setResourceValues(values)
    }
}
