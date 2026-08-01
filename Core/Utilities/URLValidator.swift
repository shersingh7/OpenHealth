import Foundation

public enum URLValidator {

    public enum Error: Swift.Error, Equatable, LocalizedError {
        case empty
        case malformed
        case unsupportedScheme(String)
        case loopbackHTTPNotAllowed
        case missingHost

        public var errorDescription: String? {
            switch self {
            case .empty: return "URL must not be empty."
            case .malformed: return "URL is malformed."
            case .unsupportedScheme(let s): return "Unsupported URL scheme: \(s)."
            case .loopbackHTTPNotAllowed: return "HTTP is only allowed for loopback hosts in debug builds when explicitly enabled."
            case .missingHost: return "URL must include a host."
            }
        }
    }

    /// Validate an export destination URL.
    /// - Parameters:
    ///   - string: User-entered URL string.
    ///   - allowLoopbackHTTP: When true, permits `http://` only for loopback hosts (127.0.0.1, localhost, ::1).
    public static func validateHTTPSEndpoint(
        _ string: String,
        allowLoopbackHTTP: Bool = false
    ) throws -> URL {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Error.empty }

        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            throw Error.malformed
        }

        guard let host = url.host, !host.isEmpty else {
            throw Error.missingHost
        }

        switch scheme {
        case "https":
            return url
        case "http":
            guard allowLoopbackHTTP, isLoopback(host) else {
                throw Error.loopbackHTTPNotAllowed
            }
            return url
        default:
            throw Error.unsupportedScheme(scheme)
        }
    }

    public static func isLoopback(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == "localhost" || h == "127.0.0.1" || h == "::1" || h == "[::1]"
    }

    /// Reserved header names that must not be overridden via custom headers.
    public static let reservedHeaderNames: Set<String> = [
        "host", "content-length", "authorization", "content-type",
        "x-openhealth-credentialed-request"
    ]

    /// Validates an HTTP header name (RFC 7230 token rules, practical subset).
    public static func validateHeaderName(_ name: String, allowReserved: Bool = false) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HeaderError.invalidName(name) }
        let lower = trimmed.lowercased()
        if !allowReserved, reservedHeaderNames.contains(lower) {
            throw HeaderError.reserved(trimmed)
        }
        // Token characters: alphanumerics and !#$%&'*+-.^_`|~
        for scalar in trimmed.unicodeScalars {
            let isAlphaNum = CharacterSet.alphanumerics.contains(scalar)
            let allowedExtras = CharacterSet(charactersIn: "!#$%&'*+-.^_`|~")
            if !isAlphaNum && !allowedExtras.contains(scalar) {
                throw HeaderError.invalidName(trimmed)
            }
        }
        if trimmed.contains(where: { $0 == " " || $0 == "\n" || $0 == "\r" || $0 == ":" }) {
            throw HeaderError.invalidName(trimmed)
        }
    }

    public static func validateCustomHeaders(_ headers: [String: String]) throws {
        for key in headers.keys {
            try validateHeaderName(key, allowReserved: false)
        }
    }

    /// API key header names use the same token rules as custom headers (not reserved list for Authorization).
    public static func validateAPIKeyHeaderName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HeaderError.invalidName(name) }
        // Disallow overriding reserved transport headers
        let lower = trimmed.lowercased()
        if reservedHeaderNames.contains(lower) {
            throw HeaderError.reserved(trimmed)
        }
        try validateHeaderName(trimmed, allowReserved: false)
    }

    public enum HeaderError: Swift.Error, Equatable, LocalizedError {
        case reserved(String)
        case invalidName(String)

        public var errorDescription: String? {
            switch self {
            case .reserved(let n): return "Header '\(n)' is reserved and cannot be set as a custom header."
            case .invalidName(let n): return "Invalid header name: '\(n)'."
            }
        }
    }
}
