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
    var accessToken: String?
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
        accessToken: String? = nil,
        entityId: String? = nil,
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
        self.accessToken = accessToken
        self.entityId = entityId
        self.refreshToken = refreshToken
        self.folderId = folderId
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String, Codable {
    case GET, POST, PUT, PATCH, DELETE
}

enum AuthenticationType: String, Codable {
    case none = "None"
    case basic = "Basic Auth"
    case bearer = "Bearer Token"
    case apiKey = "API Key"
    case oauth2 = "OAuth 2.0"
}