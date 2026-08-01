import Foundation
@testable import OpenHealthCore

// MARK: - Fake Health Data Source

actor FakeHealthDataSource: HealthDataSource {
    var access: HealthAccessState
    var snapshot: HealthDataSnapshot
    var coverage: DataCoverageSnapshot
    var fetchCallCount = 0
    var shouldThrow: Error?

    init(
        access: HealthAccessState = HealthAccessState(
            isHealthDataAvailable: true,
            requestState: .previouslyRequested
        ),
        snapshot: HealthDataSnapshot = HealthDataSnapshot(),
        coverage: DataCoverageSnapshot? = nil
    ) {
        self.access = access
        self.snapshot = snapshot
        self.coverage = coverage ?? DataCoverageSnapshot(
            scannedAt: Date(timeIntervalSince1970: 1_700_000_000),
            detectedMetricIDs: [],
            supportedMetricCount: HealthMetricCatalogCore.allMetrics.count
        )
    }

    nonisolated func supportedMetricIDs() -> Set<String> {
        HealthMetricCatalogCore.supportedQuantityIDs.union(HealthMetricCatalogCore.supportedCategoryIDs)
    }

    func accessState() async -> HealthAccessState { access }

    func requestReadAccess() async throws -> HealthAccessState {
        access = HealthAccessState(
            isHealthDataAvailable: true,
            requestState: .previouslyRequested,
            lastRequestedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        return access
    }

    func fetchSnapshot(options: HealthQueryOptions) async throws -> HealthDataSnapshot {
        fetchCallCount += 1
        if let shouldThrow { throw shouldThrow }
        return snapshot
    }

    func scanCoverage(interval: DateInterval) async throws -> DataCoverageSnapshot {
        coverage
    }

    func setSnapshot(_ snapshot: HealthDataSnapshot) {
        self.snapshot = snapshot
    }
}

// MARK: - Fake Secret Store

actor FakeSecretStore: SecretStore {
    private var storage: [String: String] = [:]

    func save(secret: String, for reference: SecretReference) async throws {
        storage[reference.id] = secret
    }

    func load(reference: SecretReference) async throws -> String {
        guard let value = storage[reference.id] else { throw SecretStoreError.notFound }
        return value
    }

    func delete(reference: SecretReference) async throws {
        storage.removeValue(forKey: reference.id)
    }

    func exists(reference: SecretReference) async -> Bool {
        storage[reference.id] != nil
    }
}

// MARK: - Fake History Repository

actor FakeHistoryRepository: ExportHistoryRepository {
    var entries: [ExportHistoryEntry] = []

    func loadRecent(limit: Int) async throws -> [ExportHistoryEntry] {
        Array(entries.suffix(limit).reversed())
    }

    func append(_ entry: ExportHistoryEntry) async throws {
        entries.append(entry)
        if entries.count > 200 {
            entries.removeFirst(entries.count - 200)
        }
    }

    func clear() async throws {
        entries.removeAll()
    }

    func count() async throws -> Int { entries.count }
}

// MARK: - Fake Automation Repository

actor FakeAutomationRepository: AutomationRepository {
    var items: [Automation] = []

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

// MARK: - Fake Destination Client

actor FakeDestinationClient: ExportDestinationClient {
    var results: [DestinationDeliveryOutcome] = [
        DestinationDeliveryOutcome(success: true, finalURL: URL(fileURLWithPath: "/tmp/export"), bytesWritten: 100)
    ]
    var callCount = 0
    var lastRequest: DestinationDeliveryRequest?

    func deliver(_ request: DestinationDeliveryRequest) async throws -> DestinationDeliveryOutcome {
        callCount += 1
        lastRequest = request
        if results.isEmpty {
            return DestinationDeliveryOutcome(success: true, finalURL: request.artifactURL, bytesWritten: 1)
        }
        let index = min(callCount - 1, results.count - 1)
        return results[index]
    }

    func setResults(_ results: [DestinationDeliveryOutcome]) {
        self.results = results
        callCount = 0
    }
}

// MARK: - Fake Background Scheduler

final class FakeBackgroundScheduler: BackgroundTaskScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var submitted: [BackgroundTaskRequest] = []
    private(set) var cancelled: [String] = []
    var throwOnSubmit: Error?

    func submit(_ request: BackgroundTaskRequest) throws {
        lock.lock()
        defer { lock.unlock() }
        if let throwOnSubmit { throw throwOnSubmit }
        submitted.removeAll { $0.identifier == request.identifier }
        submitted.append(request)
    }

    func cancel(identifier: String) {
        lock.lock()
        defer { lock.unlock() }
        cancelled.append(identifier)
        submitted.removeAll { $0.identifier == identifier }
    }

    func cancelAll() {
        lock.lock()
        defer { lock.unlock() }
        submitted.removeAll()
    }

    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return submitted.count
    }

    var latest: BackgroundTaskRequest? {
        lock.lock()
        defer { lock.unlock() }
        return submitted.last
    }
}

