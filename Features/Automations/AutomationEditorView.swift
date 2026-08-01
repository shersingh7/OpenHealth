import SwiftUI

struct AutomationEditorView: View {
    @StateObject private var viewModel: AutomationEditorViewModel
    var onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer

    @State private var showDataTypes = false
    @State private var showDestinations = false
    @State private var editingDestination: ExportDestination?

    init(container: AppContainer, automation: Automation?, onFinished: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AutomationEditorViewModel(container: container, automation: automation))
        self.onFinished = onFinished
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name & State") {
                    TextField("Name", text: $viewModel.automation.name)
                    Toggle("Enabled", isOn: $viewModel.automation.isEnabled)
                }

                Section {
                    Picker("Frequency", selection: $viewModel.automation.schedule.frequency) {
                        ForEach(ScheduleFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    if viewModel.automation.schedule.frequency != .manual
                        && viewModel.automation.schedule.frequency != .hourly {
                        Stepper("Hour: \(viewModel.automation.schedule.hour)", value: $viewModel.automation.schedule.hour, in: 0...23)
                        Stepper("Minute: \(viewModel.automation.schedule.minute)", value: $viewModel.automation.schedule.minute, in: 0...59)
                    }
                    if viewModel.automation.schedule.frequency == .weekly {
                        weekdayPicker
                    }
                    if viewModel.automation.schedule.frequency == .monthly {
                        Stepper(
                            "Day of month: \(viewModel.automation.schedule.dayOfMonth ?? 1)",
                            value: Binding(
                                get: { viewModel.automation.schedule.dayOfMonth ?? 1 },
                                set: { viewModel.automation.schedule.dayOfMonth = $0 }
                            ),
                            in: 1...31
                        )
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Background execution is best effort. “Earliest after” is not a guarantee of exact timing.")
                }

                Section("Export Configuration") {
                    Picker("Format", selection: $viewModel.automation.exportConfig.format) {
                        ForEach(ExportFormat.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    rangePicker

                    Picker("Data scope", selection: Binding(
                        get: {
                            if case .allDetected = viewModel.automation.exportConfig.selection { return 0 }
                            return 1
                        },
                        set: { value in
                            if value == 0 {
                                viewModel.automation.exportConfig.selection = .allDetected
                            } else if case .explicit = viewModel.automation.exportConfig.selection {
                                // keep
                            } else {
                                viewModel.automation.exportConfig.selection = .explicit([])
                            }
                        }
                    )) {
                        Text("All supported").tag(0)
                        Text("Choose types").tag(1)
                    }
                    .pickerStyle(.segmented)

                    Text(selectionLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if case .explicit = viewModel.automation.exportConfig.selection {
                        Button("Choose Data Types…") { showDataTypes = true }
                            .frame(minHeight: OHTheme.minTapTarget)
                    }

                    Toggle("Include metadata", isOn: $viewModel.automation.exportConfig.includeMetadata)
                    Toggle("Include workout routes", isOn: $viewModel.automation.exportConfig.includeWorkoutRoutes)
                    Text("Routes contain precise location. Off by default.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Include ECG waveforms", isOn: $viewModel.automation.exportConfig.includeECGWaveforms)
                }

                Section("Destinations") {
                    ForEach(viewModel.automation.exportConfig.destinations) { dest in
                        OHDestinationRow(name: dest.name, kind: dest.kind, isEnabled: dest.isEnabled)
                            .contentShape(Rectangle())
                            .onTapGesture { editingDestination = dest }
                    }
                    Button {
                        showDestinations = true
                    } label: {
                        Label("Add or manage destinations", systemImage: "plus.circle")
                            .frame(minHeight: OHTheme.minTapTarget)
                    }
                    if viewModel.automation.exportConfig.destinations.isEmpty {
                        Text("Add at least one destination.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle("Notify on completion", isOn: $viewModel.automation.notifyOnCompletion)
                    Text(viewModel.notificationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Permission is requested only when you enable notifications. Notification bodies never include health values or destination URLs.")
                }

                Section {
                    Button {
                        Task { await viewModel.runDraftNow() }
                    } label: {
                        if viewModel.isRunningDraft {
                            ProgressView()
                        } else {
                            Label("Run Draft Now", systemImage: "play.fill")
                        }
                    }
                    .disabled(viewModel.isRunningDraft)
                    .accessibilityIdentifier("oh.automations.runDraft")

                    if viewModel.isRunningDraft {
                        Text("Running draft export…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let report = viewModel.draftReport {
                        OHStatusBadge(
                            title: report.outcome == .completeSuccess ? "Draft succeeded" :
                                report.outcome == .partialSuccess ? "Draft partial" :
                                report.outcome == .cancelled ? "Draft cancelled" : "Draft failed",
                            kind: report.outcome == .completeSuccess ? .success :
                                report.outcome == .partialSuccess ? .partial :
                                report.outcome == .cancelled ? .neutral : .error
                        )
                        Text("\(report.serializedRecordCount) records")
                            .font(.caption.monospacedDigit())
                        if let err = report.errorDescription, !err.isEmpty {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if !report.warnings.isEmpty {
                            Text("\(report.warnings.count) warning(s)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        ForEach(report.destinationResults) { result in
                            Text("\(result.destinationName): \(result.success ? "ok" : (result.errorDescription ?? "failed"))")
                                .font(.caption2)
                                .foregroundStyle(result.success ? .secondary : .red)
                        }
                    }
                }

                if !viewModel.errors.isEmpty {
                    Section("Validation") {
                        ForEach(viewModel.errors, id: \.self) { err in
                            Text(err).foregroundStyle(.red).font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.automation.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Task {
                            await viewModel.discardSecretStaging()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                onFinished()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("oh.automations.save")
                }
            }
            .task { await viewModel.refreshNotificationStatus() }
            .onDisappear {
                // Swipe-down / interactive dismiss without Save must not leave staged secrets.
                Task { await viewModel.discardSecretStaging() }
            }
            .sheet(isPresented: $showDataTypes) {
                DataTypeSelectionView(selection: $viewModel.automation.exportConfig.selection)
            }
            .sheet(isPresented: $showDestinations) {
                DestinationPickerView(
                    destinations: $viewModel.automation.exportConfig.destinations,
                    selectedIDs: Binding(
                        get: {
                            viewModel.automation.exportConfig.destinations
                                .filter(\.isEnabled)
                                .map(\.id)
                        },
                        set: { ids in
                            for index in viewModel.automation.exportConfig.destinations.indices {
                                let id = viewModel.automation.exportConfig.destinations[index].id
                                viewModel.automation.exportConfig.destinations[index].isEnabled = ids.contains(id)
                            }
                        }
                    ),
                    // Staged store: parent Cancel discards without Keychain mutation.
                    secretStore: viewModel.secretStore
                )
            }
            .sheet(item: $editingDestination) { dest in
                DestinationEditorView(
                    destination: dest,
                    secretStore: viewModel.secretStore
                ) { updated in
                    if let idx = viewModel.automation.exportConfig.destinations.firstIndex(where: { $0.id == updated.id }) {
                        viewModel.automation.exportConfig.destinations[idx] = updated
                    }
                }
            }
        }
    }

    private var selectionLabel: String {
        switch viewModel.automation.exportConfig.selection {
        case .allDetected: return "Data scope: All supported types"
        case .explicit(let ids): return "Data scope: \(ids.count) types"
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: Binding(
            get: { viewModel.automation.exportConfig.range.displayName },
            set: { name in
                viewModel.automation.exportConfig.range = rangeFromName(name)
            }
        )) {
            ForEach(["Last 24 Hours", "Today", "Yesterday", "This Week", "This Month", "All Time"], id: \.self) { name in
                Text(name).tag(name)
            }
        }
    }

    private var weekdayPicker: some View {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return VStack(alignment: .leading, spacing: OHTheme.Spacing.xs) {
            Text("Days")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 44), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(1...7, id: \.self) { day in
                    let selected = viewModel.automation.schedule.daysOfWeek.contains(day)
                    Button(names[day - 1]) {
                        if selected {
                            viewModel.automation.schedule.daysOfWeek.remove(day)
                        } else {
                            viewModel.automation.schedule.daysOfWeek.insert(day)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? OHTheme.primaryAction : .secondary)
                    .frame(minHeight: OHTheme.minTapTarget)
                }
            }
        }
    }

    private func rangeFromName(_ name: String) -> ExportDateRange {
        switch name {
        case "Today": return .today
        case "Yesterday": return .yesterday
        case "This Week": return .thisWeek
        case "This Month": return .thisMonth
        case "All Time": return .allTime
        default: return .last24Hours
        }
    }
}
