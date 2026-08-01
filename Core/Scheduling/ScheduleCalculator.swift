import Foundation

/// Pure schedule math. Monthly days clamp to the last day of short months.
public enum ScheduleCalculator {

    public enum Error: Swift.Error, Equatable, LocalizedError {
        case emptyWeekdays
        case invalidTime
        case invalidDayOfMonth

        public var errorDescription: String? {
            switch self {
            case .emptyWeekdays: return "Weekly schedules require at least one weekday."
            case .invalidTime: return "Hour must be 0–23 and minute 0–59."
            case .invalidDayOfMonth: return "Day of month must be 1–31."
            }
        }
    }

    public static func validate(_ schedule: AutomationSchedule) throws {
        guard (0...23).contains(schedule.hour), (0...59).contains(schedule.minute) else {
            throw Error.invalidTime
        }
        if schedule.frequency == .weekly, schedule.daysOfWeek.isEmpty {
            throw Error.emptyWeekdays
        }
        if schedule.frequency == .monthly {
            let day = schedule.dayOfMonth ?? 1
            guard (1...31).contains(day) else { throw Error.invalidDayOfMonth }
        }
    }

    /// Next eligible run strictly after `after`.
    public static func nextEligibleDate(
        for schedule: AutomationSchedule,
        after: Date,
        calendar: Calendar
    ) throws -> Date? {
        try validate(schedule)
        let cal = calendar

        switch schedule.frequency {
        case .manual:
            return nil

        case .hourly:
            var comps = cal.dateComponents([.year, .month, .day, .hour], from: after)
            comps.minute = 0
            comps.second = 0
            guard let hourStart = cal.date(from: comps) else { return nil }
            let candidate = cal.date(byAdding: .hour, value: 1, to: hourStart) ?? after.addingTimeInterval(3600)
            return candidate > after ? candidate : cal.date(byAdding: .hour, value: 1, to: candidate)

        case .daily:
            return nextDaily(hour: schedule.hour, minute: schedule.minute, after: after, calendar: cal)

        case .weekly:
            var candidates: [Date] = []
            for weekday in schedule.daysOfWeek {
                if let date = nextWeekday(
                    weekday: weekday,
                    hour: schedule.hour,
                    minute: schedule.minute,
                    after: after,
                    calendar: cal
                ) {
                    candidates.append(date)
                }
            }
            return candidates.min()

        case .monthly:
            return nextMonthly(
                dayOfMonth: schedule.dayOfMonth ?? 1,
                hour: schedule.hour,
                minute: schedule.minute,
                after: after,
                calendar: cal
            )
        }
    }

    /// Failure backoff: exponential-ish delay capped at 6 hours.
    public static func retryDate(
        retryCount: Int,
        after: Date,
        baseDelay: TimeInterval = 300
    ) -> Date {
        let multiplier = pow(2.0, Double(max(0, retryCount - 1)))
        let delay = min(baseDelay * multiplier, 6 * 60 * 60)
        return after.addingTimeInterval(delay)
    }

    // MARK: - Private

    private static func nextDaily(hour: Int, minute: Int, after: Date, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: after)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        guard let todayCandidate = calendar.date(from: comps) else { return nil }
        if todayCandidate > after {
            return todayCandidate
        }
        return calendar.date(byAdding: .day, value: 1, to: todayCandidate)
    }

    private static func nextWeekday(
        weekday: Int,
        hour: Int,
        minute: Int,
        after: Date,
        calendar: Calendar
    ) -> Date? {
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.nextDate(
            after: after,
            matching: comps,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    /// Clamp day-of-month to last day of month when needed (e.g. 31 → 28/29/30).
    private static func nextMonthly(
        dayOfMonth: Int,
        hour: Int,
        minute: Int,
        after: Date,
        calendar: Calendar
    ) -> Date? {
        var cursor = after
        for _ in 0..<14 {
            let year = calendar.component(.year, from: cursor)
            let month = calendar.component(.month, from: cursor)
            guard let range = calendar.range(of: .day, in: .month, for: cursor) else { return nil }
            let clampedDay = min(dayOfMonth, range.count)
            let comps = DateComponents(year: year, month: month, day: clampedDay, hour: hour, minute: minute, second: 0)
            if let candidate = calendar.date(from: comps), candidate > after {
                return candidate
            }
            // Move to first of next month
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: cursor)) else {
                return nil
            }
            var startComps = calendar.dateComponents([.year, .month], from: nextMonth)
            startComps.day = 1
            cursor = calendar.date(from: startComps) ?? nextMonth
        }
        return nil
    }
}
