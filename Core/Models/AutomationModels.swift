import Foundation

public enum ExecutionStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    public var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .running: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle"
        }
    }
}

public enum ScheduleFrequency: String, CaseIterable, Identifiable, Codable, Sendable {
    case hourly
    case daily
    case weekly
    case monthly
    case manual

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .manual: return "Manual"
        }
    }

    public var systemImage: String {
        switch self {
        case .hourly: return "clock.fill"
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .manual: return "hand.raised.fill"
        }
    }
}

public struct AutomationSchedule: Codable, Sendable, Equatable {
    public var frequency: ScheduleFrequency
    public var hour: Int
    public var minute: Int
    /// 1 = Sunday … 7 = Saturday (Calendar weekday)
    public var daysOfWeek: Set<Int>
    public var dayOfMonth: Int?

    public init(
        frequency: ScheduleFrequency = .daily,
        hour: Int = 2,
        minute: Int = 0,
        daysOfWeek: Set<Int> = [1, 2, 3, 4, 5, 6, 7],
        dayOfMonth: Int? = 1
    ) {
        self.frequency = frequency
        self.hour = hour
        self.minute = minute
        self.daysOfWeek = daysOfWeek
        self.dayOfMonth = dayOfMonth
    }

    public var bestEffortDisplayString: String {
        let timeString = String(format: "%02d:%02d", hour, minute)
        switch frequency {
        case .hourly:
            return "Earliest after each hour (best effort)"
        case .daily:
            return "Earliest after \(timeString) daily (best effort)"
        case .weekly:
            let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let days = daysOfWeek.sorted().compactMap { d -> String? in
                guard d >= 1, d <= 7 else { return nil }
                return names[d - 1]
            }.joined(separator: ", ")
            return "Earliest after \(timeString) on \(days) (best effort)"
        case .monthly:
            return "Earliest after \(timeString) on day \(dayOfMonth ?? 1) (best effort)"
        case .manual:
            return "Manual only"
        }
    }
}

/// Export configuration embedded in an automation (destinations by value for persistence).
public struct AutomationExportConfig: Codable, Sendable, Equatable {
    public var selection: ExportRequest.Selection
    public var range: ExportDateRange
    public var format: ExportFormat
    public var destinations: [ExportDestination]
    public var includeMetadata: Bool
    public var includeWorkoutRoutes: Bool
    public var includeECGWaveforms: Bool

    public init(
        selection: ExportRequest.Selection = .allDetected,
        range: ExportDateRange = .last24Hours,
        format: ExportFormat = .json,
        destinations: [ExportDestination] = [ExportDestination.defaultLocal()],
        includeMetadata: Bool = false,
        includeWorkoutRoutes: Bool = false,
        includeECGWaveforms: Bool = false
    ) {
        self.selection = selection
        self.range = range
        self.format = format
        self.destinations = destinations
        self.includeMetadata = includeMetadata
        self.includeWorkoutRoutes = includeWorkoutRoutes
        self.includeECGWaveforms = includeECGWaveforms
    }

    public func asExportRequest(name: String) -> ExportRequest {
        ExportRequest(
            name: name,
            selection: selection,
            range: range,
            format: format,
            destinationIDs: destinations.filter(\.isEnabled).map(\.id),
            includeMetadata: includeMetadata,
            includeWorkoutRoutes: includeWorkoutRoutes,
            includeECGWaveforms: includeECGWaveforms
        )
    }
}

public struct Automation: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var exportConfig: AutomationExportConfig
    public var schedule: AutomationSchedule
    public var isEnabled: Bool
    public var notifyOnCompletion: Bool
    public var executionStatus: ExecutionStatus
    public var retryCount: Int
    public var maxRetries: Int
    public var lastRun: Date?
    public var nextEligibleAt: Date?
    public var runCount: Int
    public var lastError: String?
    public var createdAt: Date
    public var lastModified: Date

    public init(
        id: UUID = UUID(),
        name: String = "New Automation",
        exportConfig: AutomationExportConfig = AutomationExportConfig(),
        schedule: AutomationSchedule = AutomationSchedule(),
        isEnabled: Bool = true,
        notifyOnCompletion: Bool = false,
        executionStatus: ExecutionStatus = .pending,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        lastRun: Date? = nil,
        nextEligibleAt: Date? = nil,
        runCount: Int = 0,
        lastError: String? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.exportConfig = exportConfig
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.notifyOnCompletion = notifyOnCompletion
        self.executionStatus = executionStatus
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.lastRun = lastRun
        self.nextEligibleAt = nextEligibleAt
        self.runCount = runCount
        self.lastError = lastError
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

public struct AutomationEnvelope: Codable, Sendable {
    public let schemaVersion: Int
    public var automations: [Automation]
    public var migratedAt: Date?

    public init(schemaVersion: Int = 1, automations: [Automation] = [], migratedAt: Date? = nil) {
        self.schemaVersion = schemaVersion
        self.automations = automations
        self.migratedAt = migratedAt
    }
}
