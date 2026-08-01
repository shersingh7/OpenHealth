import SwiftUI

struct ExportResultView: View {
    let report: ExportReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OHStatusBadge(title: outcomeTitle, kind: outcomeKind)
                    LabeledContent("Records") {
                        Text("\(report.serializedRecordCount)")
                            .font(.body.monospacedDigit())
                    }
                    LabeledContent("Duration") {
                        Text(durationText)
                    }
                }

                if !report.destinationResults.isEmpty {
                    Section("Destinations") {
                        ForEach(report.destinationResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(result.destinationName)
                                    Spacer()
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(result.success ? Color.green : Color.red)
                                }
                                if let err = result.errorDescription {
                                    Text(err).font(.caption).foregroundStyle(.red)
                                }
                                if let path = result.artifactURLString, result.success {
                                    Text(path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                if !report.warnings.isEmpty {
                    Section("Warnings") {
                        ForEach(report.warnings) { warning in
                            VStack(alignment: .leading) {
                                Text(warning.code).font(.caption.weight(.semibold))
                                Text(warning.message).font(.footnote)
                                if let metric = warning.metricID {
                                    Text(metric).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let url = report.artifactURL, FileManager.default.fileExists(atPath: url.path) {
                    Section {
                        ShareLink(item: url) {
                            Label("Share export file", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Export Result")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("oh.export.result.done")
                }
            }
        }
    }

    private var outcomeTitle: String {
        switch report.outcome {
        case .completeSuccess: return "Complete success"
        case .partialSuccess: return "Partial success"
        case .failure: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private var outcomeKind: OHStatusKind {
        switch report.outcome {
        case .completeSuccess: return .success
        case .partialSuccess: return .partial
        case .failure: return .error
        case .cancelled: return .neutral
        }
    }

    private var durationText: String {
        let seconds = report.completedAt.timeIntervalSince(report.startedAt)
        return String(format: "%.1fs", seconds)
    }
}
