import Foundation

/// Portable health metric descriptor. IDs are exact HealthKit raw identifiers.
public struct HealthMetric: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case quantity
        case category
        case workout
        case workoutRoute
        case electrocardiogram
        case activitySummary
    }

    public enum MetricAvailability: String, Codable, Sendable {
        case always
        case ios17Plus
        case requiresWatch
        case deviceDependent
    }

    public let id: String
    public let displayName: String
    public let category: HealthDataCategory
    public let kind: Kind
    /// Canonical unit string for quantity types; nil for non-quantity kinds.
    public let canonicalUnit: String?
    public let availability: MetricAvailability

    public init(
        id: String,
        displayName: String,
        category: HealthDataCategory,
        kind: Kind,
        canonicalUnit: String? = nil,
        availability: MetricAvailability = .always
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.kind = kind
        self.canonicalUnit = canonicalUnit
        self.availability = availability
    }
}

/// Categories of health data types available for export.
public enum HealthDataCategory: String, CaseIterable, Identifiable, Codable, Sendable {
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
    case special = "Special"

    public var id: String { rawValue }

    public var systemImage: String {
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
        case .special: return "star.fill"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .activity: return 0
        case .bodyMeasurements: return 1
        case .cardiovascular: return 2
        case .mobility: return 3
        case .respiratory: return 4
        case .sleep: return 5
        case .nutrition: return 6
        case .workouts: return 7
        case .ecg: return 8
        case .symptoms: return 9
        case .heartRateNotifications: return 10
        case .lifestyle: return 11
        case .environmental: return 12
        case .cycleTracking: return 13
        case .medications: return 14
        case .stateOfMind: return 15
        case .healthRecords: return 16
        case .special: return 17
        }
    }
}

/// Portable catalog of supported metrics (no HealthKit types).
/// Units and IDs must match Infrastructure catalog 1:1.
public enum HealthMetricCatalogCore {

    public static let quantityPrefix = "HKQuantityTypeIdentifier"
    public static let categoryPrefix = "HKCategoryTypeIdentifier"

