import Foundation
import HealthKit
import CoreLocation

enum HealthKitRecordMapper {
    static func quantityRecord(
        from sample: HKQuantitySample,
        metricID: String,
        unit: HKUnit,
        includeMetadata: Bool
    ) -> QuantityRecord {
        let rawValue = sample.quantity.doubleValue(for: unit)
        // HealthKit's percent unit is a 0...1 fraction. OpenHealth schema uses
        // the conventional 0...100 representation whenever the unit is "%".
        let value = HealthMetricCatalogCore.percentMetricIDs.contains(metricID)
            ? rawValue * 100
            : rawValue
        return QuantityRecord(
            id: sample.uuid,
            metricID: metricID,
            value: value,
            unit: unit.unitString,
            startDate: sample.startDate,
            endDate: sample.endDate,
            sourceName: sample.sourceRevision.source.name,
            sourceBundleID: sample.sourceRevision.source.bundleIdentifier,
            metadata: includeMetadata ? sanitizeMetadata(sample.metadata) : nil
        )
    }

    static func categoryRecord(
        from sample: HKCategorySample,
        metricID: String,
        includeMetadata: Bool
    ) -> CategoryRecord {
        CategoryRecord(
            id: sample.uuid,
            metricID: metricID,
            value: sample.value,
            valueLabel: categoryLabel(metricID: metricID, value: sample.value),
            startDate: sample.startDate,
            endDate: sample.endDate,
            sourceName: sample.sourceRevision.source.name,
            sourceBundleID: sample.sourceRevision.source.bundleIdentifier,
            metadata: includeMetadata ? sanitizeMetadata(sample.metadata) : nil
        )
    }

    static func workoutRecord(
        from workout: HKWorkout,
        routePoints: [RoutePointRecord]?,
        includeMetadata: Bool
    ) -> WorkoutRecord {
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        let activeEnergy = activeEnergyType
            .flatMap { workout.statistics(for: $0)?.sumQuantity() }
            .map { $0.doubleValue(for: .kilocalorie()) }

        return WorkoutRecord(
            id: workout.uuid,
            activityType: workoutActivityName(workout.workoutActivityType),
            activityTypeRaw: workout.workoutActivityType.rawValue,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            totalEnergyBurnedKilocalories: activeEnergy,
            totalDistanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
            sourceName: workout.sourceRevision.source.name,
            sourceBundleID: workout.sourceRevision.source.bundleIdentifier,
            routePoints: routePoints,
            metadata: includeMetadata ? sanitizeMetadata(workout.metadata) : nil
        )
    }

    static func routePoints(from locations: [CLLocation]) -> [RoutePointRecord] {
        var points = locations.map { loc in
            RoutePointRecord(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.verticalAccuracy >= 0 ? loc.altitude : nil,
                timestamp: loc.timestamp,
                speed: loc.speed >= 0 ? loc.speed : nil,
                course: loc.course >= 0 ? loc.course : nil
            )
        }
        points.sort { $0.timestamp < $1.timestamp }
        // De-duplicate identical timestamp/coordinate points
        var deduped: [RoutePointRecord] = []
        for p in points {
            if let last = deduped.last,
               last.timestamp == p.timestamp,
               last.latitude == p.latitude,
               last.longitude == p.longitude {
                continue
            }
            deduped.append(p)
        }
        return deduped
    }

    static func activitySummaryRecord(from summary: HKActivitySummary, calendar: Calendar) -> ActivitySummaryRecord? {
        let dateComponents = summary.dateComponents(for: calendar)
        guard let date = calendar.date(from: dateComponents) else { return nil }
        return ActivitySummaryRecord(
            date: date,
            activeEnergyBurned: summary.activeEnergyBurned.doubleValue(for: .kilocalorie()),
            activeEnergyBurnedGoal: summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()),
            appleExerciseTime: summary.appleExerciseTime.doubleValue(for: .minute()),
            appleExerciseTimeGoal: summary.appleExerciseTimeGoal.doubleValue(for: .minute()),
            appleStandHours: summary.appleStandHours.doubleValue(for: .count()),
            appleStandHoursGoal: summary.appleStandHoursGoal.doubleValue(for: .count())
        )
    }

    // MARK: - Helpers

    static func sanitizeMetadata(_ metadata: [String: Any]?) -> [String: String]? {
        guard let metadata, !metadata.isEmpty else { return nil }
        var result: [String: String] = [:]
        let redactedKeys: Set<String> = [
            HKMetadataKeySyncIdentifier,
            "HKExternalUUID"
        ]
        for (key, value) in metadata {
            if redactedKeys.contains(key) { continue }
            switch value {
            case let s as String: result[key] = s
            case let n as NSNumber: result[key] = n.stringValue
            case let b as Bool: result[key] = b ? "true" : "false"
            case let d as Date: result[key] = ExportDocument.iso8601Fractional.string(from: d)
            default: continue
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func categoryLabel(metricID: String, value: Int) -> String? {
        if metricID.contains("SleepAnalysis") {
            switch value {
            case 0: return "inBed"
            case 1: return "asleepUnspecified"
            case 2: return "awake"
            case 3: return "asleepCore"
            case 4: return "asleepDeep"
            case 5: return "asleepREM"
            default: return "value_\(value)"
            }
        }
        return "value_\(value)"
    }

    static func workoutActivityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .dance, .cardioDance: return "Dance"
        case .cooldown: return "Cooldown"
        case .other: return "Other"
        default: return "Workout"
        }
    }
}
