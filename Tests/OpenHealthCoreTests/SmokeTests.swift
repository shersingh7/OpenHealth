// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class SmokeTests: XCTestCase {
    func testModuleImportsAndDateRangeResolves() throws {
        let now = Date(timeIntervalSince1970: 1_704_067_200)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let interval = try DateRangeResolver.resolve(.today, now: now, calendar: calendar)
        XCTAssertEqual(interval.start, calendar.startOfDay(for: now))
        XCTAssertGreaterThan(interval.end, interval.start)
    }

    func testCatalogInvariants() {
        let issues = HealthMetricCatalogCore.validateInvariants()
        XCTAssertTrue(issues.isEmpty, "Catalog issues: \(issues)")
        XCTAssertFalse(HealthMetricCatalogCore.quantityMetrics.isEmpty)
        XCTAssertFalse(HealthMetricCatalogCore.categoryMetrics.isEmpty)
    }
}
