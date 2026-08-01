import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: SettingsViewModel
    @State private var showClearConfirm = false
    @State private var showCoverage = false

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let state = viewModel.accessState {
                        Text(state.statusLabel)
                        Text("Apple Health never tells apps whether read access was granted or denied.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Request / Review Health Access") {
                        Task { await viewModel.requestAccess() }
                    }
                    .accessibilityIdentifier("oh.settings.requestAccess")
                    Button("View Data Coverage") { showCoverage = true }
                } header: {
                    Text("Health Access")
                }

                Section {
                    Picker("Default format", selection: $viewModel.settings.defaultFormat) {
                        ForEach(ExportFormat.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    Picker("Default range", selection: Binding(
                        get: { viewModel.settings.defaultRange.displayName },
                        set: { viewModel.settings.defaultRange = rangeFromName($0) }
                    )) {
                        ForEach(["Last 24 Hours", "Today", "This Week", "This Month", "All Time"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    Toggle("Default include metadata", isOn: $viewModel.settings.defaultIncludeMetadata)
                    Toggle("Default include workout routes", isOn: $viewModel.settings.defaultIncludeWorkoutRoutes)
                    Toggle("Default include ECG waveforms", isOn: $viewModel.settings.defaultIncludeECGWaveforms)
                    Button("Save Defaults") {
                        Task { await viewModel.save() }
                    }
                } header: {
                    Text("Export Defaults")
                } footer: {
                    Text("These defaults seed new exports and automations. Workout routes (location) default off.")
                }

                Section {
                    LabeledContent("Notifications", value: viewModel.notificationStatus)
                    Toggle("Prefer completion notifications", isOn: $viewModel.settings.preferNotifications)
                        .onChange(of: viewModel.settings.preferNotifications) { _, _ in
                            Task { await viewModel.save() }
                        }
                    Button("Open System Settings") { viewModel.openSystemSettings() }
                    if let err = viewModel.settings.lastSchedulingError {
                        Text("Last scheduling error: \(err)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text("Background App Refresh and BGTaskScheduler are best effort. Exact fire times are not guaranteed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Background & Notifications")
                }

                Section {
                    LabeledContent("History entries", value: "\(viewModel.historyCount)")
                    Button("Clear Export History", role: .destructive) {
                        showClearConfirm = true
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("History stores operational metadata only, never health sample values. Export files live in Documents / iCloud destinations you choose.")
                }

                Section {
                    Text("OpenHealth does not collect your data. Data is sent only to destinations you choose.")
                    Text("Destination credentials are stored in the Keychain with After First Unlock (This Device Only) so best-effort background exports can run after the device has been unlocked once.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Automation, history, and export files use complete protection until first unlock so background work can run after unlock without leaving health files fully unprotected before unlock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("REST destinations transmit export files to endpoints you configure. Review those endpoints carefully.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Privacy & Security")
                }

                Section {
                    LabeledContent("Version", value: viewModel.appVersion)
                    LabeledContent("Platforms", value: "iOS / iPadOS 17+")
                } header: {
                    Text("Diagnostics")
                }

                Section {
                    if let url = URL(string: "https://github.com/shersingh7/OpenHealth") {
                        Link("GitHub Repository", destination: url)
                    }
                    Text("License: MIT")
                } header: {
                    Text("About")
                }

                if let message = viewModel.message {
                    Section {
                        Text(message).font(.footnote)
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await viewModel.refresh() }
            .confirmationDialog("Clear export history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear", role: .destructive) {
                    Task { await viewModel.clearHistory() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showCoverage) {
                DataCoverageView(container: container)
            }
        }
    }

    private func rangeFromName(_ name: String) -> ExportDateRange {
        switch name {
        case "Today": return .today
        case "This Week": return .thisWeek
        case "This Month": return .thisMonth
        case "All Time": return .allTime
        default: return .last24Hours
        }
    }
}
