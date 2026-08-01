import Foundation
import HealthKit

/// Typed HealthKit catalog: maps exact raw IDs to HK types and compatible units.
/// Core stores portable strings; this file owns HealthKit types.
enum HealthMetricCatalog {
    static var allSupportedObjectTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        for id in HealthMetricCatalogCore.supportedQuantityIDs {
            let short = HealthMetricCatalogCore.shortName(from: id)
            if let t = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: short)) {
                types.insert(t)
            } else if let t = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id)) {
                types.insert(t)
            }
        }
        for id in HealthMetricCatalogCore.supportedCategoryIDs {
            let short = HealthMetricCatalogCore.shortName(from: id)
            if let t = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: short)) {
                types.insert(t)
            } else if let t = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: id)) {
                types.insert(t)
            }
        }
        types.insert(HKObjectType.workoutType())
        types.insert(HKSeriesType.workoutRoute())
        types.insert(HKObjectType.electrocardiogramType())
        types.insert(HKObjectType.activitySummaryType())
        return types
    }

    static func quantityType(for metricID: String) -> HKQuantityType? {
        let short = HealthMetricCatalogCore.shortName(from: metricID)
        if let t = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: short)) {
            return t
        }
        return HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: metricID))
    }

    static func categoryType(for metricID: String) -> HKCategoryType? {
        let short = HealthMetricCatalogCore.shortName(from: metricID)
        if let t = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: short)) {
            return t
        }
        return HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: metricID))
    }

    /// Compatible unit for a quantity metric. Never falls back to `.count()` for unknown types.
    static func unit(for metricID: String) -> HKUnit? {
        guard let metric = HealthMetricCatalogCore.metric(for: metricID), metric.kind == .quantity else {
            return nil
        }
        return unit(fromCanonicalString: metric.canonicalUnit ?? "")
    }

    static func unit(fromCanonicalString string: String) -> HKUnit? {
        switch string {
        case "count": return .count()
        case "m": return .meter()
        case "cm": return HKUnit.meterUnit(with: .centi)
        case "km": return .meterUnit(with: .kilo)
        case "min": return .minute()
        case "s": return .second()
        case "ms": return HKUnit.secondUnit(with: .milli)
        case "kcal": return .kilocalorie()
        case "count/min": return HKUnit.count().unitDivided(by: .minute())
        case "%": return .percent()
        case "mmHg": return .millimeterOfMercury()
        case "kg": return HKUnit.gramUnit(with: .kilo)
        case "g": return .gram()
        case "mg": return HKUnit.gramUnit(with: .milli)
        case "mcg": return HKUnit.gramUnit(with: .micro)
        case "L": return .liter()
        case "L/min": return .liter().unitDivided(by: .minute())
        case "m/s": return .meter().unitDivided(by: .second())
        case "W": return .watt()
        case "degC": return .degreeCelsius()
        case "mg/dL": return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        case "dBASPL": return HKUnit.decibelAWeightedSoundPressureLevel()
        case "mL/kg·min":
            return HKUnit.literUnit(with: .milli)
                .unitDivided(by: HKUnit.gramUnit(with: .kilo))
                .unitDivided(by: .minute())
        case "kcal/hr·kg":
            return HKUnit.kilocalorie()
                .unitDivided(by: .hour())
                .unitDivided(by: HKUnit.gramUnit(with: .kilo))
        default:
            // Unknown canonical unit strings return nil → typed unsupported warning (never silent .count()).
            return nil
        }
    }
}
