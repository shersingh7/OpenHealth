import Foundation

/// Hardened REST upload destination. Secrets loaded from Keychain via SecretStore.
struct RESTDestination: ExportDestinationClient {
    private let secretStore: any SecretStore
    private let session: URLSession
    private let allowLoopbackHTTP: Bool

    init(
        secretStore: any SecretStore,
        session: URLSession? = nil,
        allowLoopbackHTTP: Bool = false
    ) {
        self.secretStore = secretStore
        self.allowLoopbackHTTP = allowLoopbackHTTP
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 300
            config.httpCookieAcceptPolicy = .never
            config.httpShouldSetCookies = false
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            let delegate = RedirectPolicyDelegate()
            self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        }
    }

    func deliver(_ request: DestinationDeliveryRequest) async throws -> DestinationDeliveryOutcome {
        guard case .restAPI(let endpoint, let method, let authMode, let secretRef, let apiKeyHeaderName, let customHeaders) = request.destination.config else {
            return DestinationDeliveryOutcome(success: false, errorDescription: "Invalid REST destination configuration.")
        }

        let url: URL
        do {
            url = try URLValidator.validateHTTPSEndpoint(endpoint, allowLoopbackHTTP: allowLoopbackHTTP)
            try URLValidator.validateCustomHeaders(customHeaders)
            if authMode == .apiKey {
                let header = (apiKeyHeaderName?.isEmpty == false) ? apiKeyHeaderName! : "X-API-Key"
                try URLValidator.validateAPIKeyHeaderName(header)
            }
        } catch {
            return DestinationDeliveryOutcome(success: false, errorDescription: error.localizedDescription)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue(request.mimeType, forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(request.filename, forHTTPHeaderField: "X-OpenHealth-Filename")

        for (key, value) in customHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if authMode != .none {
            // Nonsecret marker consumed by RedirectPolicyDelegate. It ensures
            // custom API-key header names still receive same-origin protection.
            urlRequest.setValue("1", forHTTPHeaderField: "X-OpenHealth-Credentialed-Request")
        }

        switch authMode {
        case .none:
            break
        case .bearer:
            guard let secretRef else {
                return DestinationDeliveryOutcome(success: false, errorDescription: "Bearer auth requires a stored secret.")
            }
            let token = try await secretStore.load(reference: secretRef)
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .apiKey:
            guard let secretRef else {
                return DestinationDeliveryOutcome(success: false, errorDescription: "API key auth requires a stored secret.")
            }
            let key = try await secretStore.load(reference: secretRef)
            let header = (apiKeyHeaderName?.isEmpty == false) ? apiKeyHeaderName! : "X-API-Key"
            urlRequest.setValue(key, forHTTPHeaderField: header)
        }

        do {
            let (responseData, response) = try await session.upload(for: urlRequest, fromFile: request.artifactURL)
            guard let http = response as? HTTPURLResponse else {
                return DestinationDeliveryOutcome(success: false, errorDescription: "Invalid HTTP response.")
            }
            let status = http.statusCode
            if (200...299).contains(status) {
                let bytes = try? request.artifactURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
                // Do not persist endpoint URLs in operational history.
                return DestinationDeliveryOutcome(success: true, finalURL: nil, bytesWritten: bytes)
            }
            // Never surface response bodies (may contain sensitive data).
            _ = responseData
            return DestinationDeliveryOutcome(
                success: false,
                errorDescription: "HTTP \(status)"
            )
        } catch {
            AppLogger.export.error("REST delivery failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
            return DestinationDeliveryOutcome(success: false, errorDescription: "Network error")
        }
    }
}
