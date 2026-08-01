import SwiftUI

struct DataCoverageView: View {
    let container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: DataCoverageSnapshot?
    @State private var isScanning = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isScanning {
                    HStack {
                        ProgressView()
                        Text("Scanning…")
                    }
                }
                if let snapshot {
                    Section {
                        LabeledContent("Detected", value: "\(snapshot.detectedCount)")
                        LabeledContent("Supported catalog", value: "\(snapshot.supportedMetricCount)")
                        LabeledContent("Scanned", value: snapshot.scannedAt.formatted())
                    }
                    Section("Detected metric IDs") {
                        ForEach(snapshot.detectedMetricIDs.sorted(), id: \.self) { id in
                            Text(HealthMetricCatalogCore.metric(for: id)?.displayName ?? id)
                            Text(id)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if !isScanning {
                    Text("No coverage scan yet.")
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Data Coverage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Scan") {
                        Task { await scan() }
                    }
                    .disabled(isScanning)
                    .accessibilityIdentifier("oh.settings.coverage.scan")
                }
            }
            .task { await loadCached() }
        }
    }

    private func loadCached() async {
        let settings = await container.settingsStore.load()
        if let at = settings.lastCoverageScanAt {
            let ids = Set(settings.lastCoverageDetectedMetricIDs)
            if !ids.isEmpty || settings.lastCoverageTypeCount > 0 {
                snapshot = DataCoverageSnapshot(
                    scannedAt: at,
                    detectedMetricIDs: ids,
                    supportedMetricCount: container.healthDataSource.supportedMetricIDs().count
                )
            }
        }
    }

    private func scan() async {
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }
        do {
            let interval = try DateRangeResolver.resolve(.lastYear, now: Date(), calendar: .current)
            let snap = try await container.healthDataSource.scanCoverage(interval: interval)
            snapshot = snap
            var settings = await container.settingsStore.load()
            settings.lastCoverageScanAt = snap.scannedAt
            settings.lastCoverageTypeCount = snap.detectedCount
            settings.lastCoverageDetectedMetricIDs = snap.detectedMetricIDs.sorted()
            try await container.settingsStore.save(settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
