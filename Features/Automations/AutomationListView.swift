import SwiftUI

struct AutomationListView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: AutomationListViewModel
    @State private var editing: Automation?
    @State private var creating = false
    @State private var pendingDelete: Automation?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: AutomationListViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.automations.isEmpty {
                    OHStateView(kind: .loading, title: "Loading automations…")
                } else if viewModel.automations.isEmpty {
                    OHStateView(
                        kind: .empty,
                        title: "No automations",
                        message: "Schedule best-effort exports to Local Files, iCloud Drive, or REST.",
                        systemImage: "clock.badge.questionmark",
                        actionTitle: "Create Automation"
                    ) { creating = true }
                } else {
                    List {
                        if let schedulingError = viewModel.schedulingError {
                            Section {
                                Label(schedulingError, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.footnote)
                            }
                        }
                        ForEach(viewModel.automations) { automation in
                            Button {
                                editing = automation
                            } label: {
                                automationRow(automation)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    pendingDelete = automation
                                }
                                Button(automation.isEnabled ? "Pause" : "Enable") {
                                    Task { await viewModel.toggle(automation) }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button("Run") {
                                    Task { await viewModel.runNow(automation) }
                                }
                                .tint(OHTheme.primaryAction)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Automations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        creating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create automation")
                    .accessibilityIdentifier("oh.automations.create")
                }
            }
            .task { await viewModel.refresh() }
            .refreshable { await viewModel.refresh() }
            .sheet(item: $editing) { automation in
                AutomationEditorView(container: container, automation: automation) {
                    Task { await viewModel.refresh() }
                }
                .environmentObject(container)
            }
            .sheet(isPresented: $creating) {
                AutomationEditorView(container: container, automation: nil) {
                    Task { await viewModel.refresh() }
                }
                .environmentObject(container)
            }
            .confirmationDialog(
                "Delete automation?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDelete {
                        Task { await viewModel.delete(pendingDelete) }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Associated Keychain secrets are removed only when unused by other destinations.")
            }
        }
    }

    private func automationRow(_ automation: Automation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(automation.name)
                    .font(.headline)
                Spacer()
                OHStatusBadge(
                    title: automation.isEnabled ? "Enabled" : "Paused",
                    kind: automation.isEnabled ? .info : .neutral
                )
            }
            Text(automation.schedule.bestEffortDisplayString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.selectionLabel(automation.exportConfig))
                .font(.caption)
            Text(automation.exportConfig.destinations.map(\.name).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let next = automation.nextEligibleAt {
                Text("Next eligible: \(next.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let last = automation.lastRun {
                Text("Last: \(last.formatted()) · \(automation.executionStatus.displayName)")
                    .font(.caption2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("oh.automations.row.\(automation.id.uuidString)")
    }
}
