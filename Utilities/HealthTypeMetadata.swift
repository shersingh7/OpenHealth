//
//  HealthTypeMetadata.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import Foundation
import HealthKit

/// Centralized registry for health type metadata
enum HealthTypeMetadata {

    // MARK: - Activity Types

    static let activityTypes: Set<String> = [
        "stepCount", "distanceWalkingRunning", "distanceCycling", "distanceSwimming",
        "distanceDownhillSnowSports", "distanceWheelchair", "activeEnergyBurned",
        "basalEnergyBurned", "flightsClimbed", "appleExerciseTime", "appleMoveTime",
        "appleStandTime", "vo2Max", "physicalEffort"
    ]

    // MARK: - Cardiovascular Types

    static let cardiovascularTypes: Set<String> = [
        "heartRate", "restingHeartRate", "heartRateVariabilitySDNN",
        "walkingHeartRateAverage", "oxygenSaturation", "bloodPressureSystolic",
        "bloodPressureDiastolic"
    ]

    // MARK: - Body Measurement Types

    static let bodyMeasurementTypes: Set<String> = [
        "bodyMass", "height", "bodyMassIndex", "bodyFatPercentage",
        "leanBodyMass", "waistCircumference"
    ]

    // MARK: - Mobility Types

    static let mobilityTypes: Set<String> = [
        "walkingSpeed", "walkingStepLength", "walkingAsymmetryPercentage",
        "walkingDoubleSupportPercentage", "stairAscentSpeed", "stairDescentSpeed",
        "sixMinuteWalkTestDistance", "runningSpeed", "runningPower",
        "runningStrideLength", "runningGroundContactTime", "runningVerticalOscillation"
    ]

    // MARK: - Respiratory Types

    static let respiratoryTypes: Set<String> = [
        "respiratoryRate", "forcedExpiratoryVolume1", "forcedVitalCapacity",
        "peakExpiratoryFlowRate", "inhalerUsage"
    ]

    // MARK: - Nutrition Types

    static let nutritionTypes: Set<String> = [
        "dietaryEnergyConsumed", "dietaryWater", "dietaryCarbohydrates",
        "dietaryProtein", "dietaryFatTotal", "dietaryFatSaturated",
        "dietaryFatMonounsaturated", "dietaryFatPolyunsaturated",
        "dietaryCholesterol", "dietaryFiber", "dietarySugar", "dietarySodium",
        "dietaryPotassium", "dietaryCalcium", "dietaryIron",
        "dietaryVitaminA", "dietaryVitaminB6", "dietaryVitaminB12",
        "dietaryVitaminC", "dietaryVitaminD", "dietaryVitaminE", "dietaryVitaminK"
    ]

    // MARK: - Lifestyle Types

    static let lifestyleTypes: Set<String> = [
        "mindfulSessionDuration", "numberOfTimesFallen"
    ]

    // MARK: - Environmental Types

    static let environmentalTypes: Set<String> = [
        "environmentalAudioExposure", "headphoneAudioExposure",
        "timeInDaylight", "uvExposure"
    ]

    // MARK: - Sleep Types

    static let sleepTypes: Set<String> = [
        "sleepAnalysis"
    ]

    // MARK: - Symptom Types

    static let symptomTypes: Set<String> = [
        "abdominalCramps", "bloating", "constipation", "diarrhea", "heartburn",
        "nausea", "vomiting", "appetiteChanges", "chills", "dizziness",
        "fainting", "fatigue", "fever", "bodyAche", "hotFlashes",
        "chestTightness", "chestPain", "coughing", "rapidPoundingFlutteringHeartbeat",
        "shortnessOfBreath", "skippedHeartbeat", "wheezing", "lowerBackPain",
        "headache", "memoryLapse", "moodChanges", "lossOfSmell", "lossOfTaste",
        "runnyNose", "soreThroat", "sinusCongestion", "acne", "drySkin",
        "hairLoss", "nightSweats", "sleepChanges", "bladderIncontinence"
    ]

    // MARK: - Heart Rate Notification Types

    static let heartRateNotificationTypes: Set<String> = [
        "highHeartRateEvent", "lowHeartRateEvent", "irregularHeartRhythmEvent"
    ]

    // MARK: - State of Mind Types

    static let stateOfMindTypes: Set<String> = [
        "stateOfMind"
    ]

    // MARK: - Category Helper

    /// Determine the category for a health type identifier
    static func categorize(identifier: String) -> HealthDataCategory {
        // Strip any prefix if present
        let cleanId = identifier
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")

        if activityTypes.contains(cleanId) { return .activity }
        if cardiovascularTypes.contains(cleanId) { return .cardiovascular }
        if bodyMeasurementTypes.contains(cleanId) { return .bodyMeasurements }
        if mobilityTypes.contains(cleanId) { return .mobility }
        if respiratoryTypes.contains(cleanId) { return .respiratory }
        if nutritionTypes.contains(cleanId) { return .nutrition }
        if lifestyleTypes.contains(cleanId) { return .lifestyle }
        if environmentalTypes.contains(cleanId) { return .environmental }
        if sleepTypes.contains(cleanId) { return .sleep }
        if symptomTypes.contains(cleanId) { return .symptoms }
        if heartRateNotificationTypes.contains(cleanId) { return .heartRateNotifications }
        if stateOfMindTypes.contains(cleanId) { return .stateOfMind }

        return .healthRecords
    }

    // MARK: - Display Name Helper

    /// Generate a user-friendly display name from an identifier
    static func displayName(for identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .capitalized
    }

    // MARK: - Create Health Data Type

    /// Create a HealthDataType from an identifier
    static func createHealthDataType(for identifier: String) -> HealthDataType {
        HealthDataType(
            id: identifier,
            hkIdentifier: identifier,
            displayName: displayName(for: identifier),
            category: categorize(identifier: identifier),
            unit: "",
            description: ""
        )
    }

    /// Create a HealthDataType from a quantity type identifier
    static func createHealthDataType(for identifier: HKQuantityTypeIdentifier) -> HealthDataType {
        createHealthDataType(for: identifier.rawValue)
    }

    /// Create a HealthDataType from a category type identifier
    static func createHealthDataType(for identifier: HKCategoryTypeIdentifier) -> HealthDataType {
        createHealthDataType(for: identifier.rawValue)
    }
}