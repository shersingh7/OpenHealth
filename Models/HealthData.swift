//
//  HealthData.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import Foundation
import HealthKit
import CoreLocation

// MARK: - Health Data Type Categories

/// Categories of health data types available for export
enum HealthDataCategory: String, CaseIterable, Identifiable, Codable {
    case activity = "Activity"
    case bodyMeasurements = "Body Measurements"
    case cardiovascular = "Cardiovascular"
    case mobility = "Mobility"
    case respiratory = "Respiratory"
    case sleep = "Sleep"
    case nutrition = "Nutrition"
    case healthRecords = "Health Records"
    case lifestyle = "Lifestyle"
    case environmental = "Environmental"
    case workouts = "Workouts"
    case symptoms = "Symptoms"
    case cycleTracking = "Cycle Tracking"
    case medications = "Medications"
    case stateOfMind = "State of Mind"
    case ecg = "ECG"
    case heartRateNotifications = "Heart Rate Notifications"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .activity: return "figure.run"
        case .bodyMeasurements: return "scalemass.fill"
        case .cardiovascular: return "heart.fill"
        case .mobility: return "figure.walk"
        case .respiratory: return "lungs.fill"
        case .sleep: return "bed.double.fill"
        case .nutrition: return "fork.knife"
        case .healthRecords: return "doc.text.fill"
        case .lifestyle: return "sparkles"
        case .environmental: return "sun.max.fill"
        case .workouts: return "flame.fill"
        case .symptoms: return "cross.case.fill"
        case .cycleTracking: return "calendar.badge.clock"
        case .medications: return "pill.fill"
        case .stateOfMind: return "brain.head.profile"
        case .ecg: return "waveform.path.ecg"
        case .heartRateNotifications: return "bell.badge.heart.fill"
        }
    }
}

// MARK: - Health Data Type

/// Represents a single health data type that can be exported
struct HealthDataType: Identifiable, Codable, Hashable {
    let id: String
    let hkIdentifier: String
    let displayName: String
    let category: HealthDataCategory
    let unit: String
    let description: String

    var hkQuantityType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: hkIdentifier))
    }

    var hkCategoryType: HKCategoryType? {
        HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: hkIdentifier))
    }

    static func == (lhs: HealthDataType, rhs: HealthDataType) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Health Data Sample

/// Represents a health data sample with its metadata
struct HealthDataSample: Identifiable, Codable {
    let id: UUID
    let typeId: String
    let value: Double
    let unit: String
    let startDate: Date
    let endDate: Date
    let source: String
    let metadata: [String: String]?

    init(from sample: HKQuantitySample, typeId: String) {
        self.id = sample.uuid
        self.typeId = typeId
        let unit = HealthTypeMetadata.preferredUnit(for: typeId)
        self.value = sample.quantity.doubleValue(for: unit)
        self.unit = unit.unitString
        self.startDate = sample.startDate
        self.endDate = sample.endDate
        self.source = sample.sourceRevision.source.name
        self.metadata = sample.metadata?.mapValues { "\($0)" }
    }

    init(from sample: HKCategorySample, typeId: String) {
        self.id = sample.uuid
        self.typeId = typeId
        self.value = Double(sample.value)
        self.unit = ""
        self.startDate = sample.startDate
        self.endDate = sample.endDate
        self.source = sample.sourceRevision.source.name
        self.metadata = sample.metadata?.mapValues { "\($0)" }
    }
}

// MARK: - Health Data Category Sample

/// Represents a category sample (sleep, symptoms, etc.)
struct HealthDataCategorySample: Identifiable, Codable {
    let id: UUID
    let typeId: String
    let value: Int
    let startDate: Date
    let endDate: Date
    let source: String
    let metadata: [String: String]?

    init(from sample: HKCategorySample) {
        self.id = sample.uuid
        self.typeId = sample.categoryType.identifier
        self.value = sample.value
        self.startDate = sample.startDate
        self.endDate = sample.endDate
        self.source = sample.sourceRevision.source.name
        self.metadata = sample.metadata?.mapValues { "\($0)" }
    }
}

// MARK: - Health Data Bundle

/// Bundle containing all health data for export
struct HealthDataBundle {
    let quantitySamples: [HealthDataSample]
    let categorySamples: [HealthDataCategorySample]
    let workouts: [HKWorkout]
    let ecgReadings: [HKElectrocardiogram]
    let activitySummaries: [HKActivitySummary]

    var totalRecords: Int {
        quantitySamples.count + categorySamples.count + workouts.count + ecgReadings.count + activitySummaries.count
    }
}

// MARK: - Workout Data

/// Represents a workout with all its metrics
struct WorkoutData: Identifiable, Codable {
    let id: UUID
    let workoutType: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double?
    let totalDistance: Double?
    let heartRateData: [HealthDataSample]?
    let routeData: RouteData?

    init(from workout: HKWorkout, heartRateData: [HealthDataSample]? = nil, routeData: RouteData? = nil) {
        self.id = workout.uuid
        self.workoutType = WorkoutData.workoutTypeName(workout.workoutActivityType)
        self.startDate = workout.startDate
        self.endDate = workout.endDate
        self.duration = workout.duration
        self.totalEnergyBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        self.totalDistance = workout.totalDistance?.doubleValue(for: .meter())
        self.heartRateData = heartRateData
        self.routeData = routeData
    }

