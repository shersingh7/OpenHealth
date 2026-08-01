import Foundation

/// Operational export history only — never stores health sample values.
public struct ExportHistoryEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let exportID: UUID
    public let startedAt: Date
    public let completedAt: Date
    public let format: ExportFormat
    public let rangeDescription: String
    public let serializedRecordCount: Int
    public let outcome: ExportOutcome
    public let destinationSummaries: [String]
    public let warningCount: Int
    public let automationID: UUID?
    public let automationName: String?
    public let errorDescription: String?

    public init(
        id: UUID = UUID(),
        exportID: UUID,
        startedAt: Date,
        completedAt: Date,
        format: ExportFormat,
        rangeDescription: String,
        serializedRecordCount: Int,
        outcome: ExportOutcome,
        destinationSummaries: [String],
        warningCount: Int,
        automationID: UUID? = nil,
        automationName: String? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.exportID = exportID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.format = format
        self.rangeDescription = rangeDescription
        self.serializedRecordCount = serializedRecordCount
        self.outcome = outcome
        self.destinationSummaries = destinationSummaries
        self.warningCount = warningCount
        self.automationID = automationID
        self.automationName = automationName
        self.errorDescription = errorDescription
    }
}

public struct ExportHistoryEnvelope: Codable, Sendable {
    public let schemaVersion: Int
    public var entries: [ExportHistoryEntry]

    public init(schemaVersion: Int = 1, entries: [ExportHistoryEntry] = []) {
        self.schemaVersion = schemaVersion
        self.entries = entries
    }
}
