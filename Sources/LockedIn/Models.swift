import Foundation

struct BoardRow: Codable, Identifiable, Equatable {
    let userId: UUID
    let displayName: String
    let seconds: Int
    let isActive: Bool
    let lastActiveAt: Date?
    let heartbeatAt: Date?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case seconds
        case isActive = "is_active"
        case lastActiveAt = "last_active_at"
        case heartbeatAt = "heartbeat_at"
    }
}

/// Exhaustive presence states — every row matches exactly one
/// (see docs/DESIGN.md "Presence rules").
enum Presence: Equatable {
    case grinding
    case idle(minutes: Int)
    case lastSeen(Date?)

    init(row: BoardRow, now: Date = Date()) {
        let heartbeatAge = row.heartbeatAt.map { now.timeIntervalSince($0) } ?? .infinity
        if row.isActive && heartbeatAge < 120 {
            self = .grinding
        } else if heartbeatAge < 600 {
            let mins = row.lastActiveAt.map { max(0, Int(now.timeIntervalSince($0) / 60)) } ?? 0
            self = .idle(minutes: mins)
        } else {
            self = .lastSeen(row.heartbeatAt)
        }
    }
}

enum TimeFormat {
    /// "4h 12m" (or "12m" under an hour, "0m" when empty)
    static func long(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(String(format: "%02dm", m))" : "\(m)m"
    }

    /// "4:12" for the menu bar
    static func short(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }

    static func ago(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "offline" }
        let mins = Int(now.timeIntervalSince(date) / 60)
        if mins < 60 { return "last seen \(max(mins, 10))m ago" }
        if mins < 60 * 24 { return "last seen \(mins / 60)h ago" }
        return "last seen \(mins / (60 * 24))d ago"
    }
}
