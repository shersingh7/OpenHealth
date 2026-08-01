import Foundation

/// Multi-section CSV. Each section is a separate table with a header comment line.
public enum CSVExportEncoder {
    public enum Error: Swift.Error, LocalizedError {
        case writeFailed

        public var errorDescription: String? { "Failed to write CSV file." }
    }

    public static func encode(_ document: ExportDocument, to url: URL) throws {
        var lines: [String] = []
        lines.append("# OpenHealth Export schemaVersion=\(document.schemaVersion) exportID=\(document.exportID.uuidString)")
        lines.append("# generatedAt=\(ExportDocument.iso8601Fractional.string(from: document.generatedAt))")
        lines.append("# totalRecords=\(document.totalRecords)")
        lines.append("")

        if !document.quantityRecords.isEmpty {
            lines.append("# SECTION: quantity")
            lines.append(CSVSanitizer.joinRow([
                "id", "metricID", "value", "unit", "startDate", "endDate", "sourceName", "sourceBundleID"
            ]))
            for r in document.quantityRecords {
                lines.append(CSVSanitizer.joinRow([
                    r.id.uuidString,
                    r.metricID,
                    String(r.value),
                    r.unit,
                    ExportDocument.iso8601Fractional.string(from: r.startDate),
                    ExportDocument.iso8601Fractional.string(from: r.endDate),
                    r.sourceName ?? "",
                    r.sourceBundleID ?? ""
                ]))
            }
            lines.append("")
        }

        if !document.categoryRecords.isEmpty {
            lines.append("# SECTION: category")
            lines.append(CSVSanitizer.joinRow([
                "id", "metricID", "value", "valueLabel", "startDate", "endDate", "sourceName", "sourceBundleID"
            ]))
            for r in document.categoryRecords {
                lines.append(CSVSanitizer.joinRow([
                    r.id.uuidString,
                    r.metricID,
                    String(r.value),
                    r.valueLabel ?? "",
                    ExportDocument.iso8601Fractional.string(from: r.startDate),
                    ExportDocument.iso8601Fractional.string(from: r.endDate),
                    r.sourceName ?? "",
                    r.sourceBundleID ?? ""
                ]))
            }
            lines.append("")
        }

        if !document.workouts.isEmpty {
            lines.append("# SECTION: workouts")
            lines.append(CSVSanitizer.joinRow([
                "id", "activityType", "activityTypeRaw", "startDate", "endDate", "durationSeconds",
                "totalEnergyBurnedKilocalories", "totalDistanceMeters", "routePointCount", "sourceName"
            ]))
            for w in document.workouts {
                lines.append(CSVSanitizer.joinRow([
                    w.id.uuidString,
                    w.activityType,
                    String(w.activityTypeRaw),
                    ExportDocument.iso8601Fractional.string(from: w.startDate),
                    ExportDocument.iso8601Fractional.string(from: w.endDate),
                    String(w.duration),
                    w.totalEnergyBurnedKilocalories.map { String($0) } ?? "",
                    w.totalDistanceMeters.map { String($0) } ?? "",
                    String(w.routePoints?.count ?? 0),
                    w.sourceName ?? ""
                ]))
            }
            lines.append("")
        }

        if !document.electrocardiograms.isEmpty {
            lines.append("# SECTION: electrocardiograms")
            lines.append(CSVSanitizer.joinRow([
                "id", "startDate", "endDate", "classification", "averageHeartRate", "samplingFrequency", "voltagePointCount"
            ]))
            for e in document.electrocardiograms {
                lines.append(CSVSanitizer.joinRow([
                    e.id.uuidString,
                    ExportDocument.iso8601Fractional.string(from: e.startDate),
                    ExportDocument.iso8601Fractional.string(from: e.endDate),
                    e.classification ?? "",
                    e.averageHeartRate.map { String($0) } ?? "",
                    e.samplingFrequency.map { String($0) } ?? "",
                    String(e.voltagePoints?.count ?? 0)
                ]))
            }
            lines.append("")
        }

        if !document.activitySummaries.isEmpty {
            lines.append("# SECTION: activitySummaries")
            lines.append(CSVSanitizer.joinRow([
                "id", "date", "activeEnergyBurned", "activeEnergyBurnedGoal",
                "appleExerciseTime", "appleExerciseTimeGoal", "appleStandHours", "appleStandHoursGoal"
            ]))
            for a in document.activitySummaries {
                lines.append(CSVSanitizer.joinRow([
                    a.id.uuidString,
                    ExportDocument.iso8601Fractional.string(from: a.date),
                    String(a.activeEnergyBurned),
                    String(a.activeEnergyBurnedGoal),
                    String(a.appleExerciseTime),
                    String(a.appleExerciseTimeGoal),
                    String(a.appleStandHours),
                    String(a.appleStandHoursGoal)
                ]))
            }
            lines.append("")
        }

        if !document.warnings.isEmpty {
            lines.append("# SECTION: warnings")
            lines.append(CSVSanitizer.joinRow(["code", "message", "metricID"]))
            for w in document.warnings {
                lines.append(CSVSanitizer.joinRow([w.code, w.message, w.metricID ?? ""]))
            }
        }

        let content = lines.joined(separator: "\n")
        guard let data = content.data(using: .utf8) else { throw Error.writeFailed }
        try ProtectedFileIO.writeAtomically(data, to: url)
    }
}
