import Foundation

// This runs as a bare binary, so UserDefaults.standard resolves to the
// "storetest" domain, never the app's. Clear it so runs are idempotent.
UserDefaults.standard.removeObject(forKey: "dailyTotals")
var pass = 0, fail = 0
func check(_ label: String, _ got: String, _ want: String) {
    if got == want { pass += 1; print("  PASS  \(label): \(got)") }
    else { fail += 1; print("  FAIL  \(label): got \(got), want \(want)") }
}

let s = LocalStore.shared

// 1) A day's seconds accumulate under its own key.
_ = s.addToToday(seconds: 300, key: "2026-07-26")
_ = s.addToToday(seconds: 200, key: "2026-07-26")
check("day A accumulates", "\(s.todaySeconds(key: "2026-07-26"))", "500")

// 2) THE ROLLOVER: the next day starts from zero, untouched by day A.
check("day B starts at zero", "\(s.todaySeconds(key: "2026-07-27"))", "0")
_ = s.addToToday(seconds: 60, key: "2026-07-27")
check("day B counts on its own", "\(s.todaySeconds(key: "2026-07-27"))", "60")
check("day A history preserved", "\(s.todaySeconds(key: "2026-07-26"))", "500")

// 3) dateKey is Gregorian + ASCII regardless of system locale.
check("dateKey format", LocalStore.dateKey(Date(timeIntervalSince1970: 1785110400)),
      { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current; return f.string(from: Date(timeIntervalSince1970: 1785110400)) }())

// 4) Streak: needs >= 30min/day, consecutive, stops at a gap.
UserDefaults.standard.removeObject(forKey: "dailyTotals")
let cal = Calendar(identifier: .gregorian)
func key(daysAgo: Int) -> String {
    LocalStore.dateKey(cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
}
_ = s.addToToday(seconds: 1800, key: key(daysAgo: 0))
_ = s.addToToday(seconds: 2000, key: key(daysAgo: 1))
_ = s.addToToday(seconds: 1799, key: key(daysAgo: 2))   // one second short -> gap
_ = s.addToToday(seconds: 5000, key: key(daysAgo: 3))
check("streak stops at sub-30min day", "\(s.streakDays())", "2")


// ---- MonthGrid layout ----
func gridFor(_ y: Int, _ m: Int, firstWeekday: Int) -> MonthGrid {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Bangkok")!
    c.firstWeekday = firstWeekday
    let anchor = c.date(from: DateComponents(year: y, month: m, day: 15))!
    return MonthGrid.make(anchor: anchor, calendar: c)
}
// July 2026 starts on a Wednesday.
let julSun = gridFor(2026, 7, firstWeekday: 1)   // Sunday-first (US)
let julMon = gridFor(2026, 7, firstWeekday: 2)   // Monday-first (FR)
check("July 2026 days", "\(julSun.dayCount)", "31")
check("July 2026 blanks, Sunday-first", "\(julSun.leadingBlanks)", "3")
check("July 2026 blanks, Monday-first", "\(julMon.leadingBlanks)", "2")
// Feb 2028 is a leap February starting on a Tuesday.
let feb28 = gridFor(2028, 2, firstWeekday: 2)
check("Feb 2028 leap day count", "\(feb28.dayCount)", "29")
check("Feb 2028 blanks, Monday-first", "\(feb28.leadingBlanks)", "1")
check("Feb 2026 non-leap", "\(gridFor(2026, 2, firstWeekday: 2).dayCount)", "28")
// Weekday symbols must rotate with the week start.
let symsSun = MonthGrid.weekdaySymbols(firstWeekday: 1, locale: Locale(identifier: "en_US"))
let symsMon = MonthGrid.weekdaySymbols(firstWeekday: 2, locale: Locale(identifier: "en_US"))
check("Sunday-first symbols start", symsSun.first ?? "", "S")
check("Monday-first symbols start", symsMon.first ?? "", "M")
check("symbol count", "\(symsMon.count)", "7")

UserDefaults.standard.removeObject(forKey: "dailyTotals")
print(fail == 0 ? "\nALL \(pass) CHECKS PASSED" : "\n\(fail) FAILED, \(pass) passed")
exit(fail == 0 ? 0 : 1)
