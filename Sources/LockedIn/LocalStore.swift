import Foundation

/// Daily locked-in totals in UserDefaults, keyed by local date "yyyy-MM-dd".
/// The day rolls over naturally because every write targets todayKey().
struct LocalStore {
    static let shared = LocalStore()
    private let defaults = UserDefaults.standard
    private let totalsKey = "dailyTotals"

    /// Local calendar day, always Gregorian with ASCII digits. Pinning the
    /// locale and calendar matters: with a Thai locale the same formatter
    /// yields "2569-07-27", Japanese gives "0008-07-27", Arabic gives
    /// Arabic-Indic digits. Any of those would orphan the stored history and
    /// look exactly like the day counter failing to roll over.
    /// `timeZone` exists so callers doing calendar math can format with the
    /// same zone they computed in. Mixing zones here shifts keys by a day.
    static func dateKey(_ date: Date = Date(), timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = timeZone
        return f.string(from: date)
    }

    /// Every day recorded on this Mac, keyed by local `yyyy-MM-dd`.
    func totalsByDay() -> [String: Int] { totals() }

    private func totals() -> [String: Int] {
        defaults.dictionary(forKey: totalsKey) as? [String: Int] ?? [:]
    }

    func todaySeconds(key: String = Self.dateKey()) -> Int {
        totals()[key] ?? 0
    }

    /// `key` is injectable so the day-rollover path can be tested without
    /// waiting for midnight.
    func addToToday(seconds: Int, key: String = Self.dateKey()) -> Int {
        var t = totals()
        let newValue = (t[key] ?? 0) + seconds
        t[key] = newValue
        defaults.set(t, forKey: totalsKey)
        return newValue
    }

    /// Folds server-side history into the local store. Takes the larger value
    /// per day: today's local count is usually ahead of the last heartbeat, and
    /// a wiped-or-new Mac has nothing, so max() restores without ever rolling
    /// a day backwards. Returns how many days changed.
    @discardableResult
    func mergeHistory(_ remote: [String: Int]) -> Int {
        var t = totals()
        var changed = 0
        for (day, seconds) in remote where seconds > (t[day] ?? 0) {
            t[day] = seconds
            changed += 1
        }
        if changed > 0 { defaults.set(t, forKey: totalsKey) }
        return changed
    }

    /// Consecutive local days (ending today or yesterday) with >= 30 min locked in.
    /// Today counts toward the streak once it crosses the floor, but an
    /// unfinished today doesn't break yesterday's run.
    func streakDays(floorSeconds: Int = 30 * 60) -> Int {
        let t = totals()
        var streak = 0
        var day = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
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