    public static func normalizeIdentifier(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func shortName(from rawID: String) -> String {
        normalizeIdentifier(rawID)
            .replacingOccurrences(of: quantityPrefix, with: "")
            .replacingOccurrences(of: categoryPrefix, with: "")
    }

    public static func displayName(from rawID: String) -> String {
        shortName(from: rawID)
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .capitalized
    }

    /// Special section IDs that are not quantity/category types.
    public static let workoutsID = "special.workouts"
    public static let workoutRoutesID = "special.workoutRoutes"
    public static let electrocardiogramsID = "special.electrocardiograms"
    public static let activitySummariesID = "special.activitySummaries"

    public static let specialMetrics: [HealthMetric] = [
        HealthMetric(id: workoutsID, displayName: "Workouts", category: .workouts, kind: .workout),
        HealthMetric(id: workoutRoutesID, displayName: "Workout Routes", category: .workouts, kind: .workoutRoute),
        HealthMetric(id: electrocardiogramsID, displayName: "ECG", category: .ecg, kind: .electrocardiogram),
        HealthMetric(id: activitySummariesID, displayName: "Activity Summaries", category: .activity, kind: .activitySummary)
    ]

    /// Quantity metric descriptors with exact HealthKit raw IDs and canonical unit strings.
    public static let quantityMetrics: [HealthMetric] = [
        // Activity
        q("HKQuantityTypeIdentifierStepCount", "Step Count", .activity, "count"),
        q("HKQuantityTypeIdentifierDistanceWalkingRunning", "Distance Walking Running", .activity, "m"),
        q("HKQuantityTypeIdentifierDistanceCycling", "Distance Cycling", .activity, "m"),
        q("HKQuantityTypeIdentifierDistanceSwimming", "Distance Swimming", .activity, "m"),
        q("HKQuantityTypeIdentifierDistanceDownhillSnowSports", "Distance Downhill Snow Sports", .activity, "m"),
        q("HKQuantityTypeIdentifierDistanceWheelchair", "Distance Wheelchair", .activity, "m"),
        q("HKQuantityTypeIdentifierActiveEnergyBurned", "Active Energy Burned", .activity, "kcal"),
        q("HKQuantityTypeIdentifierBasalEnergyBurned", "Basal Energy Burned", .activity, "kcal"),
        q("HKQuantityTypeIdentifierFlightsClimbed", "Flights Climbed", .activity, "count"),
        q("HKQuantityTypeIdentifierAppleExerciseTime", "Apple Exercise Time", .activity, "min"),
        q("HKQuantityTypeIdentifierAppleMoveTime", "Apple Move Time", .activity, "min"),
        q("HKQuantityTypeIdentifierAppleStandTime", "Apple Stand Time", .activity, "min"),
        q("HKQuantityTypeIdentifierVO2Max", "VO2 Max", .activity, "mL/kg·min"),
        q("HKQuantityTypeIdentifierPhysicalEffort", "Physical Effort", .activity, "kcal/hr·kg"),

        // Body
        q("HKQuantityTypeIdentifierBodyMass", "Body Mass", .bodyMeasurements, "kg"),
        q("HKQuantityTypeIdentifierHeight", "Height", .bodyMeasurements, "m"),
        q("HKQuantityTypeIdentifierBodyMassIndex", "Body Mass Index", .bodyMeasurements, "count"),
        q("HKQuantityTypeIdentifierBodyFatPercentage", "Body Fat Percentage", .bodyMeasurements, "%"),
        q("HKQuantityTypeIdentifierLeanBodyMass", "Lean Body Mass", .bodyMeasurements, "kg"),
        q("HKQuantityTypeIdentifierWaistCircumference", "Waist Circumference", .bodyMeasurements, "m"),

        // Cardiovascular
        q("HKQuantityTypeIdentifierHeartRate", "Heart Rate", .cardiovascular, "count/min"),
        q("HKQuantityTypeIdentifierRestingHeartRate", "Resting Heart Rate", .cardiovascular, "count/min"),
        q("HKQuantityTypeIdentifierHeartRateVariabilitySDNN", "Heart Rate Variability SDNN", .cardiovascular, "ms"),
        q("HKQuantityTypeIdentifierWalkingHeartRateAverage", "Walking Heart Rate Average", .cardiovascular, "count/min"),
        q("HKQuantityTypeIdentifierOxygenSaturation", "Oxygen Saturation", .cardiovascular, "%"),
        q("HKQuantityTypeIdentifierBloodPressureSystolic", "Blood Pressure Systolic", .cardiovascular, "mmHg"),
        q("HKQuantityTypeIdentifierBloodPressureDiastolic", "Blood Pressure Diastolic", .cardiovascular, "mmHg"),

        // Mobility
        q("HKQuantityTypeIdentifierWalkingSpeed", "Walking Speed", .mobility, "m/s"),
        q("HKQuantityTypeIdentifierWalkingStepLength", "Walking Step Length", .mobility, "m"),
        q("HKQuantityTypeIdentifierWalkingAsymmetryPercentage", "Walking Asymmetry Percentage", .mobility, "%"),
        q("HKQuantityTypeIdentifierWalkingDoubleSupportPercentage", "Walking Double Support Percentage", .mobility, "%"),
        q("HKQuantityTypeIdentifierStairAscentSpeed", "Stair Ascent Speed", .mobility, "m/s"),
        q("HKQuantityTypeIdentifierStairDescentSpeed", "Stair Descent Speed", .mobility, "m/s"),
        q("HKQuantityTypeIdentifierSixMinuteWalkTestDistance", "Six Minute Walk Test Distance", .mobility, "m"),
        q("HKQuantityTypeIdentifierRunningSpeed", "Running Speed", .mobility, "m/s"),
        q("HKQuantityTypeIdentifierRunningPower", "Running Power", .mobility, "W"),
        q("HKQuantityTypeIdentifierRunningStrideLength", "Running Stride Length", .mobility, "m"),
        q("HKQuantityTypeIdentifierRunningGroundContactTime", "Running Ground Contact Time", .mobility, "ms"),
        q("HKQuantityTypeIdentifierRunningVerticalOscillation", "Running Vertical Oscillation", .mobility, "cm"),

        // Respiratory
        q("HKQuantityTypeIdentifierRespiratoryRate", "Respiratory Rate", .respiratory, "count/min"),
        q("HKQuantityTypeIdentifierForcedExpiratoryVolume1", "Forced Expiratory Volume 1", .respiratory, "L"),
        q("HKQuantityTypeIdentifierForcedVitalCapacity", "Forced Vital Capacity", .respiratory, "L"),
        q("HKQuantityTypeIdentifierPeakExpiratoryFlowRate", "Peak Expiratory Flow Rate", .respiratory, "L/min"),
        q("HKQuantityTypeIdentifierInhalerUsage", "Inhaler Usage", .respiratory, "count"),

        // Nutrition
        q("HKQuantityTypeIdentifierDietaryEnergyConsumed", "Dietary Energy Consumed", .nutrition, "kcal"),
        q("HKQuantityTypeIdentifierDietaryWater", "Dietary Water", .nutrition, "L"),
        q("HKQuantityTypeIdentifierDietaryCarbohydrates", "Dietary Carbohydrates", .nutrition, "g"),
        q("HKQuantityTypeIdentifierDietaryProtein", "Dietary Protein", .nutrition, "g"),
        q("HKQuantityTypeIdentifierDietaryFatTotal", "Dietary Fat Total", .nutrition, "g"),
        q("HKQuantityTypeIdentifierDietaryFatSaturated", "Dietary Fat Saturated", .nutrition, "g"),
        q("HKQuantityTypeIdentifierDietaryFatMonounsaturated", "Dietary Fat Monounsaturated", .nutrition, "g"),
        q("HKQuantityTypeIdentifierDietaryFatPolyunsaturated", "Dietary Fat Polyunsaturated", .nutrition, "g"),
        q("HKQuantityTypeIdentifierDietaryCholesterol", "Dietary Cholesterol", .nutrition, "mg"),
        q("HKQuantityTypeIdentifierDietaryFiber", "Dietary Fiber", .nutrition, "g"),
        q("HKQuantityTypeIdentifierDietarySugar", "Dietary Sugar", .nutrition, "g"),
        q("HKQuantityTypeIdentifierDietarySodium", "Dietary Sodium", .nutrition, "mg"),
        q("HKQuantityTypeIdentifierDietaryPotassium", "Dietary Potassium", .nutrition, "mg"),
        q("HKQuantityTypeIdentifierDietaryCalcium", "Dietary Calcium", .nutrition, "mg"),
        q("HKQuantityTypeIdentifierDietaryIron", "Dietary Iron", .nutrition, "mg"),
        q("HKQuantityTypeIdentifierDietaryVitaminA", "Dietary Vitamin A", .nutrition, "mcg"),
        q("HKQuantityTypeIdentifierDietaryVitaminB6", "Dietary Vitamin B6", .nutrition, "mg"),
        q("HKQuantityTypeIdentifierDietaryVitaminB12", "Dietary Vitamin B12", .nutrition, "mcg"),
        q("HKQuantityTypeIdentifierDietaryVitaminC", "Dietary Vitamin C", .nutrition, "mg"),
        q("HKQuantityTypeIdentifierDietaryVitaminD", "Dietary Vitamin D", .nutrition, "mcg"),
        q("HKQuantityTypeIdentifierDietaryVitaminE", "Dietary Vitamin E", .nutrition, "mg"),
        q("HKQuantityTypeIdentifierDietaryVitaminK", "Dietary Vitamin K", .nutrition, "mcg"),

        // Other
        q("HKQuantityTypeIdentifierBloodGlucose", "Blood Glucose", .healthRecords, "mg/dL"),
        q("HKQuantityTypeIdentifierBodyTemperature", "Body Temperature", .healthRecords, "degC"),
        q("HKQuantityTypeIdentifierPeripheralPerfusionIndex", "Peripheral Perfusion Index", .healthRecords, "%"),
        q("HKQuantityTypeIdentifierNumberOfTimesFallen", "Number Of Times Fallen", .lifestyle, "count"),
        q("HKQuantityTypeIdentifierEnvironmentalAudioExposure", "Environmental Audio Exposure", .environmental, "dBASPL"),
        q("HKQuantityTypeIdentifierHeadphoneAudioExposure", "Headphone Audio Exposure", .environmental, "dBASPL"),
        q("HKQuantityTypeIdentifierTimeInDaylight", "Time In Daylight", .environmental, "min"),
        q("HKQuantityTypeIdentifierUVExposure", "UV Exposure", .environmental, "count")
    ]

    public static let categoryMetrics: [HealthMetric] = [
        c("HKCategoryTypeIdentifierSleepAnalysis", "Sleep Analysis", .sleep),
        c("HKCategoryTypeIdentifierAbdominalCramps", "Abdominal Cramps", .symptoms),
        c("HKCategoryTypeIdentifierBloating", "Bloating", .symptoms),
        c("HKCategoryTypeIdentifierConstipation", "Constipation", .symptoms),
        c("HKCategoryTypeIdentifierDiarrhea", "Diarrhea", .symptoms),
        c("HKCategoryTypeIdentifierHeartburn", "Heartburn", .symptoms),
        c("HKCategoryTypeIdentifierNausea", "Nausea", .symptoms),
        c("HKCategoryTypeIdentifierVomiting", "Vomiting", .symptoms),
        c("HKCategoryTypeIdentifierAppetiteChanges", "Appetite Changes", .symptoms),
        c("HKCategoryTypeIdentifierChills", "Chills", .symptoms),
        c("HKCategoryTypeIdentifierDizziness", "Dizziness", .symptoms),
        c("HKCategoryTypeIdentifierFainting", "Fainting", .symptoms),
        c("HKCategoryTypeIdentifierFatigue", "Fatigue", .symptoms),
        c("HKCategoryTypeIdentifierFever", "Fever", .symptoms),
        c("HKCategoryTypeIdentifierHotFlashes", "Hot Flashes", .symptoms),
        c("HKCategoryTypeIdentifierCoughing", "Coughing", .symptoms),
        c("HKCategoryTypeIdentifierShortnessOfBreath", "Shortness Of Breath", .symptoms),
        c("HKCategoryTypeIdentifierSkippedHeartbeat", "Skipped Heartbeat", .symptoms),
        c("HKCategoryTypeIdentifierWheezing", "Wheezing", .symptoms),
        c("HKCategoryTypeIdentifierLowerBackPain", "Lower Back Pain", .symptoms),
        c("HKCategoryTypeIdentifierHeadache", "Headache", .symptoms),
        c("HKCategoryTypeIdentifierMemoryLapse", "Memory Lapse", .symptoms),
        c("HKCategoryTypeIdentifierMoodChanges", "Mood Changes", .symptoms),
        c("HKCategoryTypeIdentifierLossOfSmell", "Loss Of Smell", .symptoms),
        c("HKCategoryTypeIdentifierLossOfTaste", "Loss Of Taste", .symptoms),
        c("HKCategoryTypeIdentifierRunnyNose", "Runny Nose", .symptoms),
        c("HKCategoryTypeIdentifierSoreThroat", "Sore Throat", .symptoms),
        c("HKCategoryTypeIdentifierSinusCongestion", "Sinus Congestion", .symptoms),
        c("HKCategoryTypeIdentifierAcne", "Acne", .symptoms),
        c("HKCategoryTypeIdentifierDrySkin", "Dry Skin", .symptoms),
        c("HKCategoryTypeIdentifierHairLoss", "Hair Loss", .symptoms),
        c("HKCategoryTypeIdentifierNightSweats", "Night Sweats", .symptoms),
        c("HKCategoryTypeIdentifierSleepChanges", "Sleep Changes", .symptoms),
        c("HKCategoryTypeIdentifierBladderIncontinence", "Bladder Incontinence", .symptoms),
        c("HKCategoryTypeIdentifierHighHeartRateEvent", "High Heart Rate Event", .heartRateNotifications),
        c("HKCategoryTypeIdentifierLowHeartRateEvent", "Low Heart Rate Event", .heartRateNotifications),
        c("HKCategoryTypeIdentifierIrregularHeartRhythmEvent", "Irregular Heart Rhythm Event", .heartRateNotifications)
    ]

    /// Cached indexes: these are hot paths during large HealthKit exports and
    /// must not rebuild arrays/dictionaries once per sample.
    public static let allMetrics: [HealthMetric] = quantityMetrics + categoryMetrics + specialMetrics

    public static let allByID: [String: HealthMetric] =
        Dictionary(uniqueKeysWithValues: allMetrics.map { ($0.id, $0) })

    public static let supportedQuantityIDs: Set<String> = Set(quantityMetrics.map(\.id))

    public static let supportedCategoryIDs: Set<String> = Set(categoryMetrics.map(\.id))

    public static let percentMetricIDs: Set<String> =
        Set(quantityMetrics.lazy.filter { $0.canonicalUnit == "%" }.map(\.id))

    public static func metric(for id: String) -> HealthMetric? {
        allByID[normalizeIdentifier(id)]
    }

    public static func validateInvariants() -> [String] {
        var issues: [String] = []
        let ids = allMetrics.map(\.id)
        if Set(ids).count != ids.count {
            issues.append("Duplicate metric IDs")
        }
        for m in allMetrics {
            if m.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("Empty display name for \(m.id)")
            }
            if m.kind == .quantity && (m.canonicalUnit == nil || m.canonicalUnit?.isEmpty == true) {
                issues.append("Quantity metric missing unit: \(m.id)")
            }
            if m.kind == .category && m.canonicalUnit != nil {
                issues.append("Category metric should not have unit: \(m.id)")
            }
        }
        return issues
    }

    private static func q(_ id: String, _ name: String, _ cat: HealthDataCategory, _ unit: String) -> HealthMetric {
        HealthMetric(id: id, displayName: name, category: cat, kind: .quantity, canonicalUnit: unit)
    }

    private static func c(_ id: String, _ name: String, _ cat: HealthDataCategory) -> HealthMetric {
        HealthMetric(id: id, displayName: name, category: cat, kind: .category, canonicalUnit: nil)
    }
}
