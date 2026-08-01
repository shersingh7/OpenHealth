// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class EncoderTests: XCTestCase {
    func testCSVContainsSectionsAndEscaping() throws {
        var doc = TestFixtures.sampleDocument()
        doc.quantityRecords.append(
            QuantityRecord(
                id: UUID(),
                metricID: "HKQuantityTypeIdentifierStepCount",
                value: 1,
                unit: "count",
                startDate: TestFixtures.fixedNow,
                endDate: TestFixtures.fixedNow,
                sourceName: "a,b\"c"
            )
        )
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("out.csv")
        try CSVExportEncoder.encode(doc, to: url)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("# SECTION: quantity"))
        XCTAssertTrue(text.contains("# SECTION: workouts"))
        XCTAssertTrue(text.contains("\"a,b\"\"c\""))
    }

    func testGPXFailsWithoutRoutes() {
        let workout = TestFixtures.sampleWorkout(withRoute: false)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("out.gpx")
        XCTAssertThrowsError(try GPXExportEncoder.encode(workouts: [workout], to: url)) { error in
            XCTAssertEqual(error as? GPXExportEncoder.Error, .noRouteData)
        }
    }

    func testGPXEscapesAndIsParseable() throws {
        let workout = TestFixtures.sampleWorkout(withRoute: true)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("out.gpx")
        try GPXExportEncoder.encode(workouts: [workout], to: url, creator: "OpenHealth & Co")
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("&amp;"))
        XCTAssertTrue(text.contains("<trkpt"))

        let parser = XMLParser(contentsOf: url)
        XCTAssertNotNil(parser)
        let ok = parser!.parse()
        XCTAssertTrue(ok, "XML parse error: \(parser!.parserError?.localizedDescription ?? "unknown")")
    }

    func testFilenameGeneratorUTC() {
        let name = FilenameGenerator.generate(
            prefix: "health export",
            format: .json,
            now: TestFixtures.fixedNow,
            timeZone: TimeZone(identifier: "UTC")!,
            collisionSuffix: "abcd1234"
        )
        XCTAssertTrue(name.hasPrefix("health_export_") || name.hasPrefix("health export_") || name.contains("20240101"))
        XCTAssertTrue(name.hasSuffix(".json"))
        XCTAssertTrue(name.contains("abcd1234"))
    }
}
