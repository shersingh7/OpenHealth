import Foundation

/// Detects headers that must never be persisted in JSON automation files.
public enum SensitiveHeaderDetector {

    /// Header names treated as secret-bearing (case-insensitive).
    public static let sensitiveNames: Set<String> = [
        "authorization",
        "proxy-authorization",
        "x-api-key",
        "api-key",
        "apikey",
        "x-auth-token",
        "x-access-token",
        "access-token",
        "x-amz-security-token"
    ]

    public static func isSensitiveHeaderName(_ name: String) -> Bool {
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if sensitiveNames.contains(lower) { return true }
        if lower.contains("api-key") || lower.contains("apikey") { return true }
        if lower.contains("authorization") { return true }
        if lower.hasSuffix("-token") || lower.hasSuffix("_token") { return true }
        return false
    }

    /// Splits headers into safe custom headers and sensitive (name, value) pairs to move to Keychain.
    public static func partition(headers: [String: String]) -> (
        safe: [String: String],
        sensitive: [(name: String, value: String)]
    ) {
        var safe: [String: String] = [:]
        var sensitive: [(String, String)] = []
        for (key, value) in headers {
            if isSensitiveHeaderName(key) {
                if !value.isEmpty {
                    sensitive.append((key, value))
                }
            } else {
                safe[key] = value
            }
        }
        return (safe, sensitive)
    }
}
