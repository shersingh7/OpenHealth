// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class ExportSchemaTests: XCTestCase {
    func testTotalRecordsDerivedFromSections() {
        let doc = TestFixtures.sampleDocument()
        let expected = doc.quantityRecords.count
            + doc.categoryRecords.count
            + doc.workouts.count
            + doc.electrocardiograms.count
            + doc.activitySummaries.count
        XCTAssertEqual(doc.totalRecords, expected)
        XCTAssertEqual(doc.schemaVersion, 1)
    }

    func testJSONRoundTrip() throws {
        let doc = TestFixtures.sampleDocument()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("export.json")
        try JSONExportEncoder.encode(doc, to: url)
        let decoded = try JSONExportEncoder.decode(from: url)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.exportID, doc.exportID)
        XCTAssertEqual(decoded.totalRecords, doc.totalRecords)
        XCTAssertEqual(decoded.quantityRecords.count, doc.quantityRecords.count)
        XCTAssertEqual(decoded.quantityRecords.first?.value, 1234)
        XCTAssertEqual(decoded.workouts.first?.routePoints?.count, 2)
        XCTAssertEqual(decoded.activitySummaries.count, 1)
    }

    func testEmptyDocumentCountsZero() {
        let doc = ExportDocument(
            exportID: UUID(),
            generatedAt: TestFixtures.fixedNow,
            appVersion: "1.0",
            requestedRange: DateInterval(start: TestFixtures.fixedNow, end: TestFixtures.fixedNow.addingTimeInterval(1)),
            includedMetricIDs: []
        )
        XCTAssertEqual(doc.totalRecords, 0)
    }
}
