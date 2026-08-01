import Foundation

public enum GPXExportEncoder {
    public enum Error: Swift.Error, Equatable, LocalizedError {
        case noRouteData
        case writeFailed

        public var errorDescription: String? {
            switch self {
            case .noRouteData: return "No workout route points available for GPX export."
            case .writeFailed: return "Failed to write GPX file."
            }
        }
    }

    /// Encodes workouts that have route points. Fails if no routes exist.
    public static func encode(workouts: [WorkoutRecord], to url: URL, creator: String = "OpenHealth") throws {
        let withRoutes = workouts.filter { ($0.routePoints?.isEmpty == false) }
        guard !withRoutes.isEmpty else { throw Error.noRouteData }

        var xml = ""
        xml += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<gpx version=\"1.1\" creator=\"\(XMLSanitizer.escapeAttribute(creator))\" "
        xml += "xmlns=\"http://www.topografix.com/GPX/1/1\">\n"

        for workout in withRoutes {
            let name = XMLSanitizer.escapeText(workout.activityType)
            xml += "  <trk>\n"
            xml += "    <name>\(name)</name>\n"
            xml += "    <type>\(name)</type>\n"
            xml += "    <trkseg>\n"
            for point in workout.routePoints ?? [] {
                let lat = String(format: "%.8f", point.latitude)
                let lon = String(format: "%.8f", point.longitude)
                xml += "      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">\n"
                if let alt = point.altitude {
                    xml += "        <ele>\(String(format: "%.2f", alt))</ele>\n"
                }
                xml += "        <time>\(ExportDocument.iso8601Fractional.string(from: point.timestamp))</time>\n"
                xml += "      </trkpt>\n"
            }
            xml += "    </trkseg>\n"
            xml += "  </trk>\n"
        }

        xml += "</gpx>\n"

        guard let data = xml.data(using: .utf8) else { throw Error.writeFailed }
        try ProtectedFileIO.writeAtomically(data, to: url)
    }
}
