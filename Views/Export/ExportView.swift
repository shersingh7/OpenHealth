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
    @State private var showingExportResult = false
    @State private var validationErrors: [String] = []

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
                    if viewModel.configuration.exportAllAvailableTypes {
                        Button {
                            // Already exporting all, no need to select
                        } label: {
                            HStack {
                                Label("Data Types", systemImage: "heart.text.square.fill")

                                Spacer()

                                Text("All Types")
                                    .foregroundStyle(.blue)

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .disabled(true)
                    } else {
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
                    }
                } header: {
                    Text("What to Export")
                } footer: {
                    Text(viewModel.configuration.exportAllAvailableTypes 
                         ? "All available health data types will be exported"
                         : "Select the health data types you want to export")
                }

                // Export All Toggle
                Section {
                    Toggle("Export All Health Data", isOn: $viewModel.configuration.exportAllAvailableTypes)
                        .onChange(of: viewModel.configuration.exportAllAvailableTypes) { newValue in
                            if newValue {
                                // Clear manual selection when switching to export all
                                viewModel.configuration.dataTypes.removeAll()
                            }
                        }
                } footer: {
                    Text("Automatically export all available health data types including steps, heart rate, sleep, workouts, and more")
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
            .sheet(isPresented: $showingExportResult) {
                if let result = viewModel.lastExportResult {
                    ExportResultSheet(result: result)
                }
            }
            .alert("Validation Error", isPresented: .init(
                get: { !validationErrors.isEmpty },
                set: { if !$0 { validationErrors = [] } }
            )) {
                Button("OK", role: .cancel) { validationErrors = [] }
            } message: {
                Text(validationErrors.joined(separator: "\n"))
            }
            .task {
                await viewModel.loadAvailableTypes()
            }
        }
    }

    private func performExport() async {
        // Validate destinations before export
        let errors = viewModel.validateDestinations()
        if !errors.isEmpty {
            validationErrors = errors
            return
        }

        let result = await viewModel.export()
        if result != nil {
            showingExportResult = true
        }
    }
}

// MARK: - Export Result Sheet

struct ExportResultSheet: View {
    let result: ExportResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? .green : .red)
                            .font(.title)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.success ? "Export Complete" : "Export Failed")
                                .font(.headline)

                            if let error = result.error {
                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                if result.success {
                    Section("Summary") {
                        LabeledContent("Records Exported") {
                            Text("\(result.recordsExported)")
                                .font(.body.bold())
                        }

                        LabeledContent("Duration") {
                            Text(String(format: "%.2f seconds", result.duration))
                        }

                        if let url = result.fileURL {
                            LabeledContent("Saved To") {
                                Text(url.lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !result.destinationResults.isEmpty {
                        Section("Destinations") {
                            ForEach(result.destinationResults, id: \.destinationName) { destResult in
                                HStack {
                                    Image(systemName: destResult.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(destResult.success ? .green : .red)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(destResult.destinationName)
                                            .font(.subheadline)

                                        Text(destResult.destinationType)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if let error = destResult.error {
                                        Text(error.localizedDescription)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                            .lineLimit(1)
                                    } else {
                                        Text("\(destResult.recordsExported) records")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if let url = result.fileURL {
                    Section {
                        ShareLink(item: url) {
                            Label("Share Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Export Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Export View Model

@MainActor
class ExportViewModel: ObservableObject {
    @Published var configuration = ExportConfiguration()
    @Published var isExporting = false
    @Published var availableTypes: [HealthDataType] = []
    @Published var lastExportResult: ExportResult?
    @Published var showResult: Bool = false

    private let healthKitService: HealthKitService
    private let exportService: ExportService

    init(healthKitService: HealthKitService = HealthKitService(), exportService: ExportService = ExportService()) {
        self.healthKitService = healthKitService
        self.exportService = exportService
    }

    func loadAvailableTypes() async {
        let identifiers = await healthKitService.getAvailableDataTypes()
        availableTypes = identifiers.map { HealthTypeMetadata.createHealthDataType(for: $0) }
    }

    /// Validate all enabled destinations
    func validateDestinations() -> [String] {
        var errors: [String] = []
        for destination in configuration.destinations where destination.isEnabled {
            let validation = destination.validateConfiguration()
            if case .invalid(let message) = validation {
                errors.append("\(destination.name): \(message)")
            }
        }
        return errors
    }

    func export() async -> ExportResult? {
        // Validate destinations first
        let validationErrors = validateDestinations()
        if !validationErrors.isEmpty {
            return ExportResult(
                success: false,
                fileURL: nil,
                error: ExportError.validationError(validationErrors.joined(separator: "\n")),
                recordsExported: 0,
                duration: 0,
                destinationResults: []
            )
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let result = try await exportService.export(configuration: configuration)
            await MainActor.run {
                lastExportResult = result
                showResult = true
            }
            return result
        } catch {
            let result = ExportResult(
                success: false,
                fileURL: nil,
                error: error,
                recordsExported: 0,
                duration: 0,
                destinationResults: []
            )
            await MainActor.run {
                lastExportResult = result
                showResult = true
            }
            return result
        }
    }
}

#Preview {
    ExportView()
        .environmentObject(HealthKitService())
        .environmentObject(ExportService())
}