import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var accessState: HealthAccessState?
    @Published var lastExport: ExportHistoryEntry?
    @Published var nextAutomation: (name: String, date: Date)?
    @Published var coverage: DataCoverageSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        accessState = await container.healthDataSource.accessState()
        lastExport = try? await container.historyRepository.loadRecent(limit: 1).first
        nextAutomation = await container.automationCoordinator.nextEligibleSummary()

        let settings = await container.settingsStore.load()
        if let scanned = settings.lastCoverageScanAt {
            let ids = Set(settings.lastCoverageDetectedMetricIDs)
            // Prefer actual cached IDs; fall back to count-only display when IDs were never stored.
            if !ids.isEmpty || settings.lastCoverageTypeCount > 0 {
                coverage = DataCoverageSnapshot(
                    scannedAt: scanned,
                    detectedMetricIDs: ids,
                    supportedMetricCount: container.healthDataSource.supportedMetricIDs().count
                )
            }
        }
    }

    func scanCoverage() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let interval = try DateRangeResolver.resolve(
                .lastYear,
                now: container.clock.now(),
                calendar: .current
            )
            let snap = try await container.healthDataSource.scanCoverage(interval: interval)
            coverage = snap
            var settings = await container.settingsStore.load()
            settings.lastCoverageScanAt = snap.scannedAt
            settings.lastCoverageTypeCount = snap.detectedCount
            settings.lastCoverageDetectedMetricIDs = snap.detectedMetricIDs.sorted()
            try await container.settingsStore.save(settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAccess() async {
        do {
            accessState = try await container.healthDataSource.requestReadAccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
