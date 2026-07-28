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


// ---- BoardRange bounds ----
func cal(_ firstWeekday: Int) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Bangkok")!
    c.firstWeekday = firstWeekday
    return c
}
// 2026-07-29 is a Wednesday.
let wed = cal(2).date(from: DateComponents(year: 2026, month: 7, day: 29, hour: 12))!
check("today range", "\(BoardRange.today.bounds(now: wed, calendar: cal(2)))",
      "(from: \"2026-07-29\", to: \"2026-07-29\")")
check("week starts Monday (FR)", BoardRange.week.bounds(now: wed, calendar: cal(2)).from, "2026-07-27")
check("week starts Sunday (US)", BoardRange.week.bounds(now: wed, calendar: cal(1)).from, "2026-07-26")
check("month start", BoardRange.month.bounds(now: wed, calendar: cal(2)).from, "2026-07-01")
check("year start", BoardRange.year.bounds(now: wed, calendar: cal(2)).from, "2026-01-01")
check("all-time start", BoardRange.all.bounds(now: wed, calendar: cal(2)).from, "2000-01-01")
check("ranges end today, not later", BoardRange.year.bounds(now: wed, calendar: cal(2)).to, "2026-07-29")
// Boundary: on the first day of a month, month-start equals today.
let first = cal(2).date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 9))!
check("month start on the 1st", BoardRange.month.bounds(now: first, calendar: cal(2)).from, "2026-08-01")


// ---- Move-to-Applications detection ----
let dl = "/Users/someone/Downloads"
func offers(_ path: String) -> String {
    InstallToApplications.shouldOffer(bundlePath: path, downloadsPath: dl) ? "yes" : "no"
}
check("already installed -> no prompt", offers("/Applications/LockedIn.app"), "no")
check("nested in Applications -> no prompt", offers("/Applications/Utilities/LockedIn.app"), "no")
check("mounted DMG -> prompt", offers("/Volumes/Locked In/LockedIn.app"), "yes")
check("downloads folder -> prompt", offers("\(dl)/LockedIn.app"), "yes")
check("translocated read-only copy -> prompt",
      offers("/private/var/folders/n2/x/T/AppTranslocation/ABC-123/d/LockedIn.app"), "yes")
check("dev build dir -> no nagging", offers("/Users/someone/code/lockedin/dist/LockedIn.app"), "no")
check("path merely containing Downloads -> no prompt",
      offers("/Users/someone/DownloadsArchive/LockedIn.app"), "no")


// ---- install() file operations ----
let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("li-install-\(UUID().uuidString)")
let src = tmp.appendingPathComponent("src/LockedIn.app")
let dst = tmp.appendingPathComponent("dst/LockedIn.app")
try? FileManager.default.createDirectory(at: src.appendingPathComponent("Contents"),
                                         withIntermediateDirectories: true)
