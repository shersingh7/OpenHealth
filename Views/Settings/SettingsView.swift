//
//  SettingsView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI
import HealthKit

struct SettingsView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Authorization Status
                Section {
                    HStack {
                        Image(systemName: healthKitService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(healthKitService.isAuthorized ? .green : .red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("HealthKit Access")
                                .font(.headline)

                            Text(healthKitService.isAuthorized ? "Authorized" : "Not Authorized")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !healthKitService.isAuthorized {
                            Button("Authorize") {
                                Task {
                                    try? await healthKitService.requestAuthorization()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("OpenHealth needs access to your health data to export it. Your data stays on your device and is never collected or shared.")
                }

                // Export Settings
                Section("Export Settings") {
                    Picker("Default Format", selection: $viewModel.defaultFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .onChange(of: viewModel.defaultFormat) { _, _ in
                        viewModel.saveSettings()
                    }

                    Picker("Default Date Range", selection: $viewModel.defaultDateRange) {
                        ForEach(DateRangePreset.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .onChange(of: viewModel.defaultDateRange) { _, _ in
                        viewModel.saveSettings()
                    }

                    Toggle("Include Metadata", isOn: $viewModel.includeMetadata)
                        .onChange(of: viewModel.includeMetadata) { _, _ in
                            viewModel.saveSettings()
                        }
                    Toggle("Include Workout Routes", isOn: $viewModel.includeWorkoutRoutes)
                        .onChange(of: viewModel.includeWorkoutRoutes) { _, _ in
                            viewModel.saveSettings()
                        }
                }

                // Storage
                Section("Storage") {
                    HStack {
                        Text("Export Location")
                        Spacer()
                        Text(viewModel.exportLocation)
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear Export Cache") {
                        viewModel.clearExportCache()
                    }
                    .foregroundStyle(.red)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/shersingh/OpenHealth")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/shersingh/OpenHealth/blob/main/LICENSE")!) {
                        HStack {
                            Text("License")
                            Spacer()
                            Text("MIT")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Data Types
                Section {
                    NavigationLink("Available Data Types") {
                        AvailableTypesListView()
                    }
                } header: {
                    Text("Health Data")
                } footer: {
                    Text("\(viewModel.availableTypesCount) health data types are available for export")
                }
            }
            .navigationTitle("Settings")
            .task {
                viewModel.loadSettings()
            }
        }
    }
}

// MARK: - Available Types List View

struct AvailableTypesListView: View {
    @StateObject private var viewModel = AvailableTypesViewModel()

    var body: some View {
        List {
            ForEach(HealthDataCategory.allCases, id: \.self) { category in
                let typesInCategory = viewModel.types.filter { $0.category == category }

                if !typesInCategory.isEmpty {
                    Section(category.rawValue) {
                        ForEach(typesInCategory) { type in
                            HStack {
                                Image(systemName: category.systemImage)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(.subheadline)

                                    Text(type.id)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Data Types")
        .task {
            await viewModel.loadTypes()
        }
    }
}

// MARK: - Settings View Model

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var defaultFormat: ExportFormat = .json
    @Published var defaultDateRange: DateRangePreset = .thisMonth
    @Published var includeMetadata: Bool = true
    @Published var includeWorkoutRoutes: Bool = true
    @Published var exportLocation: String = "Documents/OpenHealthExports"
    @Published var availableTypesCount: Int = 0

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    func loadSettings() {
        // Load from UserDefaults
        if let formatRaw = UserDefaults.standard.string(forKey: "defaultFormat"),
           let format = ExportFormat(rawValue: formatRaw) {
            defaultFormat = format
        }

        if let rangeRaw = UserDefaults.standard.string(forKey: "defaultDateRange"),
           let range = DateRangePreset(rawValue: rangeRaw) {
            defaultDateRange = range
        }

        // Only override defaults if the key actually exists
        if UserDefaults.standard.object(forKey: "includeMetadata") != nil {
            includeMetadata = UserDefaults.standard.bool(forKey: "includeMetadata")
        }
        if UserDefaults.standard.object(forKey: "includeWorkoutRoutes") != nil {
            includeWorkoutRoutes = UserDefaults.standard.bool(forKey: "includeWorkoutRoutes")
        }

        // Load available types count
        availableTypesCount = UserDefaults.standard.integer(forKey: "availableTypesCount")
    }

    func saveSettings() {
        UserDefaults.standard.set(defaultFormat.rawValue, forKey: "defaultFormat")
        UserDefaults.standard.set(defaultDateRange.rawValue, forKey: "defaultDateRange")
        UserDefaults.standard.set(includeMetadata, forKey: "includeMetadata")
        UserDefaults.standard.set(includeWorkoutRoutes, forKey: "includeWorkoutRoutes")
    }

    func clearExportCache() {
        // Clear the exports directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsPath = documentsPath.appendingPathComponent("OpenHealthExports")

        try? FileManager.default.removeItem(at: exportsPath)
        try? FileManager.default.createDirectory(at: exportsPath, withIntermediateDirectories: true)
    }
}

// MARK: - Available Types View Model

@MainActor
class AvailableTypesViewModel: ObservableObject {
    @Published var types: [HealthDataType] = []

    private let healthKitService = HealthKitService()

    func loadTypes() async {
        let identifiers = await healthKitService.getAvailableDataTypes()
        types = identifiers.compactMap { identifier in
            createHealthDataType(for: identifier)
        }
    }

    private func createHealthDataType(for identifier: HKQuantityTypeIdentifier) -> HealthDataType? {
        let displayName = identifier.rawValue
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .capitalized

        return HealthDataType(
            id: identifier.rawValue,
            hkIdentifier: identifier.rawValue,
            displayName: displayName,
            category: categorize(identifier: identifier),
            unit: "",
            description: ""
        )
    }

    private func categorize(identifier: HKQuantityTypeIdentifier) -> HealthDataCategory {
        let activityTypes: Set<HKQuantityTypeIdentifier> = [
            .stepCount, .distanceWalkingRunning, .activeEnergyBurned, .basalEnergyBurned,
            .flightsClimbed, .appleExerciseTime, .appleMoveTime, .appleStandTime, .vo2Max
        ]
        if activityTypes.contains(identifier) { return .activity }
        if identifier == .heartRate || identifier == .restingHeartRate { return .cardiovascular }
        if identifier == .bodyMass || identifier == .height { return .bodyMeasurements }
        return .healthRecords
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthKitService())
}