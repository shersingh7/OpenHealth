import SwiftUI

struct ExportBuilderView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ExportViewModel
    @State private var showDataTypes = false
    @State private var showDestinations = false
    @State private var editingDestination: ExportDestination?

    init(container: AppContainer, seed: ExportRequest? = nil) {
        _viewModel = StateObject(wrappedValue: ExportViewModel(container: container, seed: seed))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OHTheme.Spacing.md) {
                    section(number: 1, title: "Data") {
                        dataSection
                    }
                    section(number: 2, title: "Time range") {
                        DateRangePickerView(range: $viewModel.request.range)
                    }
                    section(number: 3, title: "Format & privacy") {
                        formatSection
                    }
                    section(number: 4, title: "Destinations") {
                        destinationsSection
                    }

                    if !viewModel.validationErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.validationErrors.map(\.localizedDescription), id: \.self) { msg in
                                Text(msg)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(OHTheme.Spacing.md)
                .ohContentWidth()
                .padding(.bottom, 100)
            }
            .background(OHTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Export")
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .task { await viewModel.loadDefaults() }
            // Do not discard staged secrets on tab disappear — TabView fires
            // onDisappear when switching tabs, and draft REST credentials must
            // survive for the export session. Staging is memory-only for export
            // (pipeline reads StagedSecretStore; Keychain is not littered).
            .sheet(isPresented: $showDataTypes) {
                DataTypeSelectionView(selection: $viewModel.request.selection)
            }
            .sheet(isPresented: $showDestinations) {
                DestinationPickerView(
                    destinations: $viewModel.destinations,
                    selectedIDs: $viewModel.request.destinationIDs,
                    // Staged: ephemeral export credentials are not written to Keychain.
                    secretStore: viewModel.secretStore
                )
            }
            .sheet(item: $editingDestination) { dest in
                DestinationEditorView(
                    destination: dest,
                    secretStore: viewModel.secretStore
                ) { updated in
                    viewModel.updateDestination(updated)
                }
            }
            .sheet(isPresented: $viewModel.showResult) {
                if let report = viewModel.report {
                    ExportResultView(report: report)
                }
            }
        }
    }

    private func section<Content: View>(number: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        OHCard {
            VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
                Label("\(number). \(title)", systemImage: "\(number).circle.fill")
                    .font(.headline)
                    .foregroundStyle(OHTheme.primaryAction)
                content()
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
            Picker("Selection", selection: Binding(
                get: {
                    if case .allDetected = viewModel.request.selection { return 0 }
                    return 1
                },
                set: { value in
                    if value == 0 {
                        viewModel.request.selection = .allDetected
                    } else if case .explicit = viewModel.request.selection {
                        // keep
                    } else {
                        viewModel.request.selection = .explicit([])
                    }
                }
            )) {
                Text("All supported").tag(0)
                Text("Choose data types").tag(1)
            }
            .pickerStyle(.segmented)

            if case .allDetected = viewModel.request.selection {
                Text("Exports every type OpenHealth supports (not limited to last coverage scan).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if case .explicit(let ids) = viewModel.request.selection {
                Text("\(ids.count) types selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Choose Types…") { showDataTypes = true }
                    .frame(minHeight: OHTheme.minTapTarget)
            }

            Toggle("Include workout routes", isOn: $viewModel.request.includeWorkoutRoutes)
            Text("Routes contain precise location. Off by default. In “Choose data types,” routes export only when workouts or routes are selected.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Include ECG waveforms", isOn: $viewModel.request.includeECGWaveforms)
            Text("Waveforms increase size and sensitivity.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
            ForEach(ExportFormat.allCases) { format in
                Button {
                    viewModel.request.format = format
                } label: {
                    HStack {
                        Image(systemName: format.systemImage)
                        VStack(alignment: .leading) {
                            Text(format.rawValue).fontWeight(.semibold)
                            Text(format.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if viewModel.request.format == format {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OHTheme.primaryAction)
                        }
                    }
                    .frame(minHeight: OHTheme.minTapTarget)
                }
                .buttonStyle(.plain)
            }
            Toggle("Include sample metadata", isOn: $viewModel.request.includeMetadata)
            Text("Metadata may contain device identifiers. Only enable when needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var destinationsSection: some View {
        VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
            ForEach(viewModel.destinations.filter { viewModel.request.destinationIDs.contains($0.id) }) { dest in
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
            .accessibilityIdentifier("oh.export.manageDestinations")
        }
    }

    private var bottomBar: some View {
        VStack(spacing: OHTheme.Spacing.sm) {
            if viewModel.isExporting, let progress = viewModel.progress {
                OHProgressPanel(
                    phaseLabel: progress.phase.accessibilityLabel,
                    fraction: progress.fractionCompleted,
                    onCancel: { viewModel.cancelExport() }
                )
            } else {
                Text(viewModel.readySummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(viewModel.readySummary)
                OHPrimaryButton(title: "Export", systemImage: "square.and.arrow.up") {
                    viewModel.validate()
                    viewModel.startExport()
                }
                .accessibilityIdentifier("oh.export.start")
            }
        }
        .padding(OHTheme.Spacing.md)
        .background(.bar)
    }
}
