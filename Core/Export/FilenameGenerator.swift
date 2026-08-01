import Foundation

public enum FilenameGenerator {
    /// Deterministic filename using injected clock and fixed calendar/locale.
    public static func generate(
        prefix: String,
        format: ExportFormat,
        now: Date,
        timeZone: TimeZone = TimeZone(identifier: "UTC") ?? .gmt,
        collisionSuffix: String? = nil
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let stamp = String(
            format: "%04d%02d%02d_%02d%02d%02d",
            comps.year ?? 0,
            comps.month ?? 0,
            comps.day ?? 0,
            comps.hour ?? 0,
            comps.minute ?? 0,
            comps.second ?? 0
        )
        let safePrefix = PathValidator.sanitizeFilenameComponent(prefix)
        let suffix = collisionSuffix.map { "_\(PathValidator.sanitizeFilenameComponent($0, maxLength: 12))" } ?? ""
        return "\(safePrefix)_\(stamp)\(suffix).\(format.fileExtension)"
    }
}
