import Foundation

/// Which slice of history the leaderboard totals. Bounds are local calendar
/// days, matching how `daily_scores` rows are keyed.
enum BoardRange: String, CaseIterable, Identifiable {
    case today, week, month, year, all

    var id: String { rawValue }

    /// Short enough for a 320pt popover.
    var label: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .all: return "All"
        }
    }

    /// Week and month run to today rather than covering the whole period —
    /// nobody has tomorrow's minutes yet.
    func bounds(now: Date = Date(), calendar: Calendar = .lockedIn) -> (from: String, to: String) {
        let to = LocalStore.dateKey(now)
        func start(_ unit: Calendar.Component) -> String {
            guard let interval = calendar.dateInterval(of: unit, for: now) else { return to }
            return LocalStore.dateKey(interval.start)
        }
        switch self {
        case .today: return (to, to)
        case .week: return (start(.weekOfYear), to)
        case .month: return (start(.month), to)
        case .year: return (start(.year), to)
        // Earlier than any Mac could have recorded, so "all" needs no
        // special-casing on the server.
        case .all: return ("2000-01-01", to)
        }
    }
}
