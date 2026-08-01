import Foundation

// MARK: - Format & Range

public enum ExportFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case csv = "CSV"
    case json = "JSON"
    case gpx = "GPX"

    public var id: String { rawValue }

    public var fileExtension: String { rawValue.lowercased() }

    public var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        case .gpx: return "application/gpx+xml"
        }
    }

    public var systemImage: String {
        switch self {
        case .csv: return "doc.text"
        case .json: return "curlybraces"
        case .gpx: return "map"
        }
    }

    public var description: String {
        switch self {
        case .csv: return "Comma-separated values for spreadsheets and analysis"
        case .json: return "Versioned structured export with all record sections"
        case .gpx: return "GPS Exchange Format for workout routes only"
        }
    }
}

public enum ExportDateRange: Codable, Sendable, Equatable {
    case today
    case yesterday
    case last24Hours
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case thisYear
    case lastYear
    case allTime
    case custom(start: Date, end: Date)

    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .last24Hours: return "Last 24 Hours"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .thisYear: return "This Year"
        case .lastYear: return "Last Year"
        case .allTime: return "All Time"
        case .custom: return "Custom Range"
        }
    }
}

// MARK: - Authorization (read access is never definitive)

public struct HealthAccessState: Equatable, Sendable {
    public enum RequestState: Equatable, Sendable {
        case notRequested
        case requestRecommended
        case previouslyRequested
        case unavailable
    }

    public let isHealthDataAvailable: Bool
    public let requestState: RequestState
    public let lastRequestedAt: Date?

    public init(
        isHealthDataAvailable: Bool,
        requestState: RequestState,
        lastRequestedAt: Date? = nil
    ) {
        self.isHealthDataAvailable = isHealthDataAvailable
        self.requestState = requestState
        self.lastRequestedAt = lastRequestedAt
    }

    public var statusLabel: String {
        guard isHealthDataAvailable else { return "Health data unavailable on this device" }
        switch requestState {
        case .notRequested: return "Health access not requested"
        case .requestRecommended: return "Choose data access in Apple Health"
        case .previouslyRequested: return "Health access requested"
        case .unavailable: return "Health data unavailable on this device"
        }
    }
}

// MARK: - Export Request

public struct ExportRequest: Codable, Sendable, Identifiable, Equatable {
    public enum Selection: Codable, Sendable, Equatable {
        case allDetected
        case explicit(Set<String>)
    }

    public let id: UUID
    public var name: String
    public var selection: Selection
    public var range: ExportDateRange
    public var format: ExportFormat
    public var destinationIDs: [UUID]
    public var includeMetadata: Bool
    public var includeWorkoutRoutes: Bool
    public var includeECGWaveforms: Bool

    public init(
        id: UUID = UUID(),
        name: String = "Export",
        selection: Selection = .allDetected,
        range: ExportDateRange = .last24Hours,
        format: ExportFormat = .json,
        destinationIDs: [UUID] = [],
        includeMetadata: Bool = false,
        includeWorkoutRoutes: Bool = false,
        includeECGWaveforms: Bool = false
    ) {
        self.id = id
        self.name = name
        self.selection = selection
        self.range = range
        self.format = format
        self.destinationIDs = destinationIDs
        self.includeMetadata = includeMetadata
        self.includeWorkoutRoutes = includeWorkoutRoutes
        self.includeECGWaveforms = includeECGWaveforms
    }
}

public enum ExportRequestValidationError: Error, Equatable, LocalizedError {
    case nameEmpty
    case nameTooLong
    case emptyExplicitSelection
    case gpxRequiresRoutes
    case noDestinations
    case invalidDateRange(String)

    public var errorDescription: String? {
        switch self {
        case .nameEmpty: return "Name is required."
        case .nameTooLong: return "Name must be 80 characters or fewer."
        case .emptyExplicitSelection: return "Select at least one data type."
        case .gpxRequiresRoutes: return "GPX export requires workouts with routes."
        case .noDestinations: return "Select at least one destination."
        case .invalidDateRange(let m): return m
        }
    }
}

public enum ExportRequestValidator {
    public static func validate(
        _ request: ExportRequest,
        destinations: [ExportDestination],
        now: Date,
        calendar: Calendar
    ) -> [ExportRequestValidationError] {
        var errors: [ExportRequestValidationError] = []

        let trimmed = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { errors.append(.nameEmpty) }
        if trimmed.count > 80 { errors.append(.nameTooLong) }

        if case .explicit(let ids) = request.selection, ids.isEmpty {
            errors.append(.emptyExplicitSelection)
        }

        // GPX requires route-bearing selection: either the toggle with workouts/all-supported, or explicit route/workout IDs.
        if request.format == .gpx {
            let metrics = MetricSelectionResolver.resolveMetricIDs(
                selection: request.selection,
                includeWorkoutRoutes: request.includeWorkoutRoutes
            )
            let hasRoutes = MetricSelectionResolver.shouldIncludeRoutes(
                metricIDs: metrics,
                includeWorkoutRoutes: request.includeWorkoutRoutes
            )
            if !hasRoutes {
                errors.append(.gpxRequiresRoutes)
            }
        }

        let enabled = destinations.filter { request.destinationIDs.contains($0.id) && $0.isEnabled }
        if enabled.isEmpty {
            errors.append(.noDestinations)
        }

        do {
            _ = try DateRangeResolver.resolve(request.range, now: now, calendar: calendar)
        } catch {
            errors.append(.invalidDateRange(error.localizedDescription))
        }

        return errors
    }
}

