import SwiftUI

/// Month calendar of your own locked-in time, read straight from the local
/// store. Friends' history stays on the server; this view is about your days.
struct HistoryView: View {
    @Binding var showHistory: Bool
    @State private var monthAnchor = Date()
    @State private var selectedKey: String = LocalStore.dateKey()
    @State private var mode: Mode = .calendar

    enum Mode: String, CaseIterable { case calendar = "Calendar", chart = "Chart" }

    private let cal = Calendar.lockedIn
    private var totals: [String: Int] { LocalStore.shared.totalsByDay() }

    private var grid: MonthGrid { MonthGrid.make(anchor: monthAnchor, calendar: cal) }

    /// Scale shading against the best day on record so a heavy month doesn't
    /// wash out and a light one still shows contrast.
    private var peakSeconds: Int { max(totals.values.max() ?? 0, 30 * 60) }

    private var monthKeys: [String] {
        (1...grid.dayCount).compactMap { day in
            grid.date(day: day, calendar: cal).map { LocalStore.dateKey($0) }
        }
    }

    private var monthTotal: Int { monthKeys.reduce(0) { $0 + (totals[$1] ?? 0) } }
    private var daysTracked: Int { monthKeys.filter { (totals[$0] ?? 0) > 0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            modePicker
            if mode == .calendar {
                weekdayRow
                dayGrid
            } else {
                dayChart
            }
            Divider()
            selectedDetail
            monthSummary
        }
    }

