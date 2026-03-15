//
//  ExportView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI

struct ExportView: View {
    @StateObject private var viewModel: ExportViewModel
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var exportService: ExportService

    @State private var showingDataTypes = false
    @State private var showingDateRange = false
    @State private var showingDestinations = false

    init() {
        _viewModel = StateObject(wrappedValue: ExportViewModel())
    }

    var body: some View {
        NavigationStack {
            List {
                // Export Name
                Section("Export Name") {
                    TextField("Enter name", text: $viewModel.configuration.name)
                }

                // Data Types
                Section {
                    Button {
                        showingDataTypes = true
                    } label: {
                        HStack {
                            Label("Data Types", systemImage: "heart.text.square.fill")

                            Spacer()

                            if viewModel.configuration.dataTypes.isEmpty {
                                Text("Select types")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(viewModel.configuration.dataTypes.count) types")
                                    .foregroundStyle(.blue)
                            }

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("What to Export")
                } footer: {
                    Text("Select the health data types you want to export")
                }

                // Date Range
                Section("When") {
                    Button {
                        showingDateRange = true
                    } label: {
                        HStack {
                            Label("Date Range", systemImage: "calendar.badge.clock")

                            Spacer()

                            Text(viewModel.configuration.dateRange.rawValue)
                                .foregroundStyle(.blue)

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if viewModel.configuration.dateRange == .custom {
                        DatePicker(
                            "Start Date",
                            selection: Binding(
                                get: { viewModel.configuration.customStartDate ?? Date() },
                                set: { viewModel.configuration.customStartDate = $0 }
                            ),
                            displayedComponents: .date
                        )

                        DatePicker(
                            "End Date",
                            selection: Binding(
                                get: { viewModel.configuration.customEndDate ?? Date() },
                                set: { viewModel.configuration.customEndDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                // Format
                Section("Format") {
                    Picker("Export Format", selection: $viewModel.configuration.format) {
                        ForEach(ExportFormat.allCases) { format in
                            Label(format.rawValue, systemImage: format.systemImage)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Options
                Section("Options") {
                    Toggle("Include Workout Routes", isOn: $viewModel.configuration.includeWorkoutRoutes)
                    Toggle("Include Metadata", isOn: $viewModel.configuration.includeMetadata)
                }

                // Destinations
                Section {
                    Button {
                        showingDestinations = true
                    } label: {
                        HStack {
                            Label("Destinations", systemImage: "arrow.up.doc.on.clipboard")

                            Spacer()

                            if viewModel.configuration.destinations.isEmpty {
                                Text("Add destinations")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(viewModel.configuration.destinations.count) destinations")
                                    .foregroundStyle(.blue)
                            }

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Where to Export")
                } footer: {
                    Text("Save to Files, iCloud Drive, or send to an API")
                }

                // Export Button
                Section {
                    Button {
                        Task {
                            await performExport()
                        }
                    } label: {
                        if viewModel.isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Export Now", systemImage: "arrow.up.doc.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(Color.red)
                    .disabled(viewModel.configuration.dataTypes.isEmpty || viewModel.isExporting)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Export")
            .sheet(isPresented: $showingDataTypes) {
                DataTypeSelectionView(
                    selectedTypes: $viewModel.configuration.dataTypes,
                    availableTypes: viewModel.availableTypes
                )
            }
            .sheet(isPresented: $showingDestinations) {
                DestinationPickerView(destinations: $viewModel.configuration.destinations)
            }
            .task {
                await viewModel.loadAvailableTypes()
            }
        }
    }

    private func performExport() async {
        let result = await viewModel.export()
        // Handle result - show success/error alert
    }
}

// MARK: - Export View Model

@MainActor
class ExportViewModel: ObservableObject {
    @Published var configuration = ExportConfiguration()
    @Published var isExporting = false
    @Published var availableTypes: [HealthDataType] = []

    private let healthKitService = HealthKitService()
    private let exportService = ExportService()

    func loadAvailableTypes() async {
        let identifiers = await healthKitService.getAvailableDataTypes()
        availableTypes = identifiers.compactMap { createHealthDataType(for: $0) }
    }

    func export() async -> ExportResult? {
        isExporting = true
        defer { isExporting = false }

        do {
            let result = try await exportService.export(configuration: configuration)
            return result
        } catch {
            return ExportResult(success: false, fileURL: nil, error: error, recordsExported: 0, duration: 0)
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
            .flightsClimbed, .appleExerciseTime, .appleMoveTime, .appleStandTime
        ]
        if activityTypes.contains(identifier) { return .activity }
        if identifier == .heartRate || identifier == .restingHeartRate { return .cardiovascular }
        if identifier == .bodyMass || identifier == .height { return .bodyMeasurements }
        return .healthRecords
    }
}

#Preview {
    ExportView()
        .environmentObject(HealthKitService())
        .environmentObject(ExportService())
}