    static func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .americanFootball: return "American Football"
        case .archery: return "Archery"
        case .australianFootball: return "Australian Football"
        case .badminton: return "Badminton"
        case .baseball: return "Baseball"
        case .basketball: return "Basketball"
        case .bowling: return "Bowling"
        case .boxing: return "Boxing"
        case .climbing: return "Climbing"
        case .cricket: return "Cricket"
        case .crossCountrySkiing: return "Cross Country Skiing"
        case .curling: return "Curling"
        case .cycling: return "Cycling"
        case .dance: return "Dance"
        case .danceInspiredTraining: return "Dance Inspired Training"
        case .elliptical: return "Elliptical"
        case .equestrianSports: return "Equestrian Sports"
        case .fencing: return "Fencing"
        case .fishing: return "Fishing"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .golf: return "Golf"
        case .gymnastics: return "Gymnastics"
        case .handball: return "Handball"
        case .hiking: return "Hiking"
        case .hockey: return "Hockey"
        case .hunting: return "Hunting"
        case .lacrosse: return "Lacrosse"
        case .martialArts: return "Martial Arts"
        case .mindAndBody: return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Cardio"
        case .paddleSports: return "Paddle Sports"
        case .play: return "Play"
        case .preparationAndRecovery: return "Preparation and Recovery"
        case .racquetball: return "Racquetball"
        case .rowing: return "Rowing"
        case .rugby: return "Rugby"
        case .running: return "Running"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating Sports"
        case .snowboarding: return "Snowboarding"
        case .soccer: return "Soccer"
        case .softball: return "Softball"
        case .squash: return "Squash"
        case .stairClimbing: return "Stair Climbing"
        case .surfingSports: return "Surfing"
        case .swimming: return "Swimming"
        case .tableTennis: return "Table Tennis"
        case .tennis: return "Tennis"
        case .trackAndField: return "Track and Field"
        case .traditionalStrengthTraining: return "Strength Training"
        case .volleyball: return "Volleyball"
        case .walking: return "Walking"
        case .waterFitness: return "Water Fitness"
        case .waterPolo: return "Water Polo"
        case .waterSports: return "Water Sports"
        case .wrestling: return "Wrestling"
        case .yoga: return "Yoga"
        case .barre: return "Barre"
        case .coreTraining: return "Core Training"
        case .crossTraining: return "Cross Training"
        case .downhillSkiing: return "Downhill Skiing"
        case .flexibility: return "Flexibility"
        case .highIntensityIntervalTraining: return "HIIT"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .pilates: return "Pilates"
        case .stepTraining: return "Step Training"
        case .wheelchairWalkPace: return "Wheelchair Walk Pace"
        case .wheelchairRunPace: return "Wheelchair Run Pace"
        case .taiChi: return "Tai Chi"
        case .mixedCardio: return "Mixed Cardio"
        case .handCycling: return "Hand Cycling"
        case .discSports: return "Disc Sports"
        case .fitnessGaming: return "Fitness Gaming"
        case .cardioDance: return "Cardio Dance"
        case .socialDance: return "Social Dance"
        case .pickleball: return "Pickleball"
        case .transition: return "Transition"
        case .other: return "Other"
        default: return "Workout"
        }
    }
}

// MARK: - Route Data (GPS)

/// GPS route data for workouts
struct RouteData: Codable {
    let points: [RoutePoint]

    init(from locations: [CLLocation]) {
        self.points = locations.map { RoutePoint(from: $0) }
    }
}

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let speed: Double?
    let course: Double?

    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = location.timestamp
        self.speed = location.speed >= 0 ? location.speed : nil
        self.course = location.course >= 0 ? location.course : nil
    }
}

// MARK: - Export Result

/// Result of an export operation
struct ExportResult {
    let success: Bool
    let fileURL: URL?
    let error: Error?
    let recordsExported: Int
    let duration: TimeInterval
    var destinationResults: [DestinationResult]

    init(
        success: Bool,
        fileURL: URL?,
        error: Error?,
        recordsExported: Int,
        duration: TimeInterval,
        destinationResults: [DestinationResult] = []
    ) {
        self.success = success
        self.fileURL = fileURL
        self.error = error
        self.recordsExported = recordsExported
        self.duration = duration
        self.destinationResults = destinationResults
    }

    var errorMessage: String? {
        error?.localizedDescription
    }
}

/// Result for a single destination
struct DestinationResult {
    let destinationName: String
    let destinationType: String
    let success: Bool
    let error: Error?
    let recordsExported: Int

    var errorMessage: String? {
        error?.localizedDescription
    }
}

// MARK: - Activity Summary

/// Daily activity summary (Apple Watch rings)
struct ActivitySummary: Identifiable, Codable {
    let id: UUID
    let date: Date
    let activeEnergyBurned: Double
    let activeEnergyGoal: Double
    let exerciseTime: Double
    let exerciseGoal: Double
    let standTime: Double
    let standGoal: Double
    let moveTime: Double?
    let moveGoal: Double?

    var activeEnergyPercent: Double {
        guard activeEnergyGoal > 0 else { return 0 }
        return min(activeEnergyBurned / activeEnergyGoal, 1.0) * 100
    }

    var exercisePercent: Double {
        guard exerciseGoal > 0 else { return 0 }
        return min(exerciseTime / exerciseGoal, 1.0) * 100
    }

    var standPercent: Double {
        guard standGoal > 0 else { return 0 }
        return min(standTime / standGoal, 1.0) * 100
    }
}