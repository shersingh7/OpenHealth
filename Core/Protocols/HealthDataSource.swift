import Foundation

public struct HealthQueryOptions: Sendable {
    public let metricIDs: Set<String>
    public let interval: DateInterval
    public let includeMetadata: Bool
    public let includeWorkoutRoutes: Bool
    public let includeECGWaveforms: Bool

    public init(
        metricIDs: Set<String>,
        interval: DateInterval,
        includeMetadata: Bool,
        includeWorkoutRoutes: Bool,
        includeECGWaveforms: Bool
    ) {
        self.metricIDs = metricIDs
        self.interval = interval
        self.includeMetadata = includeMetadata
        self.includeWorkoutRoutes = includeWorkoutRoutes
        self.includeECGWaveforms = includeECGWaveforms
    }
}

public struct DataCoverageSnapshot: Sendable, Equatable {
    public let scannedAt: Date
    public let detectedMetricIDs: Set<String>
    public let supportedMetricCount: Int

    public init(scannedAt: Date, detectedMetricIDs: Set<String>, supportedMetricCount: Int) {
        self.scannedAt = scannedAt
        self.detectedMetricIDs = detectedMetricIDs
        self.supportedMetricCount = supportedMetricCount
    }

    public var detectedCount: Int { detectedMetricIDs.count }
}

/// Minimal HealthKit-free protocol for reading health data.
public protocol HealthDataSource: Sendable {
    func accessState() async -> HealthAccessState
    func requestReadAccess() async throws -> HealthAccessState
    func fetchSnapshot(options: HealthQueryOptions) async throws -> HealthDataSnapshot
    func scanCoverage(interval: DateInterval) async throws -> DataCoverageSnapshot
    func supportedMetricIDs() -> Set<String>
}
