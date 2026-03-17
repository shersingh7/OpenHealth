//
//  HealthKitService.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import Foundation
import HealthKit

/// Service for interacting with Apple HealthKit
@MainActor
class HealthKitService: ObservableObject {

    // MARK: - Properties

    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined

    // MARK: - Health Data Types

    /// All supported quantity types for export
    static let supportedQuantityTypes: [HKQuantityTypeIdentifier] = [
        // Activity
        .stepCount,
        .distanceWalkingRunning,
        .distanceCycling,
        .distanceSwimming,
        .distanceDownhillSnowSports,
        .distanceWheelchair,
        .activeEnergyBurned,
        .basalEnergyBurned,
        .flightsClimbed,
        .appleExerciseTime,
        .appleMoveTime,
        .appleStandTime,
        .vo2Max,
        .physicalEffort,

        // Body Measurements
        .bodyMass,
        .height,
        .bodyMassIndex,
        .bodyFatPercentage,
        .leanBodyMass,
        .waistCircumference,

        // Cardiovascular
        .heartRate,
        .restingHeartRate,
        .heartRateVariabilitySDNN,
        .walkingHeartRateAverage,
        .oxygenSaturation,
        .bloodPressureSystolic,
        .bloodPressureDiastolic,

        // Mobility
        .walkingSpeed,
        .walkingStepLength,
        .walkingAsymmetryPercentage,
        .walkingDoubleSupportPercentage,
        .stairAscentSpeed,
        .stairDescentSpeed,
        .sixMinuteWalkTestDistance,
        .runningSpeed,
        .runningPower,
        .runningStrideLength,
        .runningGroundContactTime,
        .runningVerticalOscillation,

        // Respiratory
        .respiratoryRate,
        .forcedExpiratoryVolume1,
        .forcedVitalCapacity,
        .peakExpiratoryFlowRate,
        .inhalerUsage,

        // Nutrition
        .dietaryEnergyConsumed,
        .dietaryWater,
        .dietaryCarbohydrates,
        .dietaryProtein,
        .dietaryFatTotal,
        .dietaryFatSaturated,
        .dietaryFatMonounsaturated,
        .dietaryFatPolyunsaturated,
        .dietaryCholesterol,
        .dietaryFiber,
        .dietarySugar,
        .dietarySodium,
        .dietaryPotassium,
        .dietaryCalcium,
        .dietaryIron,
        .dietaryVitaminA,
        .dietaryVitaminB6,
        .dietaryVitaminB12,
        .dietaryVitaminC,
        .dietaryVitaminD,
        .dietaryVitaminE,
        .dietaryVitaminK,

        // Lifestyle
        .mindfulSessionDuration,
        .numberOfTimesFallen,

        // Environmental
        .environmentalAudioExposure,
        .headphoneAudioExposure,
        .timeInDaylight,
        .uvExposure,

        // Other
        .bloodGlucose,
        .bodyTemperature,
        .peripheralPerfusionIndex
    ]

    /// All supported category types for export
    static let supportedCategoryTypes: [HKCategoryTypeIdentifier] = [
        // Sleep
        .sleepAnalysis,

        // Symptoms
        .abdominalCramps,
        .bloating,
        .constipation,
        .diarrhea,
        .heartburn,
        .nausea,
        .vomiting,
        .appetiteChanges,
        .chills,
        .dizziness,
        .fainting,
        .fatigue,
        .fever,
        .bodyAche,
        .hotFlashes,
        .chestTightness,
        .chestPain,
        .coughing,
        .rapidPoundingFlutteringHeartbeat,
        .shortnessOfBreath,
        .skippedHeartbeat,
        .wheezing,
        .lowerBackPain,
        .headache,
        .memoryLapse,
        .moodChanges,
        .lossOfSmell,
        .lossOfTaste,
        .runnyNose,
        .soreThroat,
        .sinusCongestion,
        .acne,
        .drySkin,
        .hairLoss,
        .nightSweats,
        .sleepChanges,
        .bladderIncontinence,

        // Heart Rate Notifications
        .highHeartRateEvent,
        .lowHeartRateEvent,
        .irregularHeartRhythmEvent,

        // State of Mind
        .stateOfMind
    ]

