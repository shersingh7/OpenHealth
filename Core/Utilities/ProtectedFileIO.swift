import Foundation

/// Shared file protection helpers.
/// Uses complete protection until first user authentication so best-effort background work
/// can read/write after first unlock, without leaving health-related files unprotected at rest
/// before first unlock.
public enum ProtectedFileIO {
    /// Atomic write with file protection suitable for automation/history and export artifacts.
    public static func writeAtomically(_ data: Data, to url: URL) throws {
        let temp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        // completeFileProtectionUntilFirstUserAuthentication ≈ NSFileProtectionCompleteUntilFirstUserAuthentication
        try data.write(to: temp, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            _ = try fm.replaceItemAt(url, withItemAt: temp)
        } else {
            try fm.moveItem(at: temp, to: url)
        }
        applyProtection(to: url)
    }

    public static func applyProtection(to url: URL) {
        let attrs: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: url.path)
    }
}
