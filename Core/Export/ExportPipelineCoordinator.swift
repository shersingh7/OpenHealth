import Foundation

/// Pure pipeline orchestration used by Infrastructure and tested with fakes.
public actor ExportPipelineCoordinator {
    private let healthDataSource: any HealthDataSource
    private let secretStore: any SecretStore
    private let historyRepository: any ExportHistoryRepository
    private let clock: any Clock
    private let calendar: Calendar
    private let appVersion: String
    private let destinationClients: [ExportDestinationKind: any ExportDestinationClient]
    private let allowLoopbackHTTP: Bool

    public init(
        healthDataSource: any HealthDataSource,
        secretStore: any SecretStore,
        historyRepository: any ExportHistoryRepository,
        clock: any Clock,
        calendar: Calendar = Calendar(identifier: .gregorian),
        appVersion: String = "1.0",
        destinationClients: [ExportDestinationKind: any ExportDestinationClient],
        allowLoopbackHTTP: Bool = false
    ) {
        self.healthDataSource = healthDataSource
        self.secretStore = secretStore
        self.historyRepository = historyRepository
        self.clock = clock
        self.calendar = calendar
        self.appVersion = appVersion
        self.destinationClients = destinationClients
        self.allowLoopbackHTTP = allowLoopbackHTTP
    }

    public struct RunContext: Sendable {
        public let request: ExportRequest
        public let destinations: [ExportDestination]
        public let automationID: UUID?
        public let automationName: String?
        public let temporaryDirectory: URL

        public init(
            request: ExportRequest,
            destinations: [ExportDestination],
            automationID: UUID? = nil,
            automationName: String? = nil,
            temporaryDirectory: URL
        ) {
            self.request = request
            self.destinations = destinations
            self.automationID = automationID
            self.automationName = automationName
            self.temporaryDirectory = temporaryDirectory
        }
    }

    public func run(
        context: RunContext,
        progress: (@Sendable (ExportProgress) -> Void)? = nil
    ) async -> ExportReport {
        let startedAt = clock.now()
        let exportID = context.request.id
        progress?(ExportProgress(phase: .validating, fractionCompleted: 0.02))

        let selectedDestinations = context.destinations.filter {
            context.request.destinationIDs.contains($0.id) && $0.isEnabled
        }

        let validationErrors = ExportRequestValidator.validate(
            context.request,
            destinations: selectedDestinations,
            now: startedAt,
            calendar: calendar
        )
        if !validationErrors.isEmpty {
            return failureReport(
                exportID: exportID,
                startedAt: startedAt,
                message: validationErrors.map(\.localizedDescription).joined(separator: " "),
                warnings: []
            )
        }

        let interval: DateInterval
        do {
            interval = try DateRangeResolver.resolve(context.request.range, now: startedAt, calendar: calendar)
        } catch {
            return failureReport(exportID: exportID, startedAt: startedAt, message: error.localizedDescription, warnings: [])
        }

        if Task.isCancelled {
            return cancelledReport(exportID: exportID, startedAt: startedAt)
        }

        let metricIDs = MetricSelectionResolver.resolveMetricIDs(
            selection: context.request.selection,
            includeWorkoutRoutes: context.request.includeWorkoutRoutes
        )
        let includeRoutes = MetricSelectionResolver.shouldIncludeRoutes(
            metricIDs: metricIDs,
            includeWorkoutRoutes: context.request.includeWorkoutRoutes
        )
        progress?(ExportProgress(phase: .reading(current: 0, total: max(metricIDs.count, 1), label: "Health data"), fractionCompleted: 0.1))

        let snapshot: HealthDataSnapshot
        do {
            snapshot = try await healthDataSource.fetchSnapshot(
                options: HealthQueryOptions(
                    metricIDs: metricIDs,
                    interval: interval,
                    includeMetadata: context.request.includeMetadata,
                    includeWorkoutRoutes: includeRoutes,
                    includeECGWaveforms: context.request.includeECGWaveforms
                )
            )
        } catch {
            if Task.isCancelled {
                return cancelledReport(exportID: exportID, startedAt: startedAt)
            }
            return failureReport(exportID: exportID, startedAt: startedAt, message: error.localizedDescription, warnings: [])
        }

        if Task.isCancelled {
            return cancelledReport(exportID: exportID, startedAt: startedAt)
        }

        let document = ExportDocument(
            exportID: exportID,
            generatedAt: clock.now(),
            appVersion: appVersion,
            requestedRange: interval,
            includedMetricIDs: metricIDs.sorted(),
            quantityRecords: snapshot.quantityRecords,
            categoryRecords: snapshot.categoryRecords,
            workouts: snapshot.workouts,
            electrocardiograms: snapshot.electrocardiograms,
            activitySummaries: snapshot.activitySummaries,
            warnings: snapshot.warnings
        )

        progress?(ExportProgress(phase: .encoding(format: context.request.format), fractionCompleted: 0.55))

        let filename = FilenameGenerator.generate(
            prefix: PathValidator.sanitizeFilenameComponent(context.request.name),
            format: context.request.format,
            now: clock.now(),
            collisionSuffix: String(exportID.uuidString.prefix(8))
        )
        let artifactURL = context.temporaryDirectory.appendingPathComponent(filename)

        do {
            try FileManager.default.createDirectory(
                at: context.temporaryDirectory,
                withIntermediateDirectories: true
            )
            try encode(document: document, format: context.request.format, to: artifactURL)
        } catch {
            return failureReport(
                exportID: exportID,
                startedAt: startedAt,
                message: error.localizedDescription,
                warnings: document.warnings,
                recordCount: document.totalRecords
            )
        }

        if Task.isCancelled {
            try? FileManager.default.removeItem(at: artifactURL)
            return cancelledReport(exportID: exportID, startedAt: startedAt)
        }

        var deliveryResults: [DestinationDeliveryResult] = []
        let totalDest = max(selectedDestinations.count, 1)
        for (index, destination) in selectedDestinations.enumerated() {
            progress?(ExportProgress(
                phase: .delivering(current: index + 1, total: totalDest, name: destination.name),
                fractionCompleted: 0.6 + 0.35 * Double(index + 1) / Double(totalDest)
            ))

            guard let client = destinationClients[destination.kind] else {
                deliveryResults.append(DestinationDeliveryResult(
                    destinationID: destination.id,
                    destinationName: destination.name,
                    destinationType: destination.kind.displayName,
                    success: false,
                    errorDescription: "No client for destination type."
                ))
                continue
            }

            do {
                let outcome = try await client.deliver(
                    DestinationDeliveryRequest(
                        artifactURL: artifactURL,
                        filename: filename,
                        mimeType: context.request.format.mimeType,
                        destination: destination
                    )
                )
                deliveryResults.append(DestinationDeliveryResult(
                    destinationID: destination.id,
                    destinationName: destination.name,
                    destinationType: destination.kind.displayName,
                    success: outcome.success,
                    artifactURLString: outcome.finalURL?.path,
                    bytesWritten: outcome.bytesWritten,
                    errorDescription: outcome.errorDescription
                ))
            } catch {
                deliveryResults.append(DestinationDeliveryResult(
                    destinationID: destination.id,
                    destinationName: destination.name,
                    destinationType: destination.kind.displayName,
                    success: false,
                    errorDescription: error.localizedDescription
                ))
            }
        }

        let successes = deliveryResults.filter(\.success).count
        let failures = deliveryResults.count - successes
        let outcome: ExportOutcome
        if successes == deliveryResults.count && !deliveryResults.isEmpty {
            outcome = .completeSuccess
        } else if successes > 0 {
            outcome = .partialSuccess
        } else {
            outcome = .failure
        }

        progress?(ExportProgress(phase: .completed, fractionCompleted: 1.0))

        let completedAt = clock.now()
        let report = ExportReport(
            exportID: exportID,
            startedAt: startedAt,
            completedAt: completedAt,
            serializedRecordCount: document.totalRecords,
            artifactURL: artifactURL,
            destinationResults: deliveryResults,
            warnings: document.warnings,
            outcome: outcome,
            errorDescription: failures > 0 && successes == 0 ? "All destinations failed." : nil
        )

        let history = ExportHistoryEntry(
            exportID: exportID,
            startedAt: startedAt,
            completedAt: completedAt,
            format: context.request.format,
            rangeDescription: context.request.range.displayName,
            serializedRecordCount: document.totalRecords,
            outcome: outcome,
            destinationSummaries: deliveryResults.map {
                "\($0.destinationName): \($0.success ? "ok" : "failed")"
            },
            warningCount: document.warnings.count,
            automationID: context.automationID,
            automationName: context.automationName,
            errorDescription: report.errorDescription
        )
        try? await historyRepository.append(history)

        return report
    }

    // MARK: - Helpers

    private func encode(document: ExportDocument, format: ExportFormat, to url: URL) throws {
        switch format {
        case .json:
            try JSONExportEncoder.encode(document, to: url)
        case .csv:
            try CSVExportEncoder.encode(document, to: url)
        case .gpx:
            try GPXExportEncoder.encode(workouts: document.workouts, to: url)
        }
    }

    private func failureReport(
        exportID: UUID,
        startedAt: Date,
        message: String,
        warnings: [ExportWarning],
        recordCount: Int = 0
    ) -> ExportReport {
        ExportReport(
            exportID: exportID,
            startedAt: startedAt,
            completedAt: clock.now(),
            serializedRecordCount: recordCount,
            artifactURL: nil,
            destinationResults: [],
            warnings: warnings,
            outcome: .failure,
            errorDescription: message
        )
    }

    private func cancelledReport(exportID: UUID, startedAt: Date) -> ExportReport {
        ExportReport(
            exportID: exportID,
            startedAt: startedAt,
            completedAt: clock.now(),
            serializedRecordCount: 0,
            artifactURL: nil,
            destinationResults: [],
            warnings: [],
            outcome: .cancelled,
            errorDescription: "Export cancelled."
        )
    }
}
