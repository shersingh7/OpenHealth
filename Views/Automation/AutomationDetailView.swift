//
//  AutomationDetailView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI

struct AutomationDetailView: View {
    let automation: Automation?
    let onSave: (Automation) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AutomationDetailViewModel

    init(automation: Automation?, onSave: @escaping (Automation) -> Void) {
        self.automation = automation
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: AutomationDetailViewModel(automation: automation))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section("Automation Name") {
                    TextField("Name", text: $viewModel.name)
                }

                // Schedule
                Section("Schedule") {
                    Picker("Frequency", selection: $viewModel.schedule.frequency) {
                        ForEach(ScheduleFrequency.allCases, id: \.self) { frequency in
                            Label(frequency.rawValue, systemImage: frequency.systemImage)
                                .tag(frequency)
                        }
                    }

                    if viewModel.schedule.frequency != .manual {
                        DatePicker(
                            "Time",
                            selection: Binding(
                                get: {
                                    let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
                                    components.hour = viewModel.schedule.hour
                                    components.minute = viewModel.schedule.minute
                                    return Calendar.current.date(from: components) ?? Date()
                                },
                                set: { date in
                                    viewModel.schedule.hour = Calendar.current.component(.hour, from: date)
                                    viewModel.schedule.minute = Calendar.current.component(.minute, from: date)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )

                        if viewModel.schedule.frequency == .weekly {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Days")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    ForEach(1...7, id: \.self) { day in
                                        let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
                                        Button {
                                            if viewModel.schedule.daysOfWeek.contains(day) {
                                                viewModel.schedule.daysOfWeek.remove(day)
                                            } else {
                                                viewModel.schedule.daysOfWeek.insert(day)
                                            }
                                        } label: {
                                            Text(dayNames[day - 1])
                                                .font(.caption.bold())
                                                .frame(width: 32, height: 32)
                                                .background(viewModel.schedule.daysOfWeek.contains(day) ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundStyle(viewModel.schedule.daysOfWeek.contains(day) ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                        }

                        if viewModel.schedule.frequency == .monthly {
                            Stepper("Day of Month: \(viewModel.schedule.dayOfMonth ?? 1)", value: Binding(
                                get: { viewModel.schedule.dayOfMonth ?? 1 },
                                set: { viewModel.schedule.dayOfMonth = $0 }
                            ), in: 1...28)
                        }
                    }
                }

                // Export Configuration
                Section("Export Settings") {
                    Picker("Format", selection: $viewModel.exportConfiguration.format) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }

                    Picker("Date Range", selection: $viewModel.exportConfiguration.dateRange) {
                        ForEach(DateRangePreset.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }

                    Toggle("Export All Health Data", isOn: $viewModel.exportConfiguration.exportAllAvailableTypes)

                    Toggle("Include Workout Routes", isOn: $viewModel.exportConfiguration.includeWorkoutRoutes)
                }

                // iCloud Folder
                Section("iCloud Destination") {
                    HStack {
                        Text("Folder Path")
                        Spacer()
                        TextField("OpenHealth/Exports", text: $viewModel.iCloudFolderPath)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        viewModel.iCloudFolderPath = "OpenHealth/DailyExports/\(Date().formatted(.dateTime.year().month().day()))"
                    } label: {
                        Label("Use Date-Based Folder", systemImage: "folder.badge.plus")
                    }
                } footer: {
                    Text("Exports will be saved to this folder in your iCloud Drive")
                }

                // Next Run
                if let nextRun = viewModel.schedule.nextRunDate() {
                    Section {
                        HStack {
                            Label("Next Run", systemImage: "clock.arrow.circlepath")
                            Spacer()
                            Text(nextRun, style: .date)
                                .foregroundStyle(.secondary)
                        }

                        if viewModel.isEditing {
                            HStack {
                                Label("Last Run", systemImage: "clock.arrow.2.circlepath")
                                Spacer()
                                if let lastRun = viewModel.lastRun {
                                    Text(lastRun, style: .relative)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Never")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let status = viewModel.executionStatus {
                                HStack {
                                    Label("Status", systemImage: status.systemImage)
                                    Spacer()
                                    Text(status.rawValue)
                                        .foregroundStyle(status == .completed ? .green : (status == .failed ? .red : .secondary))
                                }
                            }

                            if let error = viewModel.lastError {
                                Text("Error: \(error)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                // Test Button
                Section {
                    Button {
                        Task {
                            await viewModel.testAutomation()
                        }
                    } label: {
                        HStack {
                            Label("Test Now", systemImage: "play.circle.fill")
                            Spacer()
                            if viewModel.isTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isTesting)

                    if let testResult = viewModel.testResult {
                        Text(testResult)
                            .font(.caption)
                            .foregroundStyle(testResult.contains("✅") ? .green : .red)
                    }
                } footer: {
                    Text("Run this automation immediately to test the configuration")
                }

                // Enable/Disable
                Section {
                    Toggle("Enabled", isOn: $viewModel.isEnabled)
                } footer: {
                    Text("When enabled, this automation will run automatically according to the schedule")
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Automation" : "New Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let automation = viewModel.toAutomation()
                        onSave(automation)
                        dismiss()
                    }
                    .disabled(viewModel.name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Automation Detail View Model

@MainActor
class AutomationDetailViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var schedule: AutomationSchedule = AutomationSchedule()
    @Published var exportConfiguration: ExportConfiguration = ExportConfiguration()
    @Published var isEnabled: Bool = true
    @Published var iCloudFolderPath: String = "OpenHealth/DailyExports"
    @Published var isTesting: Bool = false
    @Published var testResult: String?

    var isEditing: Bool
    var lastRun: Date?
    var executionStatus: ExecutionStatus?
    var lastError: String?

    private var originalId: UUID?

    init(automation: Automation?) {
        self.isEditing = automation != nil

        if let automation = automation {
            self.originalId = automation.id
            self.name = automation.name
            self.schedule = automation.schedule
            self.exportConfiguration = automation.exportConfiguration
            self.isEnabled = automation.isEnabled
            self.iCloudFolderPath = automation.iCloudFolderPath ?? "OpenHealth/DailyExports"
            self.lastRun = automation.lastRun
            self.executionStatus = automation.executionStatus
            self.lastError = automation.lastError
        } else {
            self.name = "New Automation"
            // Default to export all for new automations
            self.exportConfiguration.exportAllAvailableTypes = true
            self.exportConfiguration.dateRange = .yesterday
        }
    }

    func toAutomation() -> Automation {
        // Update export configuration with iCloud folder
        var config = exportConfiguration
        if let iCloudDestination = config.destinations.first(where: { $0.type == .iCloudDrive }) {
            iCloudDestination.configuration.folderPath = iCloudFolderPath
        } else {
            // Add iCloud destination if not present
            let iCloudDestination = ExportDestination(
                type: .iCloudDrive,
                configuration: ExportDestinationConfiguration(folderPath: iCloudFolderPath)
            )
            config.destinations.append(iCloudDestination)
        }

        if isEditing, let originalId = originalId {
            // Preserve original ID and other fields when editing
            var automation = Automation(
                id: originalId,
                name: name,
                exportConfiguration: config,
                schedule: schedule,
                isEnabled: isEnabled,
                iCloudFolderPath: iCloudFolderPath
            )
            automation.lastRun = self.lastRun
            automation.runCount = 0 // Preserve from original if needed
            return automation
        } else {
            return Automation(
                name: name,
                exportConfiguration: config,
                schedule: schedule,
                isEnabled: isEnabled,
                iCloudFolderPath: iCloudFolderPath
            )
        }
    }

    func testAutomation() async {
        isTesting = true
        testResult = nil

        let automation = toAutomation()
        await AutomationScheduler.shared.executeAutomation(automation)

        isTesting = false
        testResult = AutomationScheduler.shared.lastRunResult
    }
}

#Preview {
    AutomationDetailView(automation: nil) { _ in }
}