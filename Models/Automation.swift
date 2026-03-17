//
//  Automation.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import Foundation

// MARK: - Execution Status

enum ExecutionStatus: String, Codable {
    case pending = "Pending"
    case running = "Running"
    case completed = "Completed"
    case failed = "Failed"
    
    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .running: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "gray"
        case .running: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - Automation

/// Represents a scheduled automation for automatic exports
struct Automation: Identifiable, Codable {
    let id: UUID
    var name: String
    var exportConfiguration: ExportConfiguration
    var schedule: AutomationSchedule
    var isEnabled: Bool
    var executionStatus: ExecutionStatus
    var retryCount: Int
    var maxRetries: Int
    var lastRun: Date?
    var nextRun: Date?
    var runCount: Int
    var lastError: String?
    var createdAt: Date
    var lastModified: Date
    var iCloudFolderPath: String?  // Custom iCloud folder for exports

    init(
        id: UUID = UUID(),
        name: String = "New Automation",
        exportConfiguration: ExportConfiguration = ExportConfiguration(),
        schedule: AutomationSchedule = AutomationSchedule(),
        isEnabled: Bool = true,
        iCloudFolderPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.exportConfiguration = exportConfiguration
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.executionStatus = .pending
        self.retryCount = 0
        self.maxRetries = 3
        self.lastRun = nil
        self.nextRun = schedule.nextRunDate()
        self.runCount = 0
        self.lastError = nil
        self.createdAt = Date()
        self.lastModified = Date()
        self.iCloudFolderPath = iCloudFolderPath
    }

    mutating func markRunning() {
        executionStatus = .running
        lastModified = Date()
    }

    mutating func markCompleted() {
        lastRun = Date()
        runCount += 1
        retryCount = 0
        executionStatus = .completed
        nextRun = schedule.nextRunDate()
        lastError = nil
        lastModified = Date()
    }

    mutating func markFailed(error: String) {
        lastRun = Date()
        lastError = error
        retryCount += 1
        executionStatus = retryCount >= maxRetries ? .failed : .pending
        lastModified = Date()
    }
    
    mutating func resetForRetry() {
        executionStatus = .pending
        lastModified = Date()
    }
}

// MARK: - Automation Schedule

/// Schedule configuration for automations
struct AutomationSchedule: Codable {
    var frequency: ScheduleFrequency
    var hour: Int
    var minute: Int
    var daysOfWeek: Set<Int>  // 1-7 where 1 is Sunday
    var dayOfMonth: Int?  // For monthly schedules

    init(
        frequency: ScheduleFrequency = .daily,
        hour: Int = 8,
        minute: Int = 0,
        daysOfWeek: Set<Int> = [1, 2, 3, 4, 5, 6, 7],
        dayOfMonth: Int? = nil
    ) {
        self.frequency = frequency
        self.hour = hour
        self.minute = minute
        self.daysOfWeek = daysOfWeek
        self.dayOfMonth = dayOfMonth
    }

    func nextRunDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        switch frequency {
        case .hourly:
            // Next hour
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
            components.hour = calendar.component(.hour, from: nextHour)
            components.minute = 0
            return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)

        case .daily:
            // Today or tomorrow at specified time
            if let today = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                if today > now {
                    return today
                }
            }
            // Tomorrow
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(from: DateComponents(
                year: calendar.component(.year, from: tomorrow),
                month: calendar.component(.month, from: tomorrow),
                day: calendar.component(.day, from: tomorrow),
                hour: hour,
                minute: minute
            ))

        case .weekly:
            // Next occurrence on specified days
            for dayOfWeek in daysOfWeek.sorted() {
                components.weekday = dayOfWeek
                if let next = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                    return next
                }
            }
            // If no match this week, find next week
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            components.weekday = daysOfWeek.min() ?? 1
            return calendar.nextDate(after: nextWeek, matching: components, matchingPolicy: .nextTime)

        case .monthly:
            // Next occurrence on specified day of month
            components.day = dayOfMonth ?? 1
            if let next = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                return next
            }
            return nil

        case .manual:
            return nil
        }
    }

    var displayString: String {
        let timeString = String(format: "%02d:%02d", hour, minute)

        switch frequency {
        case .hourly:
            return "Every hour"
        case .daily:
            return "Daily at \(timeString)"
        case .weekly:
            let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let days = daysOfWeek.sorted().compactMap { dayNames[$0 - 1] }
            return "Weekly on \(days.joined(separator: ", ")) at \(timeString)"
        case .monthly:
            return "Monthly on day \(dayOfMonth ?? 1) at \(timeString)"
        case .manual:
            return "Manual only"
        }
    }
}

// MARK: - Schedule Frequency

enum ScheduleFrequency: String, CaseIterable, Identifiable, Codable {
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case manual = "Manual"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .hourly: return "clock.fill"
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .manual: return "hand.raised.fill"
        }
    }
}

// MARK: - Activity Log

/// Log entry for automation runs
struct ActivityLog: Identifiable, Codable {
    let id: UUID
    let automationId: UUID
    let automationName: String
    let timestamp: Date
    let success: Bool
    let recordsExported: Int
    let duration: TimeInterval
    let destination: String
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        automationId: UUID,
        automationName: String,
        success: Bool,
        recordsExported: Int,
        duration: TimeInterval,
        destination: String,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.automationId = automationId
        self.automationName = automationName
        self.timestamp = Date()
        self.success = success
        self.recordsExported = recordsExported
        self.duration = duration
        self.destination = destination
        self.errorMessage = errorMessage
    }
}