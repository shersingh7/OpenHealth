// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class ExportPipelineContractTests: XCTestCase {
    func testFullSuccess() async throws {
        let health = FakeHealthDataSource(snapshot: HealthDataSnapshot(
            quantityRecords: [TestFixtures.sampleQuantity()],
            categoryRecords: [TestFixtures.sampleCategory()],
            workouts: [TestFixtures.sampleWorkout(withRoute: true)]
        ))
        let secrets = FakeSecretStore()
        let history = FakeHistoryRepository()
        let dest = FakeDestinationClient()
        let local = ExportDestination.defaultLocal()
        let request = ExportRequest(
            name: "Test",
            selection: .explicit(["HKQuantityTypeIdentifierStepCount"]),
            range: .last24Hours,
            format: .json,
            destinationIDs: [local.id]
        )

        let pipeline = ExportPipelineCoordinator(
            healthDataSource: health,
            secretStore: secrets,
            historyRepository: history,
            clock: FixedClock(TestFixtures.fixedNow),
            calendar: {
                var c = Calendar(identifier: .gregorian)
                c.timeZone = TimeZone(identifier: "UTC")!
                return c
            }(),
            appVersion: "test",
            destinationClients: [.localFiles: dest]
        )

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let report = await pipeline.run(
            context: .init(request: request, destinations: [local], temporaryDirectory: tmp)
        )
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertEqual(report.outcome, .completeSuccess)
        XCTAssertEqual(report.serializedRecordCount, 3)
        XCTAssertEqual(report.destinationResults.count, 1)
        XCTAssertTrue(report.destinationResults[0].success)
        let count = try await history.count()
        XCTAssertEqual(count, 1)
        let fetchCount = await health.fetchCallCount
        XCTAssertEqual(fetchCount, 1)
    }

    func testPartialSuccess() async throws {
        let health = FakeHealthDataSource(snapshot: HealthDataSnapshot(
            quantityRecords: [TestFixtures.sampleQuantity()]
        ))
        let ok = FakeDestinationClient()
        await ok.setResults([DestinationDeliveryOutcome(success: true, finalURL: URL(fileURLWithPath: "/a"), bytesWritten: 1)])
        let fail = FakeDestinationClient()
        await fail.setResults([DestinationDeliveryOutcome(success: false, errorDescription: "network")])

        // Use one client that fails second call by alternating — use two kinds with same actor types
        // Simpler: one destination fails validation path via custom client results per call
        let multi = AlternatingDestinationClient(outcomes: [
            DestinationDeliveryOutcome(success: true, finalURL: URL(fileURLWithPath: "/a"), bytesWritten: 10),
            DestinationDeliveryOutcome(success: false, errorDescription: "fail")
        ])

        let d1 = ExportDestination(kind: .localFiles, name: "Local", config: .localFiles(folderPath: nil))
        let d2 = ExportDestination(kind: .iCloudDrive, name: "iCloud", config: .iCloudDrive(folderPath: nil))
        let request = ExportRequest(
            name: "Partial",
            selection: .allDetected,
            range: .today,
            format: .json,
            destinationIDs: [d1.id, d2.id]
        )

        let pipeline = ExportPipelineCoordinator(
            healthDataSource: health,
            secretStore: FakeSecretStore(),
            historyRepository: FakeHistoryRepository(),
            clock: FixedClock(TestFixtures.fixedNow),
            destinationClients: [
                .localFiles: multi,
                .iCloudDrive: multi
            ]
        )

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let report = await pipeline.run(
            context: .init(request: request, destinations: [d1, d2], temporaryDirectory: tmp)
        )
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertEqual(report.outcome, .partialSuccess)
    }

    func testValidationFailureNoFetch() async throws {
        let health = FakeHealthDataSource()
        let request = ExportRequest(
            name: "Bad",
            selection: .explicit([]),
            range: .today,
            format: .json,
            destinationIDs: []
        )
        let pipeline = ExportPipelineCoordinator(
            healthDataSource: health,
            secretStore: FakeSecretStore(),
            historyRepository: FakeHistoryRepository(),
            clock: FixedClock(TestFixtures.fixedNow),
            destinationClients: [:]
        )
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let report = await pipeline.run(
            context: .init(request: request, destinations: [], temporaryDirectory: tmp)
        )
        XCTAssertEqual(report.outcome, .failure)
        let fetchCount = await health.fetchCallCount
        XCTAssertEqual(fetchCount, 0)
    }

    func testGPXWithoutRoutesFailsEncoding() async throws {
        let health = FakeHealthDataSource(snapshot: HealthDataSnapshot(
            workouts: [TestFixtures.sampleWorkout(withRoute: false)]
        ))
        let local = ExportDestination.defaultLocal()
        let request = ExportRequest(
            name: "GPX",
            selection: .explicit([HealthMetricCatalogCore.workoutsID, HealthMetricCatalogCore.workoutRoutesID]),
            range: .today,
            format: .gpx,
            destinationIDs: [local.id],
            includeWorkoutRoutes: true
        )
        let pipeline = ExportPipelineCoordinator(
            healthDataSource: health,
            secretStore: FakeSecretStore(),
            historyRepository: FakeHistoryRepository(),
            clock: FixedClock(TestFixtures.fixedNow),
            destinationClients: [.localFiles: FakeDestinationClient()]
        )
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let report = await pipeline.run(
            context: .init(request: request, destinations: [local], temporaryDirectory: tmp)
        )
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertEqual(report.outcome, .failure)
    }
}

actor AlternatingDestinationClient: ExportDestinationClient {
    private var outcomes: [DestinationDeliveryOutcome]
    private var index = 0

    init(outcomes: [DestinationDeliveryOutcome]) {
        self.outcomes = outcomes
    }

    func deliver(_ request: DestinationDeliveryRequest) async throws -> DestinationDeliveryOutcome {
        let outcome = outcomes[min(index, outcomes.count - 1)]
        index += 1
        return outcome
    }
}
