import Foundation

public struct AppSettings: Codable, Sendable, Equatable {
    public var hasCompletedOnboarding: Bool
    public var defaultFormat: ExportFormat
    public var defaultRange: ExportDateRange
    public var defaultIncludeMetadata: Bool
    public var defaultIncludeWorkoutRoutes: Bool
    public var defaultIncludeECGWaveforms: Bool
    public var preferNotifications: Bool
    public var healthAccessLastRequestedAt: Date?
    public var healthAccessRequestState: StoredAccessRequestState
    public var lastCoverageScanAt: Date?
    public var lastCoverageTypeCount: Int
    /// Actual detected metric IDs from the last coverage scan (truthful cache).
    public var lastCoverageDetectedMetricIDs: [String]
    public var lastSchedulingError: String?

    public init(
        hasCompletedOnboarding: Bool = false,
        defaultFormat: ExportFormat = .json,
        defaultRange: ExportDateRange = .last24Hours,
        defaultIncludeMetadata: Bool = false,
        defaultIncludeWorkoutRoutes: Bool = false,
        defaultIncludeECGWaveforms: Bool = false,
        preferNotifications: Bool = false,
        healthAccessLastRequestedAt: Date? = nil,
        healthAccessRequestState: StoredAccessRequestState = .notRequested,
        lastCoverageScanAt: Date? = nil,
        lastCoverageTypeCount: Int = 0,
        lastCoverageDetectedMetricIDs: [String] = [],
        lastSchedulingError: String? = nil
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.defaultFormat = defaultFormat
        self.defaultRange = defaultRange
        self.defaultIncludeMetadata = defaultIncludeMetadata
        self.defaultIncludeWorkoutRoutes = defaultIncludeWorkoutRoutes
        self.defaultIncludeECGWaveforms = defaultIncludeECGWaveforms
        self.preferNotifications = preferNotifications
        self.healthAccessLastRequestedAt = healthAccessLastRequestedAt
        self.healthAccessRequestState = healthAccessRequestState
        self.lastCoverageScanAt = lastCoverageScanAt
        self.lastCoverageTypeCount = lastCoverageTypeCount
        self.lastCoverageDetectedMetricIDs = lastCoverageDetectedMetricIDs
        self.lastSchedulingError = lastSchedulingError
    }

    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, defaultFormat, defaultRange
        case defaultIncludeMetadata, defaultIncludeWorkoutRoutes, defaultIncludeECGWaveforms
        case preferNotifications, healthAccessLastRequestedAt, healthAccessRequestState
        case lastCoverageScanAt, lastCoverageTypeCount, lastCoverageDetectedMetricIDs, lastSchedulingError
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        defaultFormat = try c.decodeIfPresent(ExportFormat.self, forKey: .defaultFormat) ?? .json
        defaultRange = try c.decodeIfPresent(ExportDateRange.self, forKey: .defaultRange) ?? .last24Hours
        defaultIncludeMetadata = try c.decodeIfPresent(Bool.self, forKey: .defaultIncludeMetadata) ?? false
        // Default route export OFF for new/legacy-missing settings.
        defaultIncludeWorkoutRoutes = try c.decodeIfPresent(Bool.self, forKey: .defaultIncludeWorkoutRoutes) ?? false
        defaultIncludeECGWaveforms = try c.decodeIfPresent(Bool.self, forKey: .defaultIncludeECGWaveforms) ?? false
        preferNotifications = try c.decodeIfPresent(Bool.self, forKey: .preferNotifications) ?? false
        healthAccessLastRequestedAt = try c.decodeIfPresent(Date.self, forKey: .healthAccessLastRequestedAt)
        healthAccessRequestState = try c.decodeIfPresent(StoredAccessRequestState.self, forKey: .healthAccessRequestState) ?? .notRequested
        lastCoverageScanAt = try c.decodeIfPresent(Date.self, forKey: .lastCoverageScanAt)
        lastCoverageTypeCount = try c.decodeIfPresent(Int.self, forKey: .lastCoverageTypeCount) ?? 0
        lastCoverageDetectedMetricIDs = try c.decodeIfPresent([String].self, forKey: .lastCoverageDetectedMetricIDs) ?? []
        lastSchedulingError = try c.decodeIfPresent(String.self, forKey: .lastSchedulingError)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try c.encode(defaultFormat, forKey: .defaultFormat)
        try c.encode(defaultRange, forKey: .defaultRange)
        try c.encode(defaultIncludeMetadata, forKey: .defaultIncludeMetadata)
        try c.encode(defaultIncludeWorkoutRoutes, forKey: .defaultIncludeWorkoutRoutes)
        try c.encode(defaultIncludeECGWaveforms, forKey: .defaultIncludeECGWaveforms)
        try c.encode(preferNotifications, forKey: .preferNotifications)
        try c.encodeIfPresent(healthAccessLastRequestedAt, forKey: .healthAccessLastRequestedAt)
        try c.encode(healthAccessRequestState, forKey: .healthAccessRequestState)
        try c.encodeIfPresent(lastCoverageScanAt, forKey: .lastCoverageScanAt)
        try c.encode(lastCoverageTypeCount, forKey: .lastCoverageTypeCount)
        try c.encode(lastCoverageDetectedMetricIDs, forKey: .lastCoverageDetectedMetricIDs)
        try c.encodeIfPresent(lastSchedulingError, forKey: .lastSchedulingError)
    }

    public static let `default` = AppSettings()
}

public enum StoredAccessRequestState: String, Codable, Sendable {
    case notRequested
    case requestRecommended
    case previouslyRequested
    case unavailable
}
