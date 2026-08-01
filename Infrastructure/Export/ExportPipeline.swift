import Foundation

/// App-facing export pipeline wrapping the pure Core coordinator with live destinations.
actor ExportPipeline {
    private let coordinator: ExportPipelineCoordinator
    private let destinationClients: [ExportDestinationKind: any ExportDestinationClient]
    private let clock: any Clock

    init(
        coordinator: ExportPipelineCoordinator,
        destinationClients: [ExportDestinationKind: any ExportDestinationClient],
        clock: any Clock = SystemClock()
    ) {
        self.coordinator = coordinator
        self.destinationClients = destinationClients
        self.clock = clock
    }

    static func live(
        healthDataSource: any HealthDataSource,
        secretStore: any SecretStore,
        historyRepository: any ExportHistoryRepository,
        clock: any Clock = SystemClock(),
        appVersion: String,
        allowLoopbackHTTP: Bool = false
    ) -> ExportPipeline {
        let clients: [ExportDestinationKind: any ExportDestinationClient] = [
            .localFiles: LocalFileDestination(),
            .iCloudDrive: ICloudDestination(),
            .restAPI: RESTDestination(secretStore: secretStore, allowLoopbackHTTP: allowLoopbackHTTP)
        ]
        let coordinator = ExportPipelineCoordinator(
            healthDataSource: healthDataSource,
            secretStore: secretStore,
            historyRepository: historyRepository,
            clock: clock,
            appVersion: appVersion,
            destinationClients: clients,
            allowLoopbackHTTP: allowLoopbackHTTP
        )
        return ExportPipeline(coordinator: coordinator, destinationClients: clients, clock: clock)
    }

    func run(
        request: ExportRequest,
        destinations: [ExportDestination],
        automationID: UUID? = nil,
        automationName: String? = nil,
        progress: (@Sendable (ExportProgress) -> Void)? = nil
    ) async -> ExportReport {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenHealthExports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return await coordinator.run(
            context: .init(
                request: request,
                destinations: destinations,
                automationID: automationID,
                automationName: automationName,
                temporaryDirectory: tmp
            ),
            progress: progress
        )
    }

    /// Re-deliver an existing artifact to destinations without re-reading HealthKit.
    func retryDestinations(
        artifactURL: URL,
        filename: String,
        mimeType: String,
        destinations: [ExportDestination]
    ) async -> [DestinationDeliveryResult] {
        var results: [DestinationDeliveryResult] = []
        for destination in destinations where destination.isEnabled {
            guard let client = destinationClients[destination.kind] else {
                results.append(DestinationDeliveryResult(
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
                        mimeType: mimeType,
                        destination: destination
                    )
                )
                results.append(DestinationDeliveryResult(
                    destinationID: destination.id,
                    destinationName: destination.name,
                    destinationType: destination.kind.displayName,
                    success: outcome.success,
                    artifactURLString: outcome.finalURL?.path,
                    bytesWritten: outcome.bytesWritten,
                    errorDescription: outcome.errorDescription
                ))
            } catch {
                results.append(DestinationDeliveryResult(
                    destinationID: destination.id,
                    destinationName: destination.name,
                    destinationType: destination.kind.displayName,
                    success: false,
                    errorDescription: error.localizedDescription
                ))
            }
        }
        return results
    }
}
