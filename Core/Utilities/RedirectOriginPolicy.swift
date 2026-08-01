import Foundation

/// Pure redirect policy for REST uploads. Never logs URLs.
public enum RedirectOriginPolicy {

    /// Whether a redirect should be followed.
    /// - Rejects HTTP (including HTTPS→HTTP downgrade).
    /// - When credentials are attached, rejects cross-host / cross-origin redirects.
    public static func shouldAllowRedirect(
        originalURL: URL?,
        redirectURL: URL?,
        credentialsAttached: Bool
    ) -> Bool {
        guard let redirectURL, let scheme = redirectURL.scheme?.lowercased() else {
            return false
        }
        if scheme != "https" && scheme != "http" {
            return false
        }
        // Never follow cleartext redirects (and reject non-loopback HTTP entirely at higher layers).
        if scheme == "http" {
            return false
        }
        guard credentialsAttached else {
            return true
        }
        guard let originalURL else {
            return false
        }
        return isSameOrigin(originalURL, redirectURL)
    }

    public static func isSameOrigin(_ a: URL, _ b: URL) -> Bool {
        let schemeA = a.scheme?.lowercased() ?? ""
        let schemeB = b.scheme?.lowercased() ?? ""
        guard schemeA == schemeB else { return false }

        let hostA = (a.host ?? "").lowercased()
        let hostB = (b.host ?? "").lowercased()
        guard !hostA.isEmpty, hostA == hostB else { return false }

        let portA = a.port ?? defaultPort(for: schemeA)
        let portB = b.port ?? defaultPort(for: schemeB)
        return portA == portB
    }

    public static func requestCarriesCredentials(_ request: URLRequest?) -> Bool {
        guard let request else { return false }
        // RESTDestination adds this nonsecret marker whenever auth is configured.
        // It makes arbitrary API-key header names safe without guessing whether
        // a user-chosen header such as "X-Custom" contains credentials.
        if request.value(forHTTPHeaderField: "X-OpenHealth-Credentialed-Request") == "1" {
            return true
        }
        if request.value(forHTTPHeaderField: "Authorization") != nil {
            return true
        }
        // Common API-key style headers (case-insensitive via URLRequest helpers).
        if request.value(forHTTPHeaderField: "X-API-Key") != nil {
            return true
        }
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                let lower = key.lowercased()
                if lower == "authorization" || lower.contains("api-key") || lower.contains("apikey") {
                    if !value.isEmpty { return true }
                }
            }
        }
        if request.url?.user != nil || request.url?.password != nil {
            return true
        }
        return false
    }

    private static func defaultPort(for scheme: String) -> Int {
        switch scheme {
        case "https": return 443
        case "http": return 80
        default: return -1
        }
    }
}
