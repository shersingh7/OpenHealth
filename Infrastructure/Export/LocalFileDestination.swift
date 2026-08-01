import Foundation

/// Saves export artifacts into the app Documents directory (Files app / file sharing).
struct LocalFileDestination: ExportDestinationClient, @unchecked Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func deliver(_ request: DestinationDeliveryRequest) async throws -> DestinationDeliveryOutcome {
        guard case .localFiles(let folderPath) = request.destination.config else {
            return DestinationDeliveryOutcome(success: false, errorDescription: "Invalid local destination configuration.")
        }

        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        var directory = documents.appendingPathComponent("Exports", isDirectory: true)

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

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: request.artifactURL, to: destinationURL)
        ProtectedFileIO.applyProtection(to: destinationURL)

        let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
        let bytes = values.fileSize

        // Documents may be backed up by user choice; file protection is until-first-unlock
        // so best-effort background delivery can complete after the device has unlocked once.
        return DestinationDeliveryOutcome(
            success: true,
            finalURL: destinationURL,
            bytesWritten: bytes
        )
    }
}
