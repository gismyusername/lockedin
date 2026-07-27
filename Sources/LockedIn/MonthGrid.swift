import Foundation

/// Layout for one month of a calendar grid: how many blank cells before the
/// 1st, and how many days the month has. Kept free of SwiftUI so the
/// off-by-one risks (week start, leap years) can be tested directly.
struct MonthGrid: Equatable {
    let year: Int
    let month: Int
    let leadingBlanks: Int
    let dayCount: Int

    /// Weekday symbols ordered to match `leadingBlanks`, e.g. ["M","T",...]
    /// for a Monday-first locale.
    static func weekdaySymbols(firstWeekday: Int, locale: Locale = .current) -> [String] {
        let f = DateFormatter()
        f.locale = locale
        let symbols = f.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let shift = firstWeekday - 1
        return (0..<7).map { symbols[($0 + shift) % 7] }
    }

    static func make(anchor: Date, calendar: Calendar) -> MonthGrid {
        let comps = calendar.dateComponents([.year, .month], from: anchor)
        let first = calendar.date(from: comps) ?? anchor
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        // weekday is 1...7 with 1 = Sunday, independent of firstWeekday.
        let weekday = calendar.component(.weekday, from: first)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        return MonthGrid(year: comps.year ?? 0, month: comps.month ?? 0,
                         leadingBlanks: blanks, dayCount: dayCount)
    }

    func date(day: Int, calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

extension Calendar {
    /// Gregorian math in the user's timezone, but honouring their week start
    /// (Monday in France, Sunday in the US) for display.
    static var lockedIn: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        c.firstWeekday = Calendar.current.firstWeekday
        return c
    }
}
