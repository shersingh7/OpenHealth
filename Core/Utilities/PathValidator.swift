import Foundation

public enum PathValidator {

    public enum Error: Swift.Error, Equatable, LocalizedError {
        case empty
        case absolutePath
        case parentTraversal
        case emptyComponent
        case controlCharacter
        case separatorInComponent

        public var errorDescription: String? {
            switch self {
            case .empty: return "Path must not be empty."
            case .absolutePath: return "Absolute paths are not allowed."
            case .parentTraversal: return "Parent directory segments ('..') are not allowed."
            case .emptyComponent: return "Empty path components are not allowed."
            case .controlCharacter: return "Control characters are not allowed in paths."
            case .separatorInComponent: return "Path separators inside a component are not allowed."
            }
        }
    }

    /// Normalize a relative folder path for Application Support / iCloud destinations.
    /// Rejects absolute paths, `..`, empty components, and control characters.
    public static func validateRelativeFolder(_ path: String) throws -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Error.empty }

        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            throw Error.absolutePath
        }

        // Reject Windows-style absolute paths
        if trimmed.count >= 2, trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)] == ":" {
            throw Error.absolutePath
        }

        let rawComponents = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        var normalized: [String] = []

        for component in rawComponents {
            if component.isEmpty {
                // Collapse repeated separators by skipping empty middle components
                continue
            }
            if component == "." {
                continue
            }
            if component == ".." {
                throw Error.parentTraversal
            }
            if component.contains("\0") || component.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
                throw Error.controlCharacter
            }
            if component.contains("\\") {
                throw Error.separatorInComponent
            }
            normalized.append(component)
        }

        guard !normalized.isEmpty else { throw Error.empty }
        return normalized.joined(separator: "/")
    }

    /// Sanitize a single filename component (no directories).
    public static func sanitizeFilenameComponent(_ name: String, maxLength: Int = 80) -> String {
        var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/\\:\0")
            .union(.controlCharacters)
            .union(.newlines)
        result = result.unicodeScalars.map { invalid.contains($0) ? "_" : Character($0) }.map(String.init).joined()
        if result.isEmpty { result = "export" }
        if result.count > maxLength {
            result = String(result.prefix(maxLength))
        }
        return result
    }
}
