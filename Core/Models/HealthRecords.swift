import Foundation

// MARK: - Portable Health Records (no HealthKit types)

public struct QuantityRecord: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let metricID: String
    public let value: Double
    public let unit: String
    public let startDate: Date
    public let endDate: Date
    public let sourceName: String?
    public let sourceBundleID: String?
    public let metadata: [String: String]?

    public init(
        id: UUID,
        metricID: String,
        value: Double,
        unit: String,
        startDate: Date,
        endDate: Date,
        sourceName: String? = nil,
        sourceBundleID: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.metricID = metricID
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        self.metadata = metadata
    }
}

public struct CategoryRecord: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let metricID: String
    public let value: Int
    public let valueLabel: String?
    public let startDate: Date
    public let endDate: Date
    public let sourceName: String?
    public let sourceBundleID: String?
    public let metadata: [String: String]?

    public init(
        id: UUID,
        metricID: String,
        value: Int,
        valueLabel: String? = nil,
        startDate: Date,
        endDate: Date,
        sourceName: String? = nil,
        sourceBundleID: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.metricID = metricID
        self.value = value
        self.valueLabel = valueLabel
        self.startDate = startDate
        self.endDate = endDate
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        self.metadata = metadata
    }
}

public struct RoutePointRecord: Codable, Sendable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let timestamp: Date
    public let speed: Double?
    public let course: Double?

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        timestamp: Date,
        speed: Double? = nil,
        course: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.course = course
    }
}

public struct WorkoutRecord: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let activityType: String
    public let activityTypeRaw: UInt
    public let startDate: Date
    public let endDate: Date
    public let duration: TimeInterval
    public let totalEnergyBurnedKilocalories: Double?
    public let totalDistanceMeters: Double?
    public let sourceName: String?
    public let sourceBundleID: String?
    public let routePoints: [RoutePointRecord]?
    public let metadata: [String: String]?

    public init(
        id: UUID,
        activityType: String,
        activityTypeRaw: UInt,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        totalEnergyBurnedKilocalories: Double? = nil,
        totalDistanceMeters: Double? = nil,
        sourceName: String? = nil,
        sourceBundleID: String? = nil,
        routePoints: [RoutePointRecord]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.activityType = activityType
        self.activityTypeRaw = activityTypeRaw
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.totalEnergyBurnedKilocalories = totalEnergyBurnedKilocalories
        self.totalDistanceMeters = totalDistanceMeters
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        self.routePoints = routePoints
        self.metadata = metadata
    }
}

public struct ECGVoltagePoint: Codable, Sendable, Hashable {
    public let timeSinceSampleStart: TimeInterval
    public let voltage: Double

    public init(timeSinceSampleStart: TimeInterval, voltage: Double) {
        self.timeSinceSampleStart = timeSinceSampleStart
        self.voltage = voltage
    }
}

public struct ECGRecord: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let classification: String?
    public let averageHeartRate: Double?
    public let samplingFrequency: Double?
    public let lead: String?
    public let sourceName: String?
    public let sourceBundleID: String?
    public let voltagePoints: [ECGVoltagePoint]?
    public let metadata: [String: String]?

    public init(
        id: UUID,
        startDate: Date,
        endDate: Date,
        classification: String? = nil,
        averageHeartRate: Double? = nil,
        samplingFrequency: Double? = nil,
        lead: String? = nil,
        sourceName: String? = nil,
        sourceBundleID: String? = nil,
        voltagePoints: [ECGVoltagePoint]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.classification = classification
        self.averageHeartRate = averageHeartRate
        self.samplingFrequency = samplingFrequency
        self.lead = lead
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        self.voltagePoints = voltagePoints
        self.metadata = metadata
    }
}

public struct ActivitySummaryRecord: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let date: Date
    public let activeEnergyBurned: Double
    public let activeEnergyBurnedGoal: Double
    public let appleExerciseTime: Double
    public let appleExerciseTimeGoal: Double
    public let appleStandHours: Double
    public let appleStandHoursGoal: Double

    public init(
        id: UUID = UUID(),
        date: Date,
        activeEnergyBurned: Double,
        activeEnergyBurnedGoal: Double,
        appleExerciseTime: Double,
        appleExerciseTimeGoal: Double,
        appleStandHours: Double,
        appleStandHoursGoal: Double
    ) {
        self.id = id
        self.date = date
        self.activeEnergyBurned = activeEnergyBurned
        self.activeEnergyBurnedGoal = activeEnergyBurnedGoal
        self.appleExerciseTime = appleExerciseTime
        self.appleExerciseTimeGoal = appleExerciseTimeGoal
        self.appleStandHours = appleStandHours
        self.appleStandHoursGoal = appleStandHoursGoal
    }
}

public struct HealthDataSnapshot: Sendable {
    public var quantityRecords: [QuantityRecord]
    public var categoryRecords: [CategoryRecord]
    public var workouts: [WorkoutRecord]
    public var electrocardiograms: [ECGRecord]
    public var activitySummaries: [ActivitySummaryRecord]
    public var warnings: [ExportWarning]

    public init(
        quantityRecords: [QuantityRecord] = [],
        categoryRecords: [CategoryRecord] = [],
        workouts: [WorkoutRecord] = [],
        electrocardiograms: [ECGRecord] = [],
        activitySummaries: [ActivitySummaryRecord] = [],
        warnings: [ExportWarning] = []
    ) {
        self.quantityRecords = quantityRecords
        self.categoryRecords = categoryRecords
        self.workouts = workouts
        self.electrocardiograms = electrocardiograms
        self.activitySummaries = activitySummaries
        self.warnings = warnings
    }

    public var totalRecordCount: Int {
        quantityRecords.count
            + categoryRecords.count
            + workouts.count
            + electrocardiograms.count
            + activitySummaries.count
    }
}
