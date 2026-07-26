import Foundation

/// Daily locked-in totals in UserDefaults, keyed by local date "yyyy-MM-dd".
/// The day rolls over naturally because every write targets todayKey().
struct LocalStore {
    static let shared = LocalStore()
    private let defaults = UserDefaults.standard
    private let totalsKey = "dailyTotals"

    static func dateKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }

    private func totals() -> [String: Int] {
        defaults.dictionary(forKey: totalsKey) as? [String: Int] ?? [:]
    }

    func todaySeconds() -> Int {
        totals()[Self.dateKey()] ?? 0
    }

    func addToToday(seconds: Int) -> Int {
        var t = totals()
        let key = Self.dateKey()
        let newValue = (t[key] ?? 0) + seconds
        t[key] = newValue
        defaults.set(t, forKey: totalsKey)
        return newValue
    }

    /// Consecutive local days (ending today or yesterday) with >= 30 min locked in.
    /// Today counts toward the streak once it crosses the floor, but an
    /// unfinished today doesn't break yesterday's run.
    func streakDays(floorSeconds: Int = 30 * 60) -> Int {
        let t = totals()
        var streak = 0
        var day = Date()
        let cal = Calendar.current
        if (t[Self.dateKey(day)] ?? 0) >= floorSeconds {
            streak += 1
        }
        // Walk backwards from yesterday.
        while true {
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
            if (t[Self.dateKey(day)] ?? 0) >= floorSeconds {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}
