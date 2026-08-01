import SwiftUI

struct DataTypeSelectionView: View {
    @Binding var selection: ExportRequest.Selection
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selected: Set<String> = []

    private var metrics: [HealthMetric] {
        HealthMetricCatalogCore.allMetrics.sorted {
            if $0.category.sortOrder != $1.category.sortOrder {
                return $0.category.sortOrder < $1.category.sortOrder
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var filtered: [HealthMetric] {
        guard !search.isEmpty else { return metrics }
        return metrics.filter {
            $0.displayName.localizedCaseInsensitiveContains(search)
                || $0.id.localizedCaseInsensitiveContains(search)
        }
    }

    private var grouped: [(HealthDataCategory, [HealthMetric])] {
        let dict = Dictionary(grouping: filtered, by: \.category)
        return dict.keys.sorted { $0.sortOrder < $1.sortOrder }.map { ($0, dict[$0]!) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { category, items in
                    Section {
                        ForEach(items) { metric in
                            Button {
                                toggle(metric.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(metric.displayName)
                                        Text(metric.id)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if selected.contains(metric.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(OHTheme.primaryAction)
                                    }
                                }
                                .frame(minHeight: OHTheme.minTapTarget)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(metric.displayName), \(selected.contains(metric.id) ? "selected" : "not selected"), \(category.rawValue)")
                        }
                    } header: {
                        Text(category.rawValue)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search name or identifier")
            .navigationTitle("Data Types")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        selection = .explicit(selected)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                    .accessibilityIdentifier("oh.export.dataTypes.done")
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Select All Supported") {
                        selected = Set(metrics.map(\.id))
                    }
                }
            }
            .onAppear {
                if case .explicit(let ids) = selection {
                    selected = ids
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}
