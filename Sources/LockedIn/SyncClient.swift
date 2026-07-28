import Foundation

/// Minimal PostgREST client — no SDK, just URLSession against Supabase's
/// REST API. The whole backend surface is 5 calls.
struct SyncClient {
    let baseURL: URL
    let anonKey: String

    enum SyncError: LocalizedError {
        case http(Int, String)
        case notFound(String)

        var errorDescription: String? {
            switch self {
            case .http(let code, let body): return "Server error \(code): \(body)"
            case .notFound(let what): return what
            }
        }
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoNoFraction = ISO8601DateFormatter()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = iso.date(from: s) ?? isoNoFraction.date(from: s) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unparseable date: \(s)"))
        }
        return d
    }()

    private func request(_ path: String, method: String, query: [URLQueryItem] = [],
                         body: [String: Any]? = nil, prefer: String? = nil) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw SyncError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    // MARK: - Calls

    func upsertUser(id: UUID, displayName: String) async throws {
        _ = try await request("rest/v1/users", method: "POST",
                              query: [.init(name: "on_conflict", value: "id")],
                              body: ["id": id.uuidString, "display_name": displayName],
                              prefer: "resolution=merge-duplicates")
    }

    /// Creates a group and returns (groupId, code).
    func createGroup(code: String, name: String) async throws -> UUID {
        struct Row: Codable { let id: UUID }
        let data = try await request("rest/v1/groups", method: "POST",
                                     body: ["code": code, "name": name],
                                     prefer: "return=representation")
        guard let row = try Self.decoder.decode([Row].self, from: data).first else {
            throw SyncError.notFound("Group creation returned no row")
        }
        return row.id
    }

    /// Looks up a group by invite code.
    func findGroup(code: String) async throws -> UUID {
        struct Row: Codable { let id: UUID }
        let data = try await request("rest/v1/groups", method: "GET",
                                     query: [.init(name: "code", value: "eq.\(code)"),
                                             .init(name: "select", value: "id")])
        guard let row = try Self.decoder.decode([Row].self, from: data).first else {
            throw SyncError.notFound("No group with code \(code)")
        }
        return row.id
    }

    func joinGroup(groupId: UUID, userId: UUID) async throws {
        _ = try await request("rest/v1/memberships", method: "POST",
                              query: [.init(name: "on_conflict", value: "group_id,user_id")],
                              body: ["group_id": groupId.uuidString, "user_id": userId.uuidString],
                              prefer: "resolution=ignore-duplicates")
    }

    func heartbeat(userId: UUID, dateKey: String, seconds: Int, isActive: Bool,
                   lastActiveAt: Date?) async throws {
        var body: [String: Any] = [
            "user_id": userId.uuidString,
            "date": dateKey,
            "seconds": seconds,
            "is_active": isActive,
            "heartbeat_at": Self.iso.string(from: Date()),
        ]
        if let lastActiveAt {
            body["last_active_at"] = Self.iso.string(from: lastActiveAt)
        }
        _ = try await request("rest/v1/daily_scores", method: "POST",
                              query: [.init(name: "on_conflict", value: "user_id,date")],
                              body: body,
                              prefer: "resolution=merge-duplicates")
    }

    /// This user's whole recorded history, for restoring onto a new Mac.
    func fetchHistory(userId: UUID) async throws -> [String: Int] {
        struct Row: Codable { let date: String; let seconds: Int }
        let data = try await request("rest/v1/daily_scores", method: "GET",
                                     query: [.init(name: "user_id", value: "eq.\(userId.uuidString.lowercased())"),
                                             .init(name: "select", value: "date,seconds")])
        let rows = try JSONDecoder().decode([Row].self, from: data)
        return Dictionary(rows.map { ($0.date, $0.seconds) }, uniquingKeysWith: max)
    }

    func fetchBoard(groupId: UUID, from: String, to: String) async throws -> [BoardRow] {
        let data = try await request("rest/v1/rpc/get_group_board_range", method: "POST",
                                     body: ["p_group": groupId.uuidString,
                                            "p_from": from, "p_to": to])
        return try Self.decoder.decode([BoardRow].self, from: data)
    }
}