// MARK: - Fake Settings Store

actor FakeSettingsStore: SettingsStore {
    var settings: AppSettings = .default

    func load() async -> AppSettings { settings }

    func save(_ settings: AppSettings) async throws {
        self.settings = settings
    }
}

// MARK: - Sample Fixtures

enum TestFixtures {
    static let fixedNow = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00:00 UTC

    static func sampleQuantity(id: UUID = UUID()) -> QuantityRecord {
        QuantityRecord(
            id: id,
            metricID: "HKQuantityTypeIdentifierStepCount",
            value: 1234,
            unit: "count",
            startDate: Date(timeIntervalSince1970: 1_704_000_000),
            endDate: Date(timeIntervalSince1970: 1_704_000_600),
            sourceName: "Apple Watch",
            sourceBundleID: "com.apple.health"
        )
    }

    static func sampleCategory() -> CategoryRecord {
        CategoryRecord(
            id: UUID(),
            metricID: "HKCategoryTypeIdentifierSleepAnalysis",
            value: 1,
            valueLabel: "asleep",
            startDate: Date(timeIntervalSince1970: 1_704_000_000),
            endDate: Date(timeIntervalSince1970: 1_704_028_800),
            sourceName: "iPhone"
        )
    }

    static func sampleWorkout(withRoute: Bool) -> WorkoutRecord {
        let points: [RoutePointRecord]? = withRoute ? [
            RoutePointRecord(latitude: 37.77, longitude: -122.42, altitude: 10, timestamp: Date(timeIntervalSince1970: 1_704_000_000)),
            RoutePointRecord(latitude: 37.78, longitude: -122.41, altitude: 12, timestamp: Date(timeIntervalSince1970: 1_704_000_100))
        ] : nil
        return WorkoutRecord(
            id: UUID(),
            activityType: "Running",
            activityTypeRaw: 37,
            startDate: Date(timeIntervalSince1970: 1_704_000_000),
            endDate: Date(timeIntervalSince1970: 1_704_003_600),
            duration: 3600,
            totalEnergyBurnedKilocalories: 400,
            totalDistanceMeters: 5000,
            sourceName: "Apple Watch",
            routePoints: points
        )
    }

    static func sampleDocument() -> ExportDocument {
        ExportDocument(
            exportID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            generatedAt: fixedNow,
            appVersion: "1.0-test",
            requestedRange: DateInterval(start: Date(timeIntervalSince1970: 1_704_000_000), end: fixedNow),
            includedMetricIDs: ["HKQuantityTypeIdentifierStepCount"],
            quantityRecords: [sampleQuantity(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)],
            categoryRecords: [sampleCategory()],
            workouts: [sampleWorkout(withRoute: true)],
            electrocardiograms: [],
            activitySummaries: [
                ActivitySummaryRecord(
                    date: Date(timeIntervalSince1970: 1_704_000_000),
                    activeEnergyBurned: 300,
                    activeEnergyBurnedGoal: 500,
                    appleExerciseTime: 30,
                    appleExerciseTimeGoal: 30,
                    appleStandHours: 10,
                    appleStandHoursGoal: 12
                )
            ],
            warnings: []
        )
    }
}
