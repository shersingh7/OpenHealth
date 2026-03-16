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

                    Toggle("Include Workout Routes", isOn: $viewModel.exportConfiguration.includeWorkoutRoutes)
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

    var isEditing: Bool

    private var originalId: UUID?

    init(automation: Automation?) {
        self.isEditing = automation != nil

        if let automation = automation {
            self.originalId = automation.id
            self.name = automation.name
            self.schedule = automation.schedule
            self.exportConfiguration = automation.exportConfiguration
            self.isEnabled = automation.isEnabled
        } else {
            self.name = "New Automation"
        }
    }

    func toAutomation() -> Automation {
        if isEditing, let originalId = originalId {
            // Preserve original ID when editing
            return Automation(
                id: originalId,
                name: name,
                exportConfiguration: exportConfiguration,
                schedule: schedule,
                isEnabled: isEnabled
            )
        } else {
            return Automation(
                name: name,
                exportConfiguration: exportConfiguration,
                schedule: schedule,
                isEnabled: isEnabled
            )
        }
    }
}

#Preview {
    AutomationDetailView(automation: nil) { _ in }
}