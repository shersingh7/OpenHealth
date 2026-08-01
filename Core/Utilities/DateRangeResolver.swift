import Foundation

/// Semantics: resolved intervals use **start inclusive, end exclusive**.
public enum DateRangeResolver {

    public enum Error: Swift.Error, Equatable, LocalizedError {
        case customStartMissing
        case customEndMissing
        case startNotBeforeEnd
        case endInFutureBeyondTolerance

        public var errorDescription: String? {
            switch self {
            case .customStartMissing: return "Custom range requires a start date."
            case .customEndMissing: return "Custom range requires an end date."
            case .startNotBeforeEnd: return "Start must be before end."
            case .endInFutureBeyondTolerance: return "End date cannot be far in the future."
            }
        }
    }

    /// Resolve a portable date-range description into a half-open DateInterval.
    /// Uses the provided calendar/time zone rather than device defaults alone.
    public static func resolve(
        _ range: ExportDateRange,
        now: Date,
        calendar: Calendar,
        futureTolerance: TimeInterval = 300
    ) throws -> DateInterval {
        var cal = calendar
        cal.timeZone = calendar.timeZone

        switch range {
        case .today:
            let start = cal.startOfDay(for: now)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)

        case .yesterday:
            let todayStart = cal.startOfDay(for: now)
            let start = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            return DateInterval(start: start, end: todayStart)

        case .last24Hours:
            let start = now.addingTimeInterval(-24 * 60 * 60)
            return DateInterval(start: start, end: now)

        case .thisWeek:
            let start = cal.dateInterval(of: .weekOfYear, for: now)?.start
                ?? cal.startOfDay(for: now)
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)

        case .lastWeek:
            let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start
                ?? cal.startOfDay(for: now)
            let start = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
            return DateInterval(start: start, end: thisWeekStart)

        case .thisMonth:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? cal.startOfDay(for: now)
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)

        case .lastMonth:
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? cal.startOfDay(for: now)
            let start = cal.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart
            return DateInterval(start: start, end: thisMonthStart)

        case .thisYear:
            let start = cal.date(from: cal.dateComponents([.year], from: now)) ?? cal.startOfDay(for: now)
            let end = cal.date(byAdding: .year, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)

        case .lastYear:
            let thisYearStart = cal.date(from: cal.dateComponents([.year], from: now)) ?? cal.startOfDay(for: now)
            let start = cal.date(byAdding: .year, value: -1, to: thisYearStart) ?? thisYearStart
            return DateInterval(start: start, end: thisYearStart)

        case .allTime:
            return DateInterval(start: Date(timeIntervalSince1970: 0), end: now)

        case .custom(let start, let end):
            guard start < end else { throw Error.startNotBeforeEnd }
            if end > now.addingTimeInterval(futureTolerance) {
                throw Error.endInFutureBeyondTolerance
            }
            return DateInterval(start: start, end: end)
        }
    }
}
