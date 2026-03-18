//
//  DashboardView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var exportService: ExportService

    init() {
        // ViewModel will be initialized with environment objects in body
        _viewModel = StateObject(wrappedValue: DashboardViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Activity Rings Card
                    ActivityRingsCard(
                        steps: viewModel.todaySteps,
                        stepsGoal: viewModel.stepsGoal,
                        activeEnergy: viewModel.todayActiveEnergy,
                        activeEnergyGoal: viewModel.activeEnergyGoal,
                        exerciseTime: viewModel.todayExerciseTime,
                        exerciseGoal: viewModel.exerciseGoal,
                        standTime: viewModel.todayStandTime,
                        standGoal: viewModel.standGoal
                    )
                    .padding(.horizontal)

                    // Heart Health Card
                    if viewModel.latestHeartRate > 0 {
                        HeartHealthCard(
                            heartRate: viewModel.latestHeartRate,
                            restingHeartRate: viewModel.latestRestingHeartRate,
                            hrv: viewModel.latestHRV
                        )
                        .padding(.horizontal)
                    }

                    // Recent Workouts
                    if !viewModel.recentWorkouts.isEmpty {
                        RecentWorkoutsCard(workouts: viewModel.recentWorkouts)
                            .padding(.horizontal)
                    }

                    // Available Data Types
                    if !viewModel.availableTypes.isEmpty {
                        AvailableTypesCard(types: viewModel.availableTypes)
                            .padding(.horizontal)
                    }

                    // Quick Export Button
                    Button {
                        Task {
                            await viewModel.quickExport()
                        }
                    } label: {
                        Label("Quick Export This Month", systemImage: "arrow.up.doc.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .padding(.vertical)
            }
            .navigationTitle("OpenHealth")
            .task {
                viewModel.configure(healthKitService: healthKitService, exportService: exportService)
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.loadData()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading health data...")
                }
            }
        }
    }
}

// MARK: - Activity Rings Card

struct ActivityRingsCard: View {
    let steps: Double
    let stepsGoal: Double
    let activeEnergy: Double
    let activeEnergyGoal: Double
    let exerciseTime: Double
    let exerciseGoal: Double
    let standTime: Double
    let standGoal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Activity")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                // Activity Rings
                ZStack {
                    // Move (Red)
                    RingView(progress: min(activeEnergy / activeEnergyGoal, 1.0), color: .red, thickness: 12)
                    // Exercise (Green)
                    RingView(progress: min(exerciseTime / exerciseGoal, 1.0), color: .green, thickness: 12)
                        .frame(width: 70, height: 70)
                    // Stand (Blue)
                    RingView(progress: min(standTime / standGoal, 1.0), color: .blue, thickness: 12)
                        .frame(width: 50, height: 50)
                }
                .frame(width: 90, height: 90)

                // Stats
                VStack(alignment: .leading, spacing: 8) {
                    StatRow(icon: "flame.fill", color: .red, label: "Move", value: activeEnergy, goal: activeEnergyGoal, unit: "kcal")
                    StatRow(icon: "figure.run", color: .green, label: "Exercise", value: exerciseTime, goal: exerciseGoal, unit: "min")
                    StatRow(icon: "person.stand", color: .blue, label: "Stand", value: standTime, goal: standGoal, unit: "hr")
                }
            }

            // Steps
            VStack(alignment: .leading, spacing: 4) {
                Text("Steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(steps))")
                        .font(.title.bold())
                    Text("/ \(Int(stepsGoal))")
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: steps, total: stepsGoal)
                    .tint(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct RingView: View {
    let progress: Double
    let color: Color
    let thickness: CGFloat

    var body: some View {
        Circle()
            .stroke(color.opacity(0.3), lineWidth: thickness)
            .overlay {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
    }
}

struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: Double
    let goal: Double
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(Int(value))/\(Int(goal))")
                .font(.caption.bold())
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Heart Health Card

struct HeartHealthCard: View {
    let heartRate: Double
    let restingHeartRate: Double
    let hrv: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heart Health")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                HeartMetricView(
                    icon: "heart.fill",
                    color: .red,
                    title: "Heart Rate",
                    value: heartRate,
                    unit: "bpm"
                )

                if restingHeartRate > 0 {
                    HeartMetricView(
                        icon: "heart.circle.fill",
                        color: .pink,
                        title: "Resting",
                        value: restingHeartRate,
                        unit: "bpm"
                    )
                }

                if hrv > 0 {
                    HeartMetricView(
                        icon: "waveform.path.ecg",
                        color: .purple,
                        title: "HRV",
                        value: hrv,
                        unit: "ms"
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct HeartMetricView: View {
    let icon: String
    let color: Color
    let title: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", value))
                    .font(.title3.bold())
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Recent Workouts Card

struct RecentWorkoutsCard: View {
    let workouts: [WorkoutData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(workouts.prefix(5)) { workout in
                HStack {
                    Image(systemName: workoutIcon(for: workout.workoutType))
                        .foregroundStyle(.red)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.workoutType)
                            .font(.subheadline.bold())

                        Text(workout.startDate, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDuration(workout.duration))
                            .font(.subheadline.bold())

                        if let calories = workout.totalEnergyBurned {
                            Text("\(Int(calories)) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func workoutIcon(for type: String) -> String {
        switch type.lowercased() {
        case let t where t.contains("run"): return "figure.run"
        case let t where t.contains("walk"): return "figure.walk"
        case let t where t.contains("cycle"): return "bicycle"
        case let t where t.contains("swim"): return "figure.pool.swim"
        case let t where t.contains("yoga"): return "figure.mind.and.body"
        default: return "figure.flexibility"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Available Types Card

struct AvailableTypesCard: View {
    let types: [HealthDataType]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Data")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(types.count) types")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Group by category
            ForEach(HealthDataCategory.allCases, id: \.self) { category in
                let categoryTypes = types.filter { $0.category == category }
                if !categoryTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(category.rawValue, systemImage: category.systemImage)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(categoryTypes.map { $0.displayName }.prefix(3).joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)

                        if categoryTypes.count > 3 {
                            Text("+\(categoryTypes.count - 3) more")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    DashboardView()
        .environmentObject(HealthKitService())
        .environmentObject(ExportService())
}