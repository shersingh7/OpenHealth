import Foundation

/// Saves export artifacts into the app's iCloud Drive container Documents folder.
struct ICloudDestination: ExportDestinationClient, @unchecked Sendable {
    static let containerIdentifier = "iCloud.com.shersingh7.openhealth"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func deliver(_ request: DestinationDeliveryRequest) async throws -> DestinationDeliveryOutcome {
        guard case .iCloudDrive(let folderPath) = request.destination.config else {
            return DestinationDeliveryOutcome(success: false, errorDescription: "Invalid iCloud destination configuration.")
        }

        guard let containerRoot = fileManager.url(forUbiquityContainerIdentifier: Self.containerIdentifier) else {
            return DestinationDeliveryOutcome(
                success: false,
                errorDescription: "iCloud Drive is unavailable. Sign in to iCloud and enable iCloud Drive."
            )
        }

        var directory = containerRoot.appendingPathComponent("Documents", isDirectory: true)
        if let folderPath, !folderPath.isEmpty {
            let normalized = try PathValidator.validateRelativeFolder(folderPath)
            directory = directory.appendingPathComponent(normalized, isDirectory: true)
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var destinationURL = directory.appendingPathComponent(request.filename)
        if fileManager.fileExists(atPath: destinationURL.path) {
            let base = destinationURL.deletingPathExtension().lastPathComponent
            let ext = destinationURL.pathExtension
            destinationURL = directory.appendingPathComponent("\(base)_\(UUID().uuidString.prefix(8)).\(ext)")
        }

        // Copy via coordinated write-friendly path
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: request.artifactURL, to: destinationURL)
        ProtectedFileIO.applyProtection(to: destinationURL)

        let values = try? destinationURL.resourceValues(forKeys: [.fileSizeKey])
        return DestinationDeliveryOutcome(
            success: true,
            finalURL: destinationURL,
            bytesWritten: values?.fileSize
        )
    }
}
