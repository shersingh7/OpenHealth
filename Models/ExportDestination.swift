//
//  ExportDestination.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import Foundation

// MARK: - Export Destination Protocol

/// Protocol for all export destinations
protocol ExportDestinationProtocol {
    var id: UUID { get }
    var name: String { get }
    var type: ExportDestinationType { get }
    var isEnabled: Bool { get set }

    func export(data: Data, filename: String) async throws -> URL
    func validateConfiguration() -> Bool
}

// MARK: - Export Destination Type

/// Types of export destinations
enum ExportDestinationType: String, CaseIterable, Identifiable, Codable {
    case localFiles = "Local Files"
    case iCloudDrive = "iCloud Drive"
    case restAPI = "REST API"
    case googleDrive = "Google Drive"
    case dropbox = "Dropbox"
    case mqtt = "MQTT"
    case homeAssistant = "Home Assistant"
    case calendar = "Calendar"

    var id: String { rawValue }

    var systemImage: String {
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

    var description: String {
        switch self {
        case .localFiles:
            return "Save to Files app on your device"
        case .iCloudDrive:
            return "Sync across all your Apple devices"
        case .restAPI:
            return "Send to any REST API endpoint"
        case .googleDrive:
            return "Upload to Google Drive"
        case .dropbox:
            return "Upload to Dropbox"
        case .mqtt:
            return "Publish to MQTT broker for IoT"
        case .homeAssistant:
            return "Send to Home Assistant sensors"
        case .calendar:
            return "Create calendar events from health data"
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .localFiles, .iCloudDrive, .restAPI, .mqtt:
            return false
        case .googleDrive, .dropbox, .homeAssistant, .calendar:
            return true
        }
    }
}

// MARK: - Export Destination

/// Configuration for an export destination
struct ExportDestination: Identifiable, Codable {
    let id: UUID
    let type: ExportDestinationType
    var name: String
    var isEnabled: Bool
    var configuration: DestinationConfiguration

    init(
        id: UUID = UUID(),
        type: ExportDestinationType,
        name: String? = nil,
        isEnabled: Bool = true,
        configuration: DestinationConfiguration = DestinationConfiguration()
    ) {
        self.id = id
        self.type = type
        self.name = name ?? type.rawValue
        self.isEnabled = isEnabled
        self.configuration = configuration
    }

    /// Validate the destination configuration
    func validateConfiguration() -> ValidationResult {
        switch type {
        case .localFiles:
            return .valid

        case .iCloudDrive:
            return .valid

        case .restAPI:
            guard let urlString = configuration.apiURL, !urlString.isEmpty else {
                return .invalid("API URL is required")
            }
            guard URL(string: urlString) != nil else {
                return .invalid("Invalid API URL format")
            }
            return .valid

        case .mqtt:
            guard let brokerURL = configuration.brokerURL, !brokerURL.isEmpty else {
                return .invalid("Broker URL is required")
            }
            guard configuration.port > 0 && configuration.port <= 65535 else {
                return .invalid("Port must be between 1 and 65535")
            }
            guard let topic = configuration.topic, !topic.isEmpty else {
                return .invalid("Topic is required")
            }
            return .valid

        case .homeAssistant:
            guard let url = configuration.homeAssistantURL, !url.isEmpty else {
                return .invalid("Home Assistant URL is required")
            }
            guard let token = configuration.homeAssistantToken, !token.isEmpty else {
                return .invalid("Access token is required")
            }
            guard let entityId = configuration.entityId, !entityId.isEmpty else {
                return .invalid("Entity ID is required")
            }
            return .valid

        case .googleDrive, .dropbox:
            guard let token = configuration.accessToken, !token.isEmpty else {
                return .invalid("Authentication is required")
            }
            return .valid

        case .calendar:
            return .valid
        }
    }
}

// MARK: - Validation Result

enum ValidationResult {
    case valid
    case invalid(String)

    var isValid: Bool {
        switch self {
        case .valid: return true
        case .invalid: return false
        }
    }

    var errorMessage: String? {
        switch self {
        case .valid: return nil
        case .invalid(let message): return message
        }
    }
}

// MARK: - Destination Configuration

/// Configuration options for destinations
struct DestinationConfiguration: Codable {
    // Local Files / iCloud Drive
    var folderPath: String?

    // REST API
    var apiURL: String?
    var httpMethod: HTTPMethod
    var headers: [String: String]
    var authentication: AuthenticationType

    // MQTT
    var brokerURL: String?
    var port: Int
    var topic: String?
    var clientId: String?
    var username: String?
    var password: String?

    // Home Assistant
    var homeAssistantURL: String?
    var homeAssistantToken: String?
    var entityId: String?

    // Google Drive / Dropbox
    var accessToken: String?
    var refreshToken: String?
    var folderId: String?

    init(
        folderPath: String? = nil,
        apiURL: String? = nil,
        httpMethod: HTTPMethod = .POST,
        headers: [String: String] = [:],
        authentication: AuthenticationType = .none,
        brokerURL: String? = nil,
        port: Int = 1883,
        topic: String? = nil,
        clientId: String? = nil,
        username: String? = nil,
        password: String? = nil,
        homeAssistantURL: String? = nil,
        homeAssistantToken: String? = nil,
        entityId: String? = nil,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        folderId: String? = nil
    ) {
        self.folderPath = folderPath
        self.apiURL = apiURL
        self.httpMethod = httpMethod
        self.headers = headers
        self.authentication = authentication
        self.brokerURL = brokerURL
        self.port = port
        self.topic = topic
        self.clientId = clientId
        self.username = username
        self.password = password
        self.homeAssistantURL = homeAssistantURL
        self.homeAssistantToken = homeAssistantToken
        self.entityId = entityId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.folderId = folderId
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String, Codable {
    case GET, POST, PUT, PATCH, DELETE
}

enum AuthenticationType: String, CaseIterable, Codable {
    case none = "None"
    case basic = "Basic Auth"
    case bearer = "Bearer Token"
    case apiKey = "API Key"
    case oauth2 = "OAuth 2.0"
}