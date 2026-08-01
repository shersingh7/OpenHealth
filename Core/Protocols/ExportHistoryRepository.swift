import Foundation

public protocol ExportHistoryRepository: Sendable {
    func loadRecent(limit: Int) async throws -> [ExportHistoryEntry]
    func append(_ entry: ExportHistoryEntry) async throws
    func clear() async throws
    func count() async throws -> Int
}
