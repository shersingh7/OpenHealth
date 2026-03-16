//
//  HealthExportWidget.swift
//  OpenHealthWidgets
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct HealthExportEntry: TimelineEntry {
    let date: Date
    let lastExportDate: Date?
    let recordsExported: Int
}

// MARK: - Widget Provider

struct HealthExportProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthExportEntry {
        HealthExportEntry(date: Date(), lastExportDate: nil, recordsExported: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthExportEntry) -> Void) {
        let entry = HealthExportEntry(date: Date(), lastExportDate: nil, recordsExported: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthExportEntry>) -> Void) {
        // Create timeline entries
        let entry = HealthExportEntry(date: Date(), lastExportDate: nil, recordsExported: 0)

        // Schedule next update in 1 hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}

// MARK: - Widget View

struct HealthExportWidgetView: View {
    var entry: HealthExportEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("OpenHealth")
                    .font(.headline)
            }

            if let lastExport = entry.lastExportDate {
                Text("Last export: \(lastExport, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No exports yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.recordsExported > 0 {
                Text("\(entry.recordsExported) records")
                    .font(.title2.bold())
            }
        }
        .padding()
    }
}

// MARK: - Widget Configuration

struct HealthExportWidget: Widget {
    let kind: String = "HealthExportWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthExportProvider()) { entry in
            HealthExportWidgetView(entry: entry)
        }
        .configurationDisplayName("Health Export")
        .description("View your latest health data export status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct HealthWidgetBundle: WidgetBundle {
    var body: some Widget {
        HealthExportWidget()
    }
}

// MARK: - Previews

struct HealthExportWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HealthExportWidgetView(entry: HealthExportEntry(date: Date(), lastExportDate: Date(), recordsExported: 1250))
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            HealthExportWidgetView(entry: HealthExportEntry(date: Date(), lastExportDate: nil, recordsExported: 0))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}