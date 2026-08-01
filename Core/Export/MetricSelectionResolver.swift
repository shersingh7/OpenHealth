import Foundation

/// Pure selection rules for which HealthKit metrics and location-bearing data to read.
/// Explicit selections never expand to workouts/routes solely because a route toggle is on.
public enum MetricSelectionResolver {

    /// Resolves the metric ID set for a request.
    /// `.allDetected` is treated as **all supported** catalog types (truthful behavior; not a live detection scan).
    public static func resolveMetricIDs(
        selection: ExportRequest.Selection,
        includeWorkoutRoutes: Bool
    ) -> Set<String> {
        switch selection {
        case .allDetected:
            var ids = HealthMetricCatalogCore.supportedQuantityIDs
                .union(HealthMetricCatalogCore.supportedCategoryIDs)
            ids.insert(HealthMetricCatalogCore.workoutsID)
            ids.insert(HealthMetricCatalogCore.electrocardiogramsID)
            ids.insert(HealthMetricCatalogCore.activitySummariesID)
            if includeWorkoutRoutes {
                ids.insert(HealthMetricCatalogCore.workoutRoutesID)
            }
            return ids
        case .explicit(let ids):
            return ids
        }
    }

    /// Workouts are queried only when workouts or routes appear in the resolved metric set.
    public static func shouldQueryWorkouts(metricIDs: Set<String>) -> Bool {
        metricIDs.contains(HealthMetricCatalogCore.workoutsID)
            || metricIDs.contains(HealthMetricCatalogCore.workoutRoutesID)
    }

    /// Route (location) data is included only when routes are selected, or when the
    /// deliberate route toggle is on **and** workouts are part of the selection.
    public static func shouldIncludeRoutes(
        metricIDs: Set<String>,
        includeWorkoutRoutes: Bool
    ) -> Bool {
        if metricIDs.contains(HealthMetricCatalogCore.workoutRoutesID) {
            return true
        }
        return includeWorkoutRoutes && metricIDs.contains(HealthMetricCatalogCore.workoutsID)
    }
}
