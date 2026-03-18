//
//  ExportConfiguration.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import Foundation

// MARK: - Export Format

/// Available export formats
enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case csv = "CSV"
    case json = "JSON"
    case gpx = "GPX"

    var id: String { rawValue }

    var fileExtension: String {
        rawValue.lowercased()
    }

    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        case .gpx: return "application/gpx+xml"
        }
    }

    var systemImage: String {
        switch self {
        case .csv: return "doc.text"
        case .json: return "curlybraces"
        case .gpx: return "map"
        }
    }

    var description: String {
        switch self {
        case .csv:
            return "Comma-separated values, ideal for spreadsheets and data analysis"
        case .json:
            return "Structured format with nested data, great for developers and APIs"
        case .gpx:
            return "GPS Exchange Format for workout routes and locations"
        }
    }
}

// MARK: - Date Range

/// Date range options for export
enum DateRangePreset: String, CaseIterable, Identifiable, Codable {
    case today = "Today"
    case yesterday = "Yesterday"
    case last24Hours = "Last 24 Hours"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case lastYear = "Last Year"
    case allTime = "All Time"
    case custom = "Custom Range"

    var id: String { rawValue }

    func dateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)

        case .yesterday:
            let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
            let end = calendar.startOfDay(for: now)
            return (start, end)

        case .last24Hours:
            // Rolling 24-hour window from now
            let end = now
            let start = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
            return (start, end)

        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? now
            return (start, end)

        case .lastWeek:
            let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
            let end = thisWeekStart
            return (start, end)

        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
            return (start, end)

        case .lastMonth:
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            let end = thisMonthStart
            return (start, end)

        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? now
            return (start, end)

        case .lastYear:
            let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let start = calendar.date(byAdding: .year, value: -1, to: thisYearStart) ?? now
            let end = thisYearStart
            return (start, end)

        case .allTime:
            // Use a reasonable start date (iOS release date)
            let start = Date(timeIntervalSince1970: 0)
            let end = now
            return (start, end)

        case .custom:
            // For custom, this will be overridden
            return (now, now)
        }
    }
}

// MARK: - Export Configuration

/// Configuration for an export operation
struct ExportConfiguration: Identifiable, Codable {
    let id: UUID
    var name: String
    var dataTypes: Set<String>  // HealthDataType IDs - empty means export all
    var exportAllAvailableTypes: Bool  // When true, export all available health data types
    var format: ExportFormat
    var dateRange: DateRangePreset
    var customStartDate: Date?
    var customEndDate: Date?
    var destinations: [ExportDestination]
    var includeWorkoutRoutes: Bool
    var includeMetadata: Bool
    var summarizeData: Bool
    var incrementalSince: Date?  // For incremental exports - only export data since this date
    var createdAt: Date
    var lastModified: Date

    init(
        id: UUID = UUID(),
        name: String = "New Export",
        dataTypes: Set<String> = [],
        exportAllAvailableTypes: Bool = false,
        format: ExportFormat = .json,
        dateRange: DateRangePreset = .thisMonth,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil,
        destinations: [ExportDestination] = [],
        includeWorkoutRoutes: Bool = true,
        includeMetadata: Bool = true,
        summarizeData: Bool = false,
        incrementalSince: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.dataTypes = dataTypes
        self.exportAllAvailableTypes = exportAllAvailableTypes
        self.format = format
        self.dateRange = dateRange
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.destinations = destinations
        self.includeWorkoutRoutes = includeWorkoutRoutes
        self.includeMetadata = includeMetadata
        self.summarizeData = summarizeData
        self.incrementalSince = incrementalSince
        self.createdAt = Date()
        self.lastModified = Date()
    }

    var effectiveDateRange: (start: Date, end: Date) {
        if dateRange == .custom, let start = customStartDate, let end = customEndDate {
            return (start, end)
        }
        return dateRange.dateRange()
    }

    func withModified() -> ExportConfiguration {
        var config = self
        config.lastModified = Date()
        return config
    }
}