    // MARK: - Authorization

    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request authorization for all supported health data types
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        // Read types
        let readTypes: Set<HKObjectType> = Set(
            Self.supportedQuantityTypes.compactMap { HKQuantityType($0) } +
            Self.supportedCategoryTypes.compactMap { HKCategoryType($0) } +
            [
                HKObjectType.workoutType(),
                HKObjectType.electrocardiogramType(),
                HKSeriesType.workoutRoute(),
                HKSeriesType.heartbeat()
            ]
        )

        // Write types (we don't write, only read)
        let writeTypes: Set<HKSampleType> = []

        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)

        await MainActor.run {
            isAuthorized = true
            authorizationStatus = .sharingAuthorized
        }
    }

    /// Check authorization status for a specific type
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }

    // MARK: - Fetch Data

    /// Fetch quantity samples for a specific type
    func fetchQuantitySamples(
        type identifier: HKQuantityTypeIdentifier,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKQuantitySample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.invalidType
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(throwing: HealthKitError.invalidSample)
                    return
                }

                continuation.resume(resuming: .success(quantitySamples))
            }

            healthStore.execute(query)
        }
    }

    /// Fetch category samples for a specific type
    func fetchCategorySamples(
        type identifier: HKCategoryTypeIdentifier,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKCategorySample] {
        guard let categoryType = HKCategoryType.categoryType(forIdentifier: identifier) else {
            throw HealthKitError.invalidType
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(throwing: HealthKitError.invalidSample)
                    return
                }

                continuation.resume(resuming: .success(categorySamples))
            }

            healthStore.execute(query)
        }
    }

    /// Fetch workouts with optional routes
    func fetchWorkouts(from startDate: Date, to endDate: Date, includeRoutes: Bool = true) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(throwing: HealthKitError.invalidSample)
                    return
                }

                continuation.resume(resuming: .success(workouts))
            }

            healthStore.execute(query)
        }
    }

    /// Fetch workout route (GPS data)
    func fetchWorkoutRoute(for workout: HKWorkout) async throws -> [CLLocation] {
        let routeType = HKSeriesType.workoutRoute()

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSeriesQuery(seriesType: routeType, predicate: nil) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let routes = results as? [HKWorkoutRoute] else {
                    continuation.resume(throwing: HealthKitError.invalidSample)
                    return
                }

                // Get locations from route
                var allLocations: [CLLocation] = []
                let group = DispatchGroup()

                for route in routes {
                    group.enter()
                    let locationQuery = HKWorkoutRouteQuery(route: route) { _, locations, _, error in
                        if let locations = locations {
                            allLocations.append(contentsOf: locations)
                        }
                        group.leave()
                    }
                    // Note: HKWorkoutRouteQuery needs to be handled differently
                    // This is a simplified version
                }

                group.notify(queue: .main) {
                    continuation.resume(resuming: .success(allLocations))
                }
            }

            healthStore.execute(query)
        }
    }

    /// Fetch activity summaries (Apple Watch rings)
    func fetchActivitySummaries(from startDate: Date, to endDate: Date) async throws -> [HKActivitySummary] {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)

        let predicate = HKQuery.predicateForActivitySummaries(withStart: startComponents, end: endComponents)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let activitySummaries = summaries else {
                    continuation.resume(throwing: HealthKitError.invalidSample)
                    return
                }

                continuation.resume(resuming: .success(activitySummaries))
            }

            healthStore.execute(query)
        }
    }

    /// Get available data types (types that have data)
    func getAvailableDataTypes() async -> Set<HKQuantityTypeIdentifier> {
        var availableTypes: Set<HKQuantityTypeIdentifier> = []

        for identifier in Self.supportedQuantityTypes {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }

            let predicate = HKQuery.predicateForSamples(
                withStart: Calendar.current.date(byAdding: .year, value: -10, to: Date()),
                end: Date(),
                options: .strictStartDate
            )

            let hasData = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, samples, _ in
                    continuation.resume(returning: samples?.isEmpty == false)
                }

                healthStore.execute(query)
            }

            if hasData {
                availableTypes.insert(identifier)
            }
        }

        return availableTypes
    }

    /// Fetch all health data (quantity types, category types, workouts, ECG, activity summaries) for a date range
    func fetchAllHealthData(from startDate: Date, to endDate: Date) async throws -> HealthDataBundle {
        var allSamples: [HealthDataSample] = []
        var allCategorySamples: [HealthDataCategorySample] = []
        var workouts: [HKWorkout] = []
        var ecgReadings: [HKElectrocardiogram] = []
        var activitySummaries: [HKActivitySummary] = []

        // Fetch all quantity samples
        for identifier in Self.supportedQuantityTypes {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            do {
                let samples = try await fetchQuantitySamples(type: identifier, from: startDate, to: endDate)
                allSamples.append(contentsOf: samples.map { HealthDataSample(from: $0) })
            } catch {
                print("Failed to fetch quantity type \(identifier): \(error)")
            }
        }

        // Fetch all category samples
        for identifier in Self.supportedCategoryTypes {
            guard let type = HKCategoryType.categoryType(forIdentifier: identifier) else { continue }
            do {
                let samples = try await fetchCategorySamples(type: identifier, from: startDate, to: endDate)
                allCategorySamples.append(contentsOf: samples.map { HealthDataCategorySample(from: $0) })
            } catch {
                print("Failed to fetch category type \(identifier): \(error)")
            }
        }

        // Fetch workouts
        do {
            workouts = try await fetchWorkouts(from: startDate, to: endDate, includeRoutes: true)
        } catch {
            print("Failed to fetch workouts: \(error)")
        }

        // Fetch ECG readings
        do {
            ecgReadings = try await fetchECGReadings(from: startDate, to: endDate)
        } catch {
            print("Failed to fetch ECG: \(error)")
        }

        // Fetch activity summaries
        do {
            activitySummaries = try await fetchActivitySummaries(from: startDate, to: endDate)
        } catch {
            print("Failed to fetch activity summaries: \(error)")
        }

        return HealthDataBundle(
            quantitySamples: allSamples,
            categorySamples: allCategorySamples,
            workouts: workouts,
            ecgReadings: ecgReadings,
            activitySummaries: activitySummaries
        )
    }

    /// Fetch ECG readings for a date range
    func fetchECGReadings(from startDate: Date, to endDate: Date) async throws -> [HKElectrocardiogram] {
        guard #available(iOS 14.0, *) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let ecgType = HKObjectType.electrocardiogramType()

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: ecgType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                    continuation.resume(returning: [])
                    return
                }

                continuation.resume(returning: ecgSamples)
            }

            healthStore.execute(query)
        }
    }

    /// Get all available data types (includes both quantity and category types)
    func getAllAvailableDataTypes() async -> Set<String> {
        var availableTypes: Set<String> = []

        // Check quantity types
        for identifier in Self.supportedQuantityTypes {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }

            let predicate = HKQuery.predicateForSamples(
                withStart: Calendar.current.date(byAdding: .year, value: -10, to: Date()),
                end: Date(),
                options: .strictStartDate
            )

            let hasData = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, samples, _ in
                    continuation.resume(returning: samples?.isEmpty == false)
                }

                healthStore.execute(query)
            }

            if hasData {
                availableTypes.insert(identifier.rawValue)
            }
        }

        // Check category types
        for identifier in Self.supportedCategoryTypes {
            guard let type = HKCategoryType.categoryType(forIdentifier: identifier) else { continue }

            let predicate = HKQuery.predicateForSamples(
                withStart: Calendar.current.date(byAdding: .year, value: -10, to: Date()),
                end: Date(),
                options: .strictStartDate
            )

            let hasData = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, samples, _ in
                    continuation.resume(returning: samples?.isEmpty == false)
                }

                healthStore.execute(query)
            }

            if hasData {
                availableTypes.insert(identifier.rawValue)
            }
        }

        return availableTypes
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case invalidType
    case invalidSample
    case unauthorized
    case queryFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .invalidType:
            return "Invalid health data type"
        case .invalidSample:
            return "Invalid health data sample"
        case .unauthorized:
            return "HealthKit access not authorized"
        case .queryFailed(let error):
            return "Query failed: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}

import CoreLocation