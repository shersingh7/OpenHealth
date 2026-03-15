//
//  AutomationListView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI

struct AutomationListView: View {
    @StateObject private var viewModel = AutomationListViewModel()
    @State private var showingAddAutomation = false
    @State private var selectedAutomation: Automation?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.automations.isEmpty {
                    emptyStateView
                } else {
                    automationListView
                }
            }
            .navigationTitle("Automations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAutomation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAutomation) {
                AutomationDetailView(automation: nil) { newAutomation in
                    viewModel.addAutomation(newAutomation)
                }
            }
            .sheet(item: $selectedAutomation) { automation in
                AutomationDetailView(automation: automation) { updated in
                    viewModel.updateAutomation(updated)
                }
            }
            .task {
                viewModel.loadAutomations()
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Automations", systemImage: "gearshape.2")
        } description: {
            Text("Create an automation to automatically export your health data on a schedule.")
        } actions: {
            Button {
                showingAddAutomation = true
            } label: {
                Label("Create Automation", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var automationListView: some View {
        List {
            ForEach(viewModel.automations) { automation in
                Button {
                    selectedAutomation = automation
                } label: {
                    AutomationRowView(automation: automation)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                indexSet.forEach { viewModel.deleteAutomation(at: $0) }
            }
        }
    }
}

// MARK: - Automation Row View

struct AutomationRowView: View {
    let automation: Automation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: automation.isEnabled ? "clock.fill" : "clock")
                    .foregroundStyle(automation.isEnabled ? .blue : .secondary)

                Text(automation.name)
                    .font(.headline)

                Spacer()

                if automation.isEnabled {
                    Text(automation.schedule.displayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                Label(
                    "\(automation.exportConfiguration.dataTypes.count) types",
                    systemImage: "heart.text.square"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Label(
                    automation.exportConfiguration.format.rawValue,
                    systemImage: "doc"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let lastRun = automation.lastRun {
                HStack {
                    Label(
                        "Last run: \(lastRun, style: .relative)",
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.green)

                    if automation.runCount > 0 {
                        Text("(\(automation.runCount) runs)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = automation.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Automation List View Model

@MainActor
class AutomationListViewModel: ObservableObject {
    @Published var automations: [Automation] = []

    private let defaultsKey = "OpenHealth_Automations"

    func loadAutomations() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        automations = (try? JSONDecoder().decode([Automation].self, from: data)) ?? []
    }

    func saveAutomations() {
        guard let data = try? JSONEncoder().encode(automations) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    func addAutomation(_ automation: Automation) {
        automations.append(automation)
        saveAutomations()
    }

    func updateAutomation(_ automation: Automation) {
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index] = automation
            saveAutomations()
        }
    }

    func deleteAutomation(at index: Int) {
        automations.remove(at: index)
        saveAutomations()
    }
}

#Preview {
    AutomationListView()
}