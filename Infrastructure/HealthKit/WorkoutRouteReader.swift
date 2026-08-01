import Foundation
import HealthKit
import CoreLocation

/// Executes HKWorkoutRouteQuery correctly: accumulates all batches until done,
/// resumes continuation once, and honors cancellation.
actor WorkoutRouteReader {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func fetchRoutePoints(for workout: HKWorkout) async throws -> [RoutePointRecord] {
        try Task.checkCancellation()

        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }

        guard !routes.isEmpty else { return [] }

        var allLocations: [CLLocation] = []
        for route in routes {
            try Task.checkCancellation()
            let locations = try await fetchLocations(for: route)
            allLocations.append(contentsOf: locations)
        }
        return HealthKitRecordMapper.routePoints(from: allLocations)
    }

    private func fetchLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { continuation in
            let accumulator = RouteLocationAccumulator()

            let query = HKWorkoutRouteQuery(route: route) { _, locationsOrNil, done, error in
                if let completion = accumulator.consume(
                    locations: locationsOrNil ?? [],
                    done: done,
                    error: error
                ) {
                    continuation.resume(with: completion)
                }
            }
            healthStore.execute(query)
        }
    }
}

/// Serializes state shared by potentially concurrent HealthKit route callbacks.
private final class RouteLocationAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var locations: [CLLocation] = []
    private var finished = false

    func consume(
        locations newLocations: [CLLocation],
        done: Bool,
        error: Error?
    ) -> Result<[CLLocation], Error>? {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return nil }

        if let error {
            finished = true
            return .failure(error)
        }
        locations.append(contentsOf: newLocations)
        guard done else { return nil }
        finished = true
        return .success(locations)
    }
}
