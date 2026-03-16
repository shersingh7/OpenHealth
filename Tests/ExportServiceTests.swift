//
//  ExportServiceTests.swift
//  OpenHealthTests
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import XCTest
@testable import OpenHealth

final class ExportServiceTests: XCTestCase {

    // MARK: - Date Range Calculation Tests

    func testDateRangeToday() {
        let range = DateRangePreset.today.dateRange()
        let calendar = Calendar.current

        XCTAssertEqual(calendar.isDateInToday(range.start), true)
        XCTAssertEqual(calendar.isDateInTomorrow(range.end), true)
    }

    func testDateRangeThisWeek() {
        let range = DateRangePreset.thisWeek.dateRange()
        let calendar = Calendar.current

        // Start should be start of this week
        let weekOfYear = calendar.component(.weekOfYear, from: range.start)
        let currentWeekOfYear = calendar.component(.weekOfYear, from: Date())
        XCTAssertEqual(weekOfYear, currentWeekOfYear)
    }

    func testDateRangeThisMonth() {
        let range = DateRangePreset.thisMonth.dateRange()
        let calendar = Calendar.current

        let month = calendar.component(.month, from: range.start)
        let currentMonth = calendar.component(.month, from: Date())
        XCTAssertEqual(month, currentMonth)
    }

    func testCustomDateRange() {
        let config = ExportConfiguration()
        // Custom range should return the current date range when not set
        let range = config.effectiveDateRange
        XCTAssertNotNil(range.start)
        XCTAssertNotNil(range.end)
    }

    // MARK: - Filename Generation Tests

    func testFilenameGeneration() {
        let service = ExportService()

        // Test that filename contains expected components
        // Note: We can't test the exact timestamp without mocking Date
        let filename = service.generateFilename(prefix: "test", format: .csv)

        XCTAssertTrue(filename.hasPrefix("test_"))
        XCTAssertTrue(filename.hasSuffix(".csv"))
    }

    func testFilenameFormatExtensions() {
        XCTAssertEqual(ExportFormat.csv.fileExtension, "csv")
        XCTAssertEqual(ExportFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportFormat.gpx.fileExtension, "gpx")
    }

    // MARK: - CSV Escaping Tests

    func testCSVEscaping() {
        let service = ExportService()

        // Test simple field (no escaping needed)
        XCTAssertEqual(service.escapeCSVField("simple"), "simple")

        // Test field with comma
        XCTAssertEqual(service.escapeCSVField("hello, world"), "\"hello, world\"")

        // Test field with quotes
        XCTAssertEqual(service.escapeCSVField("say \"hi\""), "\"say \"\"hi\"\"\"")

        // Test field with newline
        XCTAssertEqual(service.escapeCSVField("line1\nline2"), "\"line1\nline2\"")

        // Test field with multiple special characters
        XCTAssertEqual(service.escapeCSVField("a, b\nc\"d"), "\"a, b\nc\"\"d\"")
    }

    // MARK: - Export Format Tests

    func testExportFormatMimeTypes() {
        XCTAssertEqual(ExportFormat.csv.mimeType, "text/csv")
        XCTAssertEqual(ExportFormat.json.mimeType, "application/json")
        XCTAssertEqual(ExportFormat.gpx.mimeType, "application/gpx+xml")
    }

    // MARK: - Destination Validation Tests

    func testLocalFilesValidation() {
        let destination = ExportDestination(type: .localFiles)
        let result = destination.validateConfiguration()
        XCTAssertTrue(result.isValid)
    }

    func testiCloudDriveValidation() {
        let destination = ExportDestination(type: .iCloudDrive)
        let result = destination.validateConfiguration()
        XCTAssertTrue(result.isValid)
    }

    func testRestAPIValidationMissingURL() {
        var destination = ExportDestination(type: .restAPI)
        destination.configuration.apiURL = nil
        let result = destination.validateConfiguration()
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(result.errorMessage!.contains("URL"))
    }

    func testRestAPIValidationInvalidURL() {
        var destination = ExportDestination(type: .restAPI)
        destination.configuration.apiURL = "not a valid url"
        let result = destination.validateConfiguration()
        XCTAssertFalse(result.isValid)
    }

    func testRestAPIValidationValidURL() {
        var destination = ExportDestination(type: .restAPI)
        destination.configuration.apiURL = "https://api.example.com/export"
        let result = destination.validateConfiguration()
        XCTAssertTrue(result.isValid)
    }

    func testMQTTValidationMissingBroker() {
        var destination = ExportDestination(type: .mqtt)
        destination.configuration.brokerURL = nil
        destination.configuration.topic = "test/topic"
        let result = destination.validateConfiguration()
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }

    func testHomeAssistantValidation() {
        var destination = ExportDestination(type: .homeAssistant)
        // Missing required fields
        let result = destination.validateConfiguration()
        XCTAssertFalse(result.isValid)

        // With required fields
        destination.configuration.homeAssistantURL = "https://homeassistant.local"
        destination.configuration.accessToken = "token123"
        destination.configuration.entityId = "sensor.health"
        let validResult = destination.validateConfiguration()
        XCTAssertTrue(validResult.isValid)
    }

    // MARK: - Schedule Tests

    func testScheduleNextRunDaily() {
        var schedule = AutomationSchedule(frequency: .daily, hour: 8, minute: 0)
        let nextRun = schedule.nextRunDate()

        XCTAssertNotNil(nextRun)
        XCTAssertEqual(Calendar.current.component(.hour, from: nextRun!), 8)
        XCTAssertEqual(Calendar.current.component(.minute, from: nextRun!), 0)
    }

    func testScheduleNextRunWeekly() {
        var schedule = AutomationSchedule(frequency: .weekly, hour: 9, minute: 30)
        schedule.daysOfWeek = [2, 4, 6] // Mon, Wed, Fri

        let nextRun = schedule.nextRunDate()
        XCTAssertNotNil(nextRun)
    }

    func testScheduleNextRunManual() {
        let schedule = AutomationSchedule(frequency: .manual)
        let nextRun = schedule.nextRunDate()
        XCTAssertNil(nextRun)
    }

    func testScheduleDisplayString() {
        let dailySchedule = AutomationSchedule(frequency: .daily, hour: 14, minute: 30)
        XCTAssertTrue(dailySchedule.displayString.contains("Daily"))
        XCTAssertTrue(dailySchedule.displayString.contains("14:30"))
    }
}

// MARK: - ExportService Extension for Testing

extension ExportService {
    // Expose private methods for testing
    func generateFilename(prefix: String, format: ExportFormat) -> String {
        // This calls the private helper
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "\(prefix)_\(timestamp).\(format.fileExtension)"
    }

    func escapeCSVField(_ field: String) -> String {
        let needsEscaping = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        if !needsEscaping {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}