    private var header: some View {
        HStack {
            arrow("chevron.left", -1)
            Spacer()
            Text(monthTitle).font(.headline)
            Spacer()
            arrow("chevron.right", 1)
            Button { showHistory = false } label: {
                Text("Done").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
    }

    private func arrow(_ icon: String, _ months: Int) -> some View {
        let enabled = canStep(months)
        return Button { if enabled { step(months) } } label: {
            Image(systemName: icon)
                .foregroundStyle(enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var modePicker: some View {
        HStack(spacing: 3) {
            ForEach(Mode.allCases, id: \.rawValue) { option in
                let selected = option == mode
                Button { mode = option } label: {
                    Text(option.rawValue)
                        .font(.system(size: 10, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .padding(.vertical, 2).padding(.horizontal, 7)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(selected ? Color.white.opacity(0.1) : .clear))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if let best = monthKeys.map({ totals[$0] ?? 0 }).max(), best > 0 {
                Text("best \(TimeFormat.long(best))")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
    }

    /// Daily bars for the month on screen. The calendar answers "which days",
    /// this answers "what shape" — streaks, weekends, the drop-off after a
    /// heavy day.
    private var dayChart: some View {
        let values = monthKeys.map { totals[$0] ?? 0 }
        let peak = max(values.max() ?? 0, 1)
        let tracked = values.filter { $0 > 0 }
        let average = tracked.isEmpty ? 0 : tracked.reduce(0, +) / tracked.count
        return VStack(alignment: .leading, spacing: 3) {
            ZStack(alignment: .bottom) {
                // Mean of the days actually worked, so idle days don't drag it.
                if average > 0 {
                    GeometryReader { geo in
                        let y = geo.size.height * (1 - CGFloat(average) / CGFloat(peak))
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .foregroundStyle(.white.opacity(0.25))
                    }
                }
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(monthKeys.enumerated()), id: \.offset) { index, key in
                        let seconds = totals[key] ?? 0
                        let isSelected = key == selectedKey
                        let height = seconds > 0
                            ? max(3, 92 * CGFloat(seconds) / CGFloat(peak)) : 2
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(seconds > 0
                                  ? GreenRamp.color(GreenRamp.fraction(seconds: seconds, peak: peak))
                                  : Color.white.opacity(0.08))
                            .frame(height: height)
                            .overlay(RoundedRectangle(cornerRadius: 1.5)
                                .strokeBorder(isSelected ? Color.primary.opacity(0.8) : .clear,
                                              lineWidth: 1))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedKey = key }
                            .accessibilityLabel("\(index + 1): \(TimeFormat.long(seconds))")
                    }
                }
            }
            .frame(height: 94)
            // Sparse axis: a label under every 7th day keeps it readable at 320pt.
            HStack(spacing: 2) {
                ForEach(Array(monthKeys.enumerated()), id: \.offset) { index, _ in
                    Text((index + 1) % 7 == 1 ? "\(index + 1)" : " ")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                        // A day column is ~7pt wide, so two digits wrap unless
                        // the label is allowed to overflow its slot.
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(MonthGrid.weekdaySymbols(firstWeekday: cal.firstWeekday).enumerated()),
                    id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let cells: [Int?] = Array(repeating: nil, count: grid.leadingBlanks)
            + (1...grid.dayCount).map { Optional($0) }
        return LazyVGrid(columns: Array(repeating: GridItem(spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day, let date = grid.date(day: day, calendar: cal) {
                    dayCell(day: day, key: LocalStore.dateKey(date))
                } else {
                    Color.clear.frame(height: 30)
                }
            }
        }
    }

    private func dayCell(day: Int, key: String) -> some View {
        let seconds = totals[key] ?? 0
        let isToday = key == LocalStore.dateKey()
        let isSelected = key == selectedKey
        let fill: Color = seconds > 0
            ? GreenRamp.color(GreenRamp.fraction(seconds: seconds, peak: peakSeconds))
            : .clear
        return Text("\(day)")
            .font(.system(size: 11, weight: isToday ? .bold : .regular))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 5).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .strokeBorder(isSelected ? Color.primary.opacity(0.7)
                              : (isToday ? Color.secondary.opacity(0.6) : .clear),
                              lineWidth: isSelected ? 1.5 : 1))
            .contentShape(Rectangle())
            .onTapGesture { selectedKey = key }
    }

    private var selectedDetail: some View {
        let seconds = totals[selectedKey] ?? 0
        return HStack(alignment: .firstTextBaseline) {
            Text(longDate(selectedKey)).font(.caption).foregroundStyle(.secondary)
            Spacer()
            // Monospaced digits are for times; the placeholder shouldn't shout.
            if seconds > 0 {
                Text(TimeFormat.long(seconds))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
            } else {
                Text("nothing logged").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private var monthSummary: some View {
        HStack(spacing: 12) {
            stat("total", TimeFormat.long(monthTotal))
            stat("days", "\(daysTracked)")
            stat("avg/day", daysTracked > 0 ? TimeFormat.long(monthTotal / daysTracked) : "—")
            stat("streak", "\(LocalStore.shared.streakDays())")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold)).kerning(0.5)
                .foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Month navigation

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = cal
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthAnchor).capitalized
    }

    private func longDate(_ key: String) -> String {
        let parse = DateFormatter()
        parse.locale = Locale(identifier: "en_US_POSIX")
        parse.calendar = Calendar(identifier: .gregorian)
        parse.dateFormat = "yyyy-MM-dd"
        parse.timeZone = .current
        guard let date = parse.date(from: key) else { return key }
        let out = DateFormatter()
        out.locale = .current
        out.calendar = cal
        out.dateFormat = "EEEE d MMMM"
        return out.string(from: date).capitalized
    }

    private func step(_ months: Int) {
        guard let next = cal.date(byAdding: .month, value: months, to: monthAnchor) else { return }
        monthAnchor = next
    }

    /// Don't wander past the current month, or before the first day recorded.
    private func canStep(_ months: Int) -> Bool {
        guard let next = cal.date(byAdding: .month, value: months, to: monthAnchor) else { return false }
        let nextMonth = cal.dateComponents([.year, .month], from: next)
        if months > 0 {
            let now = cal.dateComponents([.year, .month], from: Date())
            return (nextMonth.year!, nextMonth.month!) <= (now.year!, now.month!)
        }
        guard let earliest = totals.keys.min() else { return false }
        let parts = earliest.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2 else { return false }
        return (nextMonth.year!, nextMonth.month!) >= (parts[0], parts[1])
    }
}
