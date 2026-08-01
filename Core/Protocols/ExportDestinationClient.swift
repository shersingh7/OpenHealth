import Foundation

public struct DestinationDeliveryRequest: Sendable {
    public let artifactURL: URL
    public let filename: String
    public let mimeType: String
    public let destination: ExportDestination

    public init(artifactURL: URL, filename: String, mimeType: String, destination: ExportDestination) {
        self.artifactURL = artifactURL
        self.filename = filename
        self.mimeType = mimeType
        self.destination = destination
    }
}

public struct DestinationDeliveryOutcome: Sendable {
    public let success: Bool
    public let finalURL: URL?
    public let bytesWritten: Int?
    public let errorDescription: String?

    public init(success: Bool, finalURL: URL? = nil, bytesWritten: Int? = nil, errorDescription: String? = nil) {
        self.success = success
        self.finalURL = finalURL
        self.bytesWritten = bytesWritten
        self.errorDescription = errorDescription
    }
}

public protocol ExportDestinationClient: Sendable {
    func deliver(_ request: DestinationDeliveryRequest) async throws -> DestinationDeliveryOutcome
}
