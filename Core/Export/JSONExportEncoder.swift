import Foundation

public enum JSONExportEncoder {
    public static func encode(_ document: ExportDocument, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(ExportDocument.iso8601Fractional.string(from: date))
        }
        let data = try encoder.encode(document)
        try ProtectedFileIO.writeAtomically(data, to: url)
    }

    public static func decode(from url: URL) throws -> ExportDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let string = try c.decode(String.self)
            if let d = ExportDocument.iso8601Fractional.date(from: string) {
                return d
            }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let d = fallback.date(from: string) {
                return d
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid ISO-8601 date")
        }
        return try decoder.decode(ExportDocument.self, from: data)
    }

    public static func encodeToData(_ document: ExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(ExportDocument.iso8601Fractional.string(from: date))
        }
        return try encoder.encode(document)
    }
}
