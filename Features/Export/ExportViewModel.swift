import Foundation

@MainActor
final class ExportViewModel: ObservableObject {
    @Published var request: ExportRequest
    @Published var destinations: [ExportDestination]
    @Published var validationErrors: [ExportRequestValidationError] = []
    @Published var isExporting = false
    @Published var progress: ExportProgress?
    @Published var report: ExportReport?
    @Published var showResult = false

    private let container: AppContainer
    private var exportTask: Task<Void, Never>?
    /// Stages credentials for this export session; never commits unless needed.
    /// Export uses a pipeline that reads the staging store so cancel/leave
    /// does not leave Keychain orphans from ephemeral destinations.
    let secretStaging: StagedSecretStore

    init(container: AppContainer, seed: ExportRequest? = nil) {
        self.container = container
        self.secretStaging = StagedSecretStore(underlying: container.secretStore)
        let local = ExportDestination.defaultLocal()
        self.destinations = [local]
        if var seed {
            if seed.destinationIDs.isEmpty {
                seed.destinationIDs = [local.id]
            }
            self.request = seed
        } else {
            self.request = ExportRequest(
                name: "Export",
                selection: .allDetected,
                range: .last24Hours,
                format: .json,
                destinationIDs: [local.id]
            )
        }
    }

    var secretStore: any SecretStore { secretStaging }

    func loadDefaults() async {
        let settings = await container.settingsStore.load()
        request.range = settings.defaultRange
        request.format = settings.defaultFormat
        request.includeMetadata = settings.defaultIncludeMetadata
        request.includeWorkoutRoutes = settings.defaultIncludeWorkoutRoutes
        request.includeECGWaveforms = settings.defaultIncludeECGWaveforms
    }

    func validate() {
        let selected = destinations.filter { request.destinationIDs.contains($0.id) }
        validationErrors = ExportRequestValidator.validate(
            request,
            destinations: selected,
            now: container.clock.now(),
            calendar: .current
        )
    }

    var isValid: Bool {
        validate()
        return validationErrors.isEmpty
    }

    var readySummary: String {
        let types: String
        switch request.selection {
        case .allDetected: types = "All supported"
        case .explicit(let ids): types = "\(ids.count) types"
        }
        let destCount = destinations.filter { request.destinationIDs.contains($0.id) && $0.isEnabled }.count
        return "Ready: \(types) · \(request.range.displayName) · \(request.format.rawValue) · \(destCount) destination(s)"
    }

    func startExport() {
        validate()
        guard validationErrors.isEmpty else { return }
        isExporting = true
        progress = ExportProgress(phase: .validating, fractionCompleted: 0)
        report = nil

        exportTask = Task { [weak self] in
            guard let self else { return }
            // Pipeline reads staged secrets without permanently writing Keychain
            // for ephemeral export destinations (avoids orphans if user abandons).
            let pipeline = self.container.makeExportPipeline(secretStore: self.secretStaging)
            let report = await pipeline.run(
                request: self.request,
                destinations: self.destinations,
                progress: { prog in
                    Task { @MainActor in
                        self.progress = prog
                    }
                }
            )
            await MainActor.run {
                self.report = report
                self.isExporting = false
                self.progress = nil
                self.showResult = true
            }
        }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        progress = ExportProgress(phase: .cancelled, fractionCompleted: 0)
    }

    func discardSecretStaging() async {
        await secretStaging.discard()
    }

    func addDestination(_ destination: ExportDestination) {
        if !destinations.contains(where: { $0.id == destination.id }) {
            destinations.append(destination)
        }
        if !request.destinationIDs.contains(destination.id) {
            request.destinationIDs.append(destination.id)
        }
    }

    func removeDestination(_ id: UUID) {
        destinations.removeAll { $0.id == id }
        request.destinationIDs.removeAll { $0 == id }
    }

    func updateDestination(_ destination: ExportDestination) {
        if let idx = destinations.firstIndex(where: { $0.id == destination.id }) {
            destinations[idx] = destination
        }
    }
}
