import Foundation

/// Transactional migration from legacy `openhealth.automations` UserDefaults blob.
/// Merges by ID with existing v2 entries. Secrets move to Keychain before the new file is committed.
/// On failure, leave legacy untouched. Never write secret material into JSON.
struct LegacyAutomationMigrator {
    static let legacyKey = "openhealth.automations"
    static let migrationMarkerKey = "openhealth.automations.migrated.v1"

    private let defaults: UserDefaults
    private let secretStore: any SecretStore
    private let repository: any AutomationRepository

    init(
        defaults: UserDefaults = .standard,
        secretStore: any SecretStore,
        repository: any AutomationRepository
    ) {
        self.defaults = defaults
        self.secretStore = secretStore
        self.repository = repository
    }

    enum Outcome: Equatable {
        case alreadyMigrated
        case nothingToMigrate
        case migrated(count: Int, warnings: [String])
        case failed(String)
    }

    func migrateIfNeeded() async -> Outcome {
        if defaults.bool(forKey: Self.migrationMarkerKey) {
            return .alreadyMigrated
        }
        guard let data = defaults.data(forKey: Self.legacyKey) else {
            defaults.set(true, forKey: Self.migrationMarkerKey)
            return .nothingToMigrate
        }

        var originalRepository: [Automation]?
        var secretBackups: [(reference: SecretReference, previousValue: String?)] = []

        do {
            let legacy = try JSONDecoder().decode([LegacyAutomationDTO].self, from: data)
            let existing = try await repository.loadAll()
            originalRepository = existing
            var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            var migratedIDs = Set<UUID>()
            var secretsToVerify: [SecretReference] = []
            var warnings: [String] = []

            for item in legacy {
                // A v2 record is authoritative. Skip before converting or touching
                // deterministic Keychain references so legacy data cannot overwrite
                // a newer destination credential.
                if byID[item.id] != nil {
                    warnings.append("Skipped legacy automation “\(item.name)” — already present in v2 storage.")
                    continue
                }

                let (automation, secrets, itemWarnings) = try await convert(item)
                warnings.append(contentsOf: itemWarnings)

                // Write and verify secrets before committing the merged repository.
                // Back up any pre-existing value so every failure path can roll back.
                for (ref, value) in secrets {
                    let previous = try? await secretStore.load(reference: ref)
                    secretBackups.append((ref, previous))
                    try await secretStore.save(secret: value, for: ref)
                    let loaded = try await secretStore.load(reference: ref)
                    guard loaded == value else {
                        throw MigrationError.secretVerificationFailed
                    }
                    secretsToVerify.append(ref)
                }

                byID[automation.id] = automation
                migratedIDs.insert(automation.id)
            }

            try await repository.saveAll(Array(byID.values))

            // Verify the durable repository and every Keychain reference before
            // deleting the only legacy copy.
            let loadedIDs = Set(try await repository.loadAll().map(\.id))
            guard migratedIDs.isSubset(of: loadedIDs) else {
                throw MigrationError.repositoryVerificationFailed
            }
            for ref in secretsToVerify {
                guard await secretStore.exists(reference: ref) else {
                    throw MigrationError.secretVerificationFailed
                }
            }

            defaults.removeObject(forKey: Self.legacyKey)
            defaults.set(true, forKey: Self.migrationMarkerKey)
            // Count only — no names, endpoints, or secrets.
            AppLogger.persistence.info("Migrated automation count: \(migratedIDs.count, privacy: .public)")
            return .migrated(count: migratedIDs.count, warnings: warnings)
        } catch {
            // Roll back both stores. The legacy blob and marker remain untouched,
            // so the migration can be retried without data or credential loss.
            if let originalRepository {
                try? await repository.saveAll(originalRepository)
            }
            for backup in secretBackups.reversed() {
                if let previous = backup.previousValue {
                    try? await secretStore.save(secret: previous, for: backup.reference)
                } else {
                    try? await secretStore.delete(reference: backup.reference)
                }
            }
            AppLogger.persistence.error("Migration failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
            return .failed(error.localizedDescription)
        }
    }

    private enum MigrationError: LocalizedError {
        case secretVerificationFailed
        case repositoryVerificationFailed
        case unsupportedCredentialedDestination(String)
        case multipleCredentials(String)
        case unsupportedAuthorizationScheme(String)

        var errorDescription: String? {
            switch self {
            case .secretVerificationFailed:
                return "A destination credential could not be verified. Legacy data was kept."
            case .repositoryVerificationFailed:
                return "Migrated automations could not be verified. Legacy data was kept."
            case .unsupportedCredentialedDestination(let name):
                return "“\(name)” uses credentials for a destination that is not implemented. Legacy data was kept."
            case .multipleCredentials(let name):
                return "“\(name)” uses multiple credentials that cannot be represented safely. Legacy data was kept."
            case .unsupportedAuthorizationScheme(let name):
                return "“\(name)” uses an unsupported Authorization scheme. Legacy data was kept."
            }
        }
    }

    // MARK: - Legacy DTOs (shape of old Codable models)

    struct LegacyAutomationDTO: Codable {
        let id: UUID
        var name: String
        var exportConfiguration: LegacyExportConfigurationDTO
        var schedule: LegacyScheduleDTO
        var isEnabled: Bool
        var executionStatus: String?
        var retryCount: Int?
        var maxRetries: Int?
        var lastRun: Date?
        var nextRun: Date?
        var runCount: Int?
        var lastError: String?
        var createdAt: Date?
        var lastModified: Date?
        var iCloudFolderPath: String?
    }

    struct LegacyExportConfigurationDTO: Codable {
        var dataTypes: Set<String>?
        var exportAllAvailableTypes: Bool?
        var format: String?
        var dateRange: String?
        var customStartDate: Date?
        var customEndDate: Date?
        var destinations: [LegacyDestinationDTO]?
        var includeWorkoutRoutes: Bool?
        var includeMetadata: Bool?
    }

    struct LegacyDestinationDTO: Codable {
        let id: UUID?
        var type: String?
        var name: String?
        var isEnabled: Bool?
        var configuration: LegacyDestinationConfigDTO?
    }

    struct LegacyDestinationConfigDTO: Codable {
        var folderPath: String?
        var apiURL: String?
        var httpMethod: String?
        var headers: [String: String]?
        var authentication: String?
        var brokerURL: String?
        var port: Int?
        var topic: String?
        var username: String?
        var password: String?
        var homeAssistantURL: String?
        var homeAssistantToken: String?
        var entityId: String?
        var accessToken: String?
        var refreshToken: String?
    }

    struct LegacyScheduleDTO: Codable {
        var frequency: String?
        var hour: Int?
        var minute: Int?
        var daysOfWeek: Set<Int>?
        var dayOfMonth: Int?
    }

    // Exposed for tests
    func convertForTesting(_ legacy: LegacyAutomationDTO) async throws -> (Automation, [(SecretReference, String)], [String]) {
        try await convert(legacy)
    }

    private func convert(_ legacy: LegacyAutomationDTO) async throws -> (Automation, [(SecretReference, String)], [String]) {
        var secretPairs: [(SecretReference, String)] = []
        var destinations: [ExportDestination] = []
        var warnings: [String] = []

        for dest in legacy.exportConfiguration.destinations ?? [] {
            let (mapped, secrets, destWarnings) = try mapDestination(dest, iCloudFolder: legacy.iCloudFolderPath)
            destinations.append(mapped)
            secretPairs.append(contentsOf: secrets)
            warnings.append(contentsOf: destWarnings)
        }

        if destinations.isEmpty {
            destinations = [ExportDestination.defaultLocal()]
        }

        let format = mapFormat(legacy.exportConfiguration.format)
        let range = mapRange(
            legacy.exportConfiguration.dateRange,
            start: legacy.exportConfiguration.customStartDate,
            end: legacy.exportConfiguration.customEndDate
        )
        let selection: ExportRequest.Selection
        if legacy.exportConfiguration.exportAllAvailableTypes == true
            || (legacy.exportConfiguration.dataTypes ?? []).isEmpty {
            selection = .allDetected
        } else {
            selection = .explicit(legacy.exportConfiguration.dataTypes ?? [])
        }

        let schedule = AutomationSchedule(
            frequency: mapFrequency(legacy.schedule.frequency),
            hour: legacy.schedule.hour ?? 2,
            minute: legacy.schedule.minute ?? 0,
            daysOfWeek: legacy.schedule.daysOfWeek ?? [1, 2, 3, 4, 5, 6, 7],
            dayOfMonth: legacy.schedule.dayOfMonth
        )

        // Preserve explicit legacy route preference; default OFF when absent.
        let includeRoutes = legacy.exportConfiguration.includeWorkoutRoutes ?? false

        let automation = Automation(
            id: legacy.id,
            name: legacy.name,
            exportConfig: AutomationExportConfig(
                selection: selection,
                range: range,
                format: format,
                destinations: destinations,
                includeMetadata: legacy.exportConfiguration.includeMetadata ?? false,
                includeWorkoutRoutes: includeRoutes,
                includeECGWaveforms: false
            ),
            schedule: schedule,
            isEnabled: legacy.isEnabled,
            notifyOnCompletion: false,
            executionStatus: mapStatus(legacy.executionStatus),
            retryCount: legacy.retryCount ?? 0,
            maxRetries: legacy.maxRetries ?? 3,
            lastRun: legacy.lastRun,
            nextEligibleAt: legacy.nextRun,
            runCount: legacy.runCount ?? 0,
            lastError: legacy.lastError,
            createdAt: legacy.createdAt ?? Date(),
            lastModified: legacy.lastModified ?? Date()
        )
        return (automation, secretPairs, warnings)
    }

    private func mapDestination(
        _ dest: LegacyDestinationDTO,
        iCloudFolder: String?
    ) throws -> (ExportDestination, [(SecretReference, String)], [String]) {
        let typeName = dest.type ?? "Local Files"
        let id = dest.id ?? UUID()
        let name = dest.name ?? typeName
        let enabled = dest.isEnabled ?? true
        var secrets: [(SecretReference, String)] = []
        var warnings: [String] = []
        let configDTO = dest.configuration

        let kind: ExportDestinationKind
        let config: DestinationConfig
        var finalEnabled = enabled

        switch typeName {
        case "Local Files", "localFiles":
            kind = .localFiles
            config = .localFiles(folderPath: configDTO?.folderPath)
        case "iCloud Drive", "iCloudDrive":
            kind = .iCloudDrive
            config = .iCloudDrive(folderPath: configDTO?.folderPath ?? iCloudFolder)
        case "REST API", "restAPI":
            kind = .restAPI
            let mapped = try mapRESTConfig(id: id, name: name, configDTO: configDTO)
            config = mapped.config
            secrets.append(contentsOf: mapped.secrets)
            warnings.append(contentsOf: mapped.warnings)
            if mapped.failedSafely {
                finalEnabled = false
            }
        case "Home Assistant", "homeAssistant":
            // Map HA to REST when possible; otherwise disable with warning and preserve token.
            if let url = firstNonEmpty(configDTO?.homeAssistantURL, configDTO?.apiURL),
               let token = firstNonEmpty(configDTO?.homeAssistantToken, configDTO?.accessToken, configDTO?.password) {
                kind = .restAPI
                let ref = SecretReference(id: "dest-\(id.uuidString)")
                secrets.append((ref, token))
                config = .restAPI(
                    endpoint: url,
                    method: .POST,
                    authMode: .bearer,
                    secretRef: ref,
                    apiKeyHeaderName: nil,
                    customHeaders: [:]
                )
                warnings.append("“\(name)” migrated from Home Assistant to REST API (Bearer).")
            } else {
                kind = .homeAssistant
                config = .planned
                finalEnabled = false
                if firstNonEmpty(configDTO?.homeAssistantToken, configDTO?.accessToken, configDTO?.password, configDTO?.refreshToken) != nil {
                    throw MigrationError.unsupportedCredentialedDestination(name)
                }
                warnings.append("“\(name)” migrated disabled — Home Assistant is not implemented.")
            }
        default:
            // Planned / unknown destinations: never silently become enabled Local Files.
            kind = mapPlannedKind(typeName)
            config = .planned
            finalEnabled = false
            if firstNonEmpty(
                configDTO?.accessToken,
                configDTO?.homeAssistantToken,
                configDTO?.password,
                configDTO?.refreshToken
            ) != nil {
                throw MigrationError.unsupportedCredentialedDestination(name)
            }
            warnings.append("“\(name)” (\(typeName)) migrated disabled — destination not implemented.")
        }

        return (
            ExportDestination(id: id, kind: kind, name: name, isEnabled: finalEnabled, config: config),
            secrets,
            warnings
        )
    }

    private struct RESTMapResult {
        var config: DestinationConfig
        var secrets: [(SecretReference, String)]
        var warnings: [String]
        var failedSafely: Bool
    }

    private func mapRESTConfig(id: UUID, name: String, configDTO: LegacyDestinationConfigDTO?) throws -> RESTMapResult {
        var secrets: [(SecretReference, String)] = []
        var warnings: [String] = []
        var failedSafely = false

        let rawHeaders = configDTO?.headers ?? [:]
        let partitioned = SensitiveHeaderDetector.partition(headers: rawHeaders)
        let safeHeaders = partitioned.safe

        // The v2 model supports one Bearer or API-key credential. Refuse any
        // legacy shape that cannot be represented losslessly; leaving the
        // legacy blob is safer than dropping a refresh token, Basic-auth user,
        // or additional secret header.
        if firstNonEmpty(configDTO?.refreshToken) != nil {
            throw MigrationError.unsupportedCredentialedDestination(name)
        }
        if firstNonEmpty(configDTO?.username) != nil {
            throw MigrationError.unsupportedAuthorizationScheme(name)
        }

        let token = firstNonEmpty(
            configDTO?.accessToken,
            configDTO?.homeAssistantToken,
            configDTO?.password
        )
        guard partitioned.sensitive.count <= 1,
              !(token != nil && !partitioned.sensitive.isEmpty) else {
            throw MigrationError.multipleCredentials(name)
        }

        var auth = mapAuth(configDTO?.authentication)
        var secretRef: SecretReference?
        var apiKeyHeaderName: String?

        if let token {
            if auth == .none {
                if configDTO?.homeAssistantToken != nil || configDTO?.accessToken != nil {
                    auth = .bearer
                } else if configDTO?.authentication == "API Key" {
                    auth = .apiKey
                } else {
                    auth = .bearer
                }
            }
            if auth != .none {
                let ref = SecretReference(id: "dest-\(id.uuidString)")
                secretRef = ref
                secrets.append((ref, token))
            }
        }

        if let header = partitioned.sensitive.first {
            let lower = header.name.lowercased()
            let secretValue: String
            let inferredAuth: DestinationAuthMode

            if lower == "authorization" {
                guard header.value.lowercased().hasPrefix("bearer ") else {
                    throw MigrationError.unsupportedAuthorizationScheme(name)
                }
                inferredAuth = .bearer
                secretValue = String(header.value.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if lower == "proxy-authorization" {
                throw MigrationError.unsupportedAuthorizationScheme(name)
            } else {
                inferredAuth = .apiKey
                secretValue = header.value
                apiKeyHeaderName = header.name
            }

            guard auth == .none || auth == inferredAuth else {
                throw MigrationError.multipleCredentials(name)
            }
            auth = inferredAuth
            let ref = SecretReference(id: "dest-\(id.uuidString)")
            secretRef = ref
            secrets.append((ref, secretValue))
            warnings.append("Moved sensitive header “\(header.name)” to Keychain for a REST destination.")
        }

        // If auth requires secret but we have none, fail safely (disable).
        if auth != .none && secretRef == nil {
            failedSafely = true
            warnings.append("REST destination disabled: authentication required but no credential could be migrated safely.")
            auth = .none
        }

        let endpoint = firstNonEmpty(configDTO?.apiURL, configDTO?.homeAssistantURL) ?? ""

        return RESTMapResult(
            config: .restAPI(
                endpoint: endpoint,
                method: mapMethod(configDTO?.httpMethod),
                authMode: auth,
                secretRef: secretRef,
                apiKeyHeaderName: apiKeyHeaderName,
                customHeaders: safeHeaders
            ),
            secrets: secrets,
            warnings: warnings,
            failedSafely: failedSafely
        )
    }

    private func mapPlannedKind(_ typeName: String) -> ExportDestinationKind {
        switch typeName {
        case "Google Drive", "googleDrive": return .googleDrive
        case "Dropbox", "dropbox": return .dropbox
        case "MQTT", "mqtt": return .mqtt
        case "Home Assistant", "homeAssistant": return .homeAssistant
        case "Calendar", "calendar": return .calendar
        default: return .googleDrive // generic planned stand-in; disabled + planned config
        }
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let value, !value.isEmpty { return value }
        }
        return nil
    }

    private func mapFormat(_ raw: String?) -> ExportFormat {
        switch raw {
        case "CSV": return .csv
        case "GPX": return .gpx
        default: return .json
        }
    }

    private func mapRange(_ raw: String?, start: Date?, end: Date?) -> ExportDateRange {
        switch raw {
        case "Today": return .today
        case "Yesterday": return .yesterday
        case "Last 24 Hours": return .last24Hours
        case "This Week": return .thisWeek
        case "Last Week": return .lastWeek
        case "This Month": return .thisMonth
        case "Last Month": return .lastMonth
        case "This Year": return .thisYear
        case "Last Year": return .lastYear
        case "All Time": return .allTime
        case "Custom Range":
            if let start, let end, start < end { return .custom(start: start, end: end) }
            return .last24Hours
        default: return .last24Hours
        }
    }

    private func mapFrequency(_ raw: String?) -> ScheduleFrequency {
        switch raw {
        case "Hourly": return .hourly
        case "Daily": return .daily
        case "Weekly": return .weekly
        case "Monthly": return .monthly
        case "Manual": return .manual
        default: return .daily
        }
    }

    private func mapStatus(_ raw: String?) -> ExecutionStatus {
        switch raw {
        case "Running": return .running
        case "Completed": return .completed
        case "Failed": return .failed
        default: return .pending
        }
    }

    private func mapAuth(_ raw: String?) -> DestinationAuthMode {
        switch raw {
        case "Bearer Token": return .bearer
        case "API Key": return .apiKey
        default: return .none
        }
    }

    private func mapMethod(_ raw: String?) -> HTTPMETHOD {
        switch raw {
        case "PUT": return .PUT
        case "PATCH": return .PATCH
        default: return .POST
        }
    }
}