// MARK: - Export Document (schema v1)

public struct ExportWarning: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let code: String
    public let message: String
    public let metricID: String?

    public init(id: UUID = UUID(), code: String, message: String, metricID: String? = nil) {
        self.id = id
        self.code = code
        self.message = message
        self.metricID = metricID
    }
}

public struct ExportDocument: Codable, Sendable {
    public let schemaVersion: Int
    public let exportID: UUID
    public let generatedAt: Date
    public let appVersion: String
    public let requestedRange: CodableDateInterval
    public let includedMetricIDs: [String]
    public var quantityRecords: [QuantityRecord]
    public var categoryRecords: [CategoryRecord]
    public var workouts: [WorkoutRecord]
    public var electrocardiograms: [ECGRecord]
    public var activitySummaries: [ActivitySummaryRecord]
    public var warnings: [ExportWarning]

    public init(
        schemaVersion: Int = 1,
        exportID: UUID,
        generatedAt: Date,
        appVersion: String,
        requestedRange: DateInterval,
        includedMetricIDs: [String],
        quantityRecords: [QuantityRecord] = [],
        categoryRecords: [CategoryRecord] = [],
        workouts: [WorkoutRecord] = [],
        electrocardiograms: [ECGRecord] = [],
        activitySummaries: [ActivitySummaryRecord] = [],
        warnings: [ExportWarning] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportID = exportID
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.requestedRange = CodableDateInterval(requestedRange)
        self.includedMetricIDs = includedMetricIDs
        self.quantityRecords = quantityRecords
        self.categoryRecords = categoryRecords
        self.workouts = workouts
        self.electrocardiograms = electrocardiograms
        self.activitySummaries = activitySummaries
        self.warnings = warnings
    }

    /// Counts derive only from serialized sections.
    public var totalRecords: Int {
        quantityRecords.count
            + categoryRecords.count
            + workouts.count
            + electrocardiograms.count
            + activitySummaries.count
    }

    public static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

public struct CodableDateInterval: Codable, Sendable, Equatable {
    public let start: Date
    public let end: Date

    public init(_ interval: DateInterval) {
        self.start = interval.start
        self.end = interval.end
    }

    public var dateInterval: DateInterval {
        DateInterval(start: start, end: end)
    }
}

// MARK: - Progress & Report

public enum ExportPhase: Equatable, Sendable {
    case validating
    case reading(current: Int, total: Int, label: String)
    case encoding(format: ExportFormat)
    case delivering(current: Int, total: Int, name: String)
    case completed
    case cancelled

    public var accessibilityLabel: String {
        switch self {
        case .validating: return "Validating export"
        case .reading(let c, let t, let label): return "Reading \(label), \(c) of \(t)"
        case .encoding(let f): return "Encoding \(f.rawValue)"
        case .delivering(let c, let t, let name): return "Delivering to \(name), \(c) of \(t)"
        case .completed: return "Export completed"
        case .cancelled: return "Export cancelled"
        }
    }
}

public struct ExportProgress: Sendable, Equatable {
    public let phase: ExportPhase
    public let fractionCompleted: Double

    public init(phase: ExportPhase, fractionCompleted: Double) {
        self.phase = phase
        self.fractionCompleted = min(max(fractionCompleted, 0), 1)
    }
}

public struct DestinationDeliveryResult: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let destinationID: UUID
    public let destinationName: String
    public let destinationType: String
    public let success: Bool
    public let artifactURLString: String?
    public let bytesWritten: Int?
    public let errorDescription: String?

    public init(
        id: UUID = UUID(),
        destinationID: UUID,
        destinationName: String,
        destinationType: String,
        success: Bool,
        artifactURLString: String? = nil,
        bytesWritten: Int? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.destinationID = destinationID
        self.destinationName = destinationName
        self.destinationType = destinationType
        self.success = success
        self.artifactURLString = artifactURLString
        self.bytesWritten = bytesWritten
        self.errorDescription = errorDescription
    }
}

public enum ExportOutcome: String, Codable, Sendable {
    case completeSuccess
    case partialSuccess
    case failure
    case cancelled
}

public struct ExportReport: Sendable {
    public let exportID: UUID
    public let startedAt: Date
    public let completedAt: Date
    public let serializedRecordCount: Int
    public let artifactURL: URL?
    public let destinationResults: [DestinationDeliveryResult]
    public let warnings: [ExportWarning]
    public let outcome: ExportOutcome
    public let errorDescription: String?

    public init(
        exportID: UUID,
        startedAt: Date,
        completedAt: Date,
        serializedRecordCount: Int,
        artifactURL: URL?,
        destinationResults: [DestinationDeliveryResult],
        warnings: [ExportWarning],
        outcome: ExportOutcome,
        errorDescription: String? = nil
    ) {
        self.exportID = exportID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.serializedRecordCount = serializedRecordCount
        self.artifactURL = artifactURL
        self.destinationResults = destinationResults
        self.warnings = warnings
        self.outcome = outcome
        self.errorDescription = errorDescription
    }

    public var isCompleteSuccess: Bool { outcome == .completeSuccess }
    public var isPartialSuccess: Bool { outcome == .partialSuccess }
}
