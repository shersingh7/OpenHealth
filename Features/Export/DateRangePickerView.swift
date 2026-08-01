import SwiftUI

struct DateRangePickerView: View {
    @Binding var range: ExportDateRange
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEnd = Date()

    private let presets: [(String, ExportDateRange)] = [
        ("Today", .today),
        ("Yesterday", .yesterday),
        ("Last 24 Hours", .last24Hours),
        ("This Week", .thisWeek),
        ("Last Week", .lastWeek),
        ("This Month", .thisMonth),
        ("Last Month", .lastMonth),
        ("This Year", .thisYear),
        ("Last Year", .lastYear),
        ("All Time", .allTime)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
            ForEach(presets, id: \.0) { title, value in
                Button {
                    range = value
                } label: {
                    HStack {
                        Text(title)
                        Spacer()
                        if isSelected(value) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OHTheme.primaryAction)
                        }
                    }
                    .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button {
                range = .custom(start: customStart, end: customEnd)
            } label: {
                HStack {
                    Text("Custom Range")
                    Spacer()
                    if isCustom {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(OHTheme.primaryAction)
                    }
                }
            }
            .buttonStyle(.plain)

            if isCustom {
                DatePicker("Start", selection: $customStart, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: $customEnd, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: customStart) { _, new in
                        range = .custom(start: new, end: customEnd)
                    }
                    .onChange(of: customEnd) { _, new in
                        range = .custom(start: customStart, end: new)
                    }
            }

            Text("Ranges are start-inclusive and end-exclusive.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            if case .custom(let s, let e) = range {
                customStart = s
                customEnd = e
            }
        }
    }

    private var isCustom: Bool {
        if case .custom = range { return true }
        return false
    }

    private func isSelected(_ value: ExportDateRange) -> Bool {
        switch (range, value) {
        case (.today, .today), (.yesterday, .yesterday), (.last24Hours, .last24Hours),
             (.thisWeek, .thisWeek), (.lastWeek, .lastWeek), (.thisMonth, .thisMonth),
             (.lastMonth, .lastMonth), (.thisYear, .thisYear), (.lastYear, .lastYear),
             (.allTime, .allTime):
            return true
        default:
            return false
        }
    }
}