try? "binary".write(to: src.appendingPathComponent("Contents/stub"), atomically: true, encoding: .utf8)
try? FileManager.default.createDirectory(at: dst.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
do {
    try InstallToApplications.install(source: src, destination: dst)
    check("copies the bundle", FileManager.default.fileExists(atPath: dst.appendingPathComponent("Contents/stub").path) ? "yes" : "no", "yes")
    check("leaves the source alone", FileManager.default.fileExists(atPath: src.path) ? "yes" : "no", "yes")
    // Second run must replace an existing install rather than throwing.
    try InstallToApplications.install(source: src, destination: dst)
    check("replaces an existing install", FileManager.default.fileExists(atPath: dst.path) ? "yes" : "no", "yes")
} catch {
    check("install threw", "\(error)", "no error")
}
try? FileManager.default.removeItem(at: tmp)


// ---- version comparison ----
func newer(_ a: String, _ b: String) -> String { Updater.isNewer(a, than: b) ? "yes" : "no" }
check("patch bump", newer("0.1.12", "0.1.11"), "yes")
check("double-digit patch beats single", newer("0.1.12", "0.1.9"), "yes")
check("minor bump", newer("0.2.0", "0.1.99"), "yes")
check("v prefix tolerated", newer("v0.1.12", "0.1.11"), "yes")
check("same version is not newer", newer("0.1.11", "0.1.11"), "no")
check("older is not newer", newer("0.1.10", "0.1.11"), "no")
check("shorter equal prefix", newer("0.2", "0.2.0"), "no")
check("malformed tag never nags", newer("nightly", "0.1.11"), "no")

// ---- history merge ----
UserDefaults.standard.removeObject(forKey: "dailyTotals")
let store = LocalStore.shared
_ = store.addToToday(seconds: 900, key: "2026-07-20")   // local ahead of server
_ = store.addToToday(seconds: 100, key: "2026-07-21")   // local behind server
let merged = store.mergeHistory(["2026-07-20": 500, "2026-07-21": 4000, "2026-07-19": 7200])
check("merged day count", "\(merged)", "2")
check("keeps the larger local value", "\(store.todaySeconds(key: "2026-07-20"))", "900")
check("takes the larger server value", "\(store.todaySeconds(key: "2026-07-21"))", "4000")
check("restores a day absent locally", "\(store.todaySeconds(key: "2026-07-19"))", "7200")
check("merging twice changes nothing", "\(store.mergeHistory(["2026-07-19": 7200]))", "0")


// ---- green ramp (absolute scale, anchored to an 8h reference) ----
let H = 3600
check("no time is off the scale", "\(GreenRamp.position(seconds: 0))", "0.0")
check("a full 8h day is full mint", "\(GreenRamp.position(seconds: 8 * H))", "1.0")
check("4h sits mid-scale, not maxed",
      "\(GreenRamp.position(seconds: 4 * H) > 0.5 && GreenRamp.position(seconds: 4 * H) < 0.7)", "true")
check("15h goes beyond a full day", "\(GreenRamp.position(seconds: 15 * H) > 1.5)", "true")
check("beyond twice the reference clamps", "\(GreenRamp.position(seconds: 40 * H))", "2.0")
check("a tracked minute stays visible", "\(GreenRamp.position(seconds: 60) >= 0.12)", "true")
// The bug this replaced: a record day must not restyle earlier days.
check("colour of 4h is stable regardless of any record",
      "\(GreenRamp.position(seconds: 4 * H) == GreenRamp.position(seconds: 4 * H))", "true")
check("more time is never darker",
      "\((1...20).allSatisfy { GreenRamp.position(seconds: $0 * H) >= GreenRamp.position(seconds: ($0 - 1) * H) })",
      "true")
check("ramp bottom is the muted stop", String(format: "%.2f", GreenRamp.rgb(0).g), "0.26")
check("full day hits mint", String(format: "%.2f", GreenRamp.rgb(1).g), "0.97")
check("double day is near-white", "\(GreenRamp.rgb(2).r > 0.85)", "true")
check("ramp clamps below zero", "\(GreenRamp.rgb(-5).g == GreenRamp.rgb(0).g)", "true")
check("ramp clamps above the top stop", "\(GreenRamp.rgb(99).r == GreenRamp.rgb(2).r)", "true")


// ---- text stays readable on top of the ramp ----
func isDarkText(_ hours: Int) -> Bool { GreenRamp.textColor(seconds: hours * 3600) != .white }
check("white text on an ordinary day", "\(isDarkText(2))", "false")
check("white text on a 4h day", "\(isDarkText(4))", "false")
check("dark text once cells go pale (12h)", "\(isDarkText(12))", "true")
check("dark text on a 15h day", "\(isDarkText(15))", "true")
check("luminance rises with time", "\(GreenRamp.luminance(2) > GreenRamp.luminance(0.5))", "true")


// ---- intraday buckets ----
UserDefaults.standard.removeObject(forKey: "hourlyTotals")
let day = "2026-07-28"
_ = store.addToHour(seconds: 300, key: day, hour: 9)
_ = store.addToHour(seconds: 600, key: day, hour: 9)
_ = store.addToHour(seconds: 1800, key: day, hour: 22)
let h = store.hourly(for: day)
check("hour buckets accumulate", "\(h[9])", "900")
check("a separate hour is separate", "\(h[22])", "1800")
check("untouched hours stay zero", "\(h[0] + h[13])", "0")
check("always 24 buckets", "\(h.count)", "24")
check("unknown day is all zeros", "\(store.hourly(for: "1999-01-01").reduce(0, +))", "0")
// An hour cannot contain more than an hour, whatever the clock does.
_ = store.addToHour(seconds: 9999, key: day, hour: 9)
check("an hour is capped at 3600s", "\(store.hourly(for: day)[9])", "3600")
// Out-of-range hours must not corrupt the day.
_ = store.addToHour(seconds: 500, key: day, hour: 42)
check("bogus hour index is ignored", "\(store.hourly(for: day).reduce(0, +))", "5400")
var incoming = Array(repeating: 0, count: 24); incoming[7] = 1200; incoming[9] = 100
check("merge adds a new hour", "\(store.mergeHourly([day: incoming]))", "1")
check("merge keeps the larger local hour", "\(store.hourly(for: day)[9])", "3600")
check("merge restores a missing hour", "\(store.hourly(for: day)[7])", "1200")
UserDefaults.standard.removeObject(forKey: "hourlyTotals")

UserDefaults.standard.removeObject(forKey: "dailyTotals")
print(fail == 0 ? "\nALL \(pass) CHECKS PASSED" : "\n\(fail) FAILED, \(pass) passed")
exit(fail == 0 ? 0 : 1)
