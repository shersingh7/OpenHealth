import Foundation

// MARK: - Secret reference (never holds secret material)

public struct SecretReference: Codable, Hashable, Sendable, Equatable {
    public let id: String

    public init(id: String = UUID().uuidString) {
        self.id = id
    }
}

// MARK: - Destination types

public enum ExportDestinationKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case localFiles = "localFiles"
    case iCloudDrive = "iCloudDrive"
    case restAPI = "restAPI"
    case googleDrive = "googleDrive"
    case dropbox = "dropbox"
    case mqtt = "mqtt"
    case homeAssistant = "homeAssistant"
    case calendar = "calendar"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .localFiles: return "Local Files"
        case .iCloudDrive: return "iCloud Drive"
        case .restAPI: return "REST API"
        case .googleDrive: return "Google Drive"
        case .dropbox: return "Dropbox"
        case .mqtt: return "MQTT"
        case .homeAssistant: return "Home Assistant"
        case .calendar: return "Calendar"
        }
    }

    public var systemImage: String {
        switch self {
        case .localFiles: return "folder.fill"
        case .iCloudDrive: return "icloud.fill"
        case .restAPI: return "network"
        case .googleDrive: return "externaldrive.fill"
        case .dropbox: return "drop.fill"
        case .mqtt: return "antenna.radiowaves.left.and.right"
        case .homeAssistant: return "house.fill"
        case .calendar: return "calendar.badge.clock"
        }
    }

    /// Only these kinds are selectable as implemented destinations.
    public var isImplemented: Bool {
        switch self {
        case .localFiles, .iCloudDrive, .restAPI: return true
        default: return false
        }
    }

    public static var implemented: [ExportDestinationKind] {
        allCases.filter(\.isImplemented)
    }

    public static var planned: [ExportDestinationKind] {
        allCases.filter { !$0.isImplemented }
    }
}

public enum HTTPMETHOD: String, Codable, Sendable, CaseIterable {
    case POST, PUT, PATCH
}

public enum DestinationAuthMode: String, Codable, Sendable, CaseIterable {
    case none
    case bearer
    case apiKey

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .bearer: return "Bearer Token"
        case .apiKey: return "API Key"
        }
    }
}

public enum DestinationConfig: Codable, Sendable, Equatable {
    case localFiles(folderPath: String?)
    case iCloudDrive(folderPath: String?)
    case restAPI(
        endpoint: String,
        method: HTTPMETHOD,
        authMode: DestinationAuthMode,
        secretRef: SecretReference?,
        apiKeyHeaderName: String?,
        customHeaders: [String: String]
    )
    case planned

    enum CodingKeys: String, CodingKey {
        case type, folderPath, endpoint, method, authMode, secretRef, apiKeyHeaderName, customHeaders
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "localFiles":
            self = .localFiles(folderPath: try c.decodeIfPresent(String.self, forKey: .folderPath))
        case "iCloudDrive":
            self = .iCloudDrive(folderPath: try c.decodeIfPresent(String.self, forKey: .folderPath))
        case "restAPI":
            self = .restAPI(
                endpoint: try c.decode(String.self, forKey: .endpoint),
                method: try c.decode(HTTPMETHOD.self, forKey: .method),
                authMode: try c.decode(DestinationAuthMode.self, forKey: .authMode),
                secretRef: try c.decodeIfPresent(SecretReference.self, forKey: .secretRef),
                apiKeyHeaderName: try c.decodeIfPresent(String.self, forKey: .apiKeyHeaderName),
                customHeaders: try c.decodeIfPresent([String: String].self, forKey: .customHeaders) ?? [:]
            )
        default:
            self = .planned
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .localFiles(let folderPath):
            try c.encode("localFiles", forKey: .type)
            try c.encodeIfPresent(folderPath, forKey: .folderPath)
        case .iCloudDrive(let folderPath):
            try c.encode("iCloudDrive", forKey: .type)
            try c.encodeIfPresent(folderPath, forKey: .folderPath)
        case .restAPI(let endpoint, let method, let authMode, let secretRef, let apiKeyHeaderName, let customHeaders):
            try c.encode("restAPI", forKey: .type)
            try c.encode(endpoint, forKey: .endpoint)
            try c.encode(method, forKey: .method)
            try c.encode(authMode, forKey: .authMode)
            try c.encodeIfPresent(secretRef, forKey: .secretRef)
            try c.encodeIfPresent(apiKeyHeaderName, forKey: .apiKeyHeaderName)
            try c.encode(customHeaders, forKey: .customHeaders)
        case .planned:
            try c.encode("planned", forKey: .type)
        }
    }

    /// Collect secret refs for Keychain lifecycle.
    public var secretReferences: [SecretReference] {
        switch self {
        case .restAPI(_, _, _, let secretRef, _, _):
            return secretRef.map { [$0] } ?? []
        default:
            return []
        }
    }
}

public struct ExportDestination: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var kind: ExportDestinationKind
    public var name: String
    public var isEnabled: Bool
    public var config: DestinationConfig

    public init(
        id: UUID = UUID(),
        kind: ExportDestinationKind,
        name: String? = nil,
        isEnabled: Bool = true,
        config: DestinationConfig
    ) {
        self.id = id
        self.kind = kind
        self.name = name ?? kind.displayName
        self.isEnabled = isEnabled
        self.config = config
    }

    public func validate(allowLoopbackHTTP: Bool = false) -> [String] {
        var errors: [String] = []
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { errors.append("Name is required.") }
        if !kind.isImplemented {
            errors.append("\(kind.displayName) is not implemented yet.")
            return errors
        }

        switch config {
        case .localFiles(let folderPath):
            if let path = folderPath, !path.isEmpty {
                do { _ = try PathValidator.validateRelativeFolder(path) }
                catch { errors.append(error.localizedDescription) }
            }
        case .iCloudDrive(let folderPath):
            if let path = folderPath, !path.isEmpty {
                do { _ = try PathValidator.validateRelativeFolder(path) }
                catch { errors.append(error.localizedDescription) }
            }
        case .restAPI(let endpoint, _, let authMode, let secretRef, let apiKeyHeaderName, let headers):
            do {
                _ = try URLValidator.validateHTTPSEndpoint(endpoint, allowLoopbackHTTP: allowLoopbackHTTP)
            } catch {
                errors.append(error.localizedDescription)
            }
            if authMode != .none && secretRef == nil {
                errors.append("Authentication requires a stored secret.")
            }
            if authMode == .apiKey {
                let header = (apiKeyHeaderName?.isEmpty == false) ? apiKeyHeaderName! : "X-API-Key"
                do {
                    try URLValidator.validateAPIKeyHeaderName(header)
                } catch {
                    errors.append(error.localizedDescription)
                }
            }
            do {
                try URLValidator.validateCustomHeaders(headers)
            } catch {
                errors.append(error.localizedDescription)
            }
        case .planned:
            errors.append("Destination is not configured.")
        }
        return errors
    }

    public static func defaultLocal() -> ExportDestination {
        ExportDestination(kind: .localFiles, name: "Local Files", config: .localFiles(folderPath: nil))
    }
}
