// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class HealthMetricTests: XCTestCase {
    func testUniqueIDs() {
        let ids = HealthMetricCatalogCore.allMetrics.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testPercentMetricIndexUsesCanonicalPercentUnits() {
        XCTAssertTrue(HealthMetricCatalogCore.percentMetricIDs.contains("HKQuantityTypeIdentifierOxygenSaturation"))
        XCTAssertTrue(HealthMetricCatalogCore.percentMetricIDs.contains("HKQuantityTypeIdentifierBodyFatPercentage"))
        XCTAssertFalse(HealthMetricCatalogCore.percentMetricIDs.contains("HKQuantityTypeIdentifierStepCount"))
    }

    func testQuantityUnitsPresentCategoryUnitsAbsent() {
        for m in HealthMetricCatalogCore.quantityMetrics {
            XCTAssertNotNil(m.canonicalUnit)
            XCTAssertFalse(m.canonicalUnit!.isEmpty)
        }
        for m in HealthMetricCatalogCore.categoryMetrics {
            XCTAssertNil(m.canonicalUnit)
        }
    }

    func testStepCountUsesFullRawIDAndCountUnit() {
        let metric = HealthMetricCatalogCore.metric(for: "HKQuantityTypeIdentifierStepCount")
        XCTAssertNotNil(metric)
        XCTAssertEqual(metric?.canonicalUnit, "count")
        XCTAssertEqual(metric?.kind, .quantity)
    }

    func testHeartRateNotCountFallback() {
        let metric = HealthMetricCatalogCore.metric(for: "HKQuantityTypeIdentifierHeartRate")
        XCTAssertEqual(metric?.canonicalUnit, "count/min")
    }

    func testBodyMassUsesKilograms() {
        let metric = HealthMetricCatalogCore.metric(for: "HKQuantityTypeIdentifierBodyMass")
        XCTAssertEqual(metric?.canonicalUnit, "kg")
    }

    func testDisplayOrderingByCategory() {
        let sorted = HealthMetricCatalogCore.allMetrics.sorted {
            if $0.category.sortOrder != $1.category.sortOrder {
                return $0.category.sortOrder < $1.category.sortOrder
            }
            return $0.displayName < $1.displayName
        }
        XCTAssertEqual(sorted.count, HealthMetricCatalogCore.allMetrics.count)
    }

    func testNormalizeIdentifierTrims() {
        let id = HealthMetricCatalogCore.normalizeIdentifier("  HKQuantityTypeIdentifierStepCount  ")
        XCTAssertEqual(id, "HKQuantityTypeIdentifierStepCount")
    }

    func testShortNameStripsPrefix() {
        XCTAssertEqual(
            HealthMetricCatalogCore.shortName(from: "HKQuantityTypeIdentifierStepCount"),
            "StepCount"
        )
    }

    func testNoCountUnitForDistance() {
        let metric = HealthMetricCatalogCore.metric(for: "HKQuantityTypeIdentifierDistanceWalkingRunning")
        XCTAssertEqual(metric?.canonicalUnit, "m")
        XCTAssertNotEqual(metric?.canonicalUnit, "count")
    }
}
