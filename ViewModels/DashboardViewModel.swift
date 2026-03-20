//
//  DashboardViewModel.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import Foundation
import HealthKit
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {

    // MARK: - Properties

    @Published var isLoading = true
    @Published var error: Error?

    // Activity Summary (Apple Watch Rings)
    @Published var todaySteps: Double = 0
    @Published var todayActiveEnergy: Double = 0
    @Published var todayExerciseTime: Double = 0
    @Published var todayStandTime: Double = 0

    @Published var stepsGoal: Double = 10000
    @Published var activeEnergyGoal: Double = 500
    @Published var exerciseGoal: Double = 30 // minutes
    @Published var standGoal: Double = 12 // hours

    // Heart Health
    @Published var latestHeartRate: Double = 0
    @Published var latestRestingHeartRate: Double = 0
    @Published var latestHRV: Double = 0

    // Recent Workouts
    @Published var recentWorkouts: [WorkoutData] = []

    // Available Data Types
    @Published var availableTypes: [HealthDataType] = []

    // Export Service
    var exportService: ExportService?

    private var healthKitService: HealthKitService?

    // MARK: - Initialization

    init(healthKitService: HealthKitService? = nil, exportService: ExportService? = nil) {
        self.healthKitService = healthKitService
        self.exportService = exportService
    }

    /// Configure with environment services (called from view)
    func configure(healthKitService: HealthKitService, exportService: ExportService) {
        self.healthKitService = healthKitService
        self.exportService = exportService
    }

    // MARK: - Load Data

    func loadData() async {
        guard let healthKitService = healthKitService else { return }

        await MainActor.run { isLoading = true }

        do {
            // Load today's activity
            await loadTodayActivity(using: healthKitService)

            // Load heart health data
            await loadHeartHealth(using: healthKitService)

            // Load recent workouts
            await loadRecentWorkouts(using: healthKitService)

            // Load available types
            await loadAvailableTypes(using: healthKitService)

            await MainActor.run {
                isLoading = false
                error = nil
            }
        }
    }

    // MARK: - Private Methods

    private func loadTodayActivity(using healthKitService: HealthKitService) async {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        // Steps
        if let steps = try? await fetchQuantitySum(for: .stepCount, from: startOfDay, to: endOfDay, using: healthKitService) {
            await MainActor.run { todaySteps = steps }
        }

        // Active Energy
        if let energy = try? await fetchQuantitySum(for: .activeEnergyBurned, from: startOfDay, to: endOfDay, using: healthKitService) {
            await MainActor.run { todayActiveEnergy = energy }
        }

        // Exercise Time
        if let exercise = try? await fetchQuantitySum(for: .appleExerciseTime, from: startOfDay, to: endOfDay, using: healthKitService) {
            await MainActor.run { todayExerciseTime = exercise }
        }

        // Stand Time
        if let stand = try? await fetchQuantitySum(for: .appleStandTime, from: startOfDay, to: endOfDay, using: healthKitService) {
            await MainActor.run { todayStandTime = stand }
        }
    }

    private func loadHeartHealth(using healthKitService: HealthKitService) async {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        // Latest Heart Rate
        if let hrSamples = try? await healthKitService.fetchQuantitySamples(type: .heartRate, from: yesterday, to: now),
           let latestHR = hrSamples.first {
            await MainActor.run { latestHeartRate = latestHR.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
        }

        // Resting Heart Rate
        if let rhrSamples = try? await healthKitService.fetchQuantitySamples(type: .restingHeartRate, from: yesterday, to: now),
           let latestRHR = rhrSamples.first {
            await MainActor.run { latestRestingHeartRate = latestRHR.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
        }

        // HRV
        if let hrvSamples = try? await healthKitService.fetchQuantitySamples(type: .heartRateVariabilitySDNN, from: yesterday, to: now),
           let hrvSample = hrvSamples.first {
            let hrv = hrvSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            await MainActor.run { latestHRV = hrv }
        }
    }

    private func loadRecentWorkouts(using healthKitService: HealthKitService) async {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        if let hkWorkouts = try? await healthKitService.fetchWorkouts(from: weekAgo, to: now) {
            let workoutData = hkWorkouts.prefix(5).map { WorkoutData(from: $0) }
            await MainActor.run { recentWorkouts = Array(workoutData) }
        }
    }

    private func loadAvailableTypes(using healthKitService: HealthKitService) async {
        let available = await healthKitService.getAvailableDataTypes()
        let types = available.map { HealthTypeMetadata.createHealthDataType(for: $0) }
        await MainActor.run { availableTypes = types }
    }

    private func fetchQuantitySum(for identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date, using healthKitService: HealthKitService) async throws -> Double {
        let samples = try await healthKitService.fetchQuantitySamples(type: identifier, from: start, to: end)
        let unit = HealthTypeMetadata.preferredUnit(for: identifier.rawValue)
        return samples.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
    }

    // MARK: - Quick Export

    func quickExport() async {
        guard let exportService = exportService else { return }

        var config = ExportConfiguration()
        config.name = "Quick Export"
        config.dateRange = .thisMonth
        config.format = .json
        config.destinations = [ExportDestination(type: .localFiles)]

        _ = try? await exportService.export(configuration: config)
    }
}