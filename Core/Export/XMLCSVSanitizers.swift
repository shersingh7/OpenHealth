import Foundation

public enum CSVSanitizer {
    /// RFC 4180-compatible field escaping.
    /// Spreadsheet formula prefixes (`=`, `+`, `-`, `@`) are left as-is when quoted,
    /// matching the documented choice to preserve raw health values rather than rewrite them.
    public static func escapeField(_ value: String) -> String {
        let needsQuoting =
            value.contains(",") ||
            value.contains("\"") ||
            value.contains("\n") ||
            value.contains("\r")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    public static func joinRow(_ fields: [String]) -> String {
        fields.map(escapeField).joined(separator: ",")
    }
}

public enum XMLSanitizer {
    /// Escape text content for XML 1.0/1.1.
    public static func escapeText(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default:
                // Filter invalid XML 1.0 characters
                if isValidXMLCharacter(scalar) {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result
    }

    /// Escape attribute values (same rules as text for our subset).
    public static func escapeAttribute(_ value: String) -> String {
        escapeText(value)
    }

    private static func isValidXMLCharacter(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        // XML 1.0: #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
        if v == 0x9 || v == 0xA || v == 0xD { return true }
        if v >= 0x20 && v <= 0xD7FF { return true }
        if v >= 0xE000 && v <= 0xFFFD { return true }
        if v >= 0x10000 && v <= 0x10FFFF { return true }
        return false
    }
}
