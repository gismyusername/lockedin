import Foundation
import SwiftUI
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    @Published var todaySeconds: Int = 0
    @Published var isLockedIn: Bool = false
    @Published var board: [BoardRow] = []
    @Published var displayName: String
    @Published var groupCode: String?
    @Published var syncError: String?
    @Published var launchAtLogin: Bool = false

    private var groupId: UUID?
    private(set) var userId: UUID
    private var client: SyncClient?
    private var lastActiveAt: Date?
    private var tick = 0
    private var timer: Timer?
    private var userRegistered = false

    /// Idle threshold: last input under 60s ago counts as locked in.
    private let idleThreshold: Double = 60
    private let tickSeconds = 5

    var configured: Bool { client != nil }
    var inGroup: Bool { groupId != nil }

    var grindingFriendCount: Int {
        board.filter { $0.userId != userId && Presence(row: $0) == .grinding }.count
    }

    var menuBarTitle: String {
        var title = TimeFormat.short(todaySeconds)
        let grinding = grindingFriendCount
        if grinding > 0 { title += " | \(grinding) grinding" }
        return title
    }

    init() {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: "userId"), let id = UUID(uuidString: stored) {
            userId = id
        } else {
            userId = UUID()
            defaults.set(userId.uuidString, forKey: "userId")
        }
        displayName = defaults.string(forKey: "displayName") ?? ""
        groupCode = defaults.string(forKey: "groupCode")
        if let stored = defaults.string(forKey: "groupId") { groupId = UUID(uuidString: stored) }
        client = Config.supabase()
        todaySeconds = LocalStore.shared.todaySeconds()
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        start()
    }

    func start() {
        timer?.invalidate()
        let t = Timer(timeInterval: Double(tickSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
        // .common mode so the timer fires while the popover is open.
        RunLoop.main.add(t, forMode: .common)
        timer = t
        onTick()
    }

    private func onTick() {
        let idle = IdleTracker.idleSeconds()
        isLockedIn = idle < idleThreshold
        if isLockedIn {
            todaySeconds = LocalStore.shared.addToToday(seconds: tickSeconds)
            lastActiveAt = Date()
        } else {
            // Day may have rolled over at midnight while idle.
            todaySeconds = LocalStore.shared.todaySeconds()
        }
        tick += 1
        let secondsElapsed = tick * tickSeconds
        if secondsElapsed % 60 == 0 { Task { await sendHeartbeat() } }
        if secondsElapsed % 30 == 0 { Task { await refreshBoard() } }
    }

    var streak: Int { LocalStore.shared.streakDays() }

    // MARK: - Sync

    /// The users row is a foreign key target for every heartbeat, but the name
    /// can be set before a backend is configured (solo mode). Re-assert it on
    /// launch so a solo-then-configured install doesn't heartbeat into a
    /// missing row forever.
    private func ensureUserRegistered() async {
        guard let client, !displayName.isEmpty, !userRegistered else { return }
        do {
            try await client.upsertUser(id: userId, displayName: displayName)
            userRegistered = true
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func sendHeartbeat() async {
        guard let client, !displayName.isEmpty else { return }
        await ensureUserRegistered()
        do {
            try await client.heartbeat(userId: userId, dateKey: LocalStore.dateKey(),
                                       seconds: todaySeconds, isActive: isLockedIn,
                                       lastActiveAt: lastActiveAt)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    func refreshBoard() async {
        guard let client, let groupId else { return }
        do {
            board = try await client.fetchBoard(groupId: groupId, dateKey: LocalStore.dateKey())
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Onboarding actions

    func saveDisplayName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = String(trimmed.prefix(20))
        UserDefaults.standard.set(displayName, forKey: "displayName")
        guard let client else { return }
        do {
            try await client.upsertUser(id: userId, displayName: displayName)
            userRegistered = true
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    func createGroup() async {
        guard let client else { return }
        // 6-char code, unambiguous alphabet (no 0/O/1/I).
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let code = String((0..<6).map { _ in alphabet.randomElement()! })
        do {
            try await client.upsertUser(id: userId, displayName: displayName)
            let id = try await client.createGroup(code: code, name: "\(displayName)'s group")
            try await client.joinGroup(groupId: id, userId: userId)
            setGroup(id: id, code: code)
            await refreshBoard()
        } catch {
            syncError = error.localizedDescription
        }
    }

    func joinGroup(code rawCode: String) async {
        guard let client else { return }
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }
        do {
            try await client.upsertUser(id: userId, displayName: displayName)
            let id = try await client.findGroup(code: code)
            try await client.joinGroup(groupId: id, userId: userId)
            setGroup(id: id, code: code)
            await refreshBoard()
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func setGroup(id: UUID, code: String) {
        groupId = id
        groupCode = code
        UserDefaults.standard.set(id.uuidString, forKey: "groupId")
        UserDefaults.standard.set(code, forKey: "groupCode")
        syncError = nil
    }

    func leaveGroup() {
        groupId = nil
        groupCode = nil
        board = []
        UserDefaults.standard.removeObject(forKey: "groupId")
        UserDefaults.standard.removeObject(forKey: "groupCode")
    }

    // MARK: - Settings actions

    func saveSupabaseConfig(url: String, key: String) {
        UserDefaults.standard.set(url.trimmingCharacters(in: .whitespaces), forKey: "supabaseUrl")
        UserDefaults.standard.set(key.trimmingCharacters(in: .whitespaces), forKey: "supabaseKey")
        client = Config.supabase()
        userRegistered = false
        syncError = client == nil ? "Invalid Supabase URL or key" : nil
        Task { await ensureUserRegistered() }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        // Only works from a real .app bundle, not a bare `swift run` binary.
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            syncError = "Launch at login needs the bundled app (run scripts/bundle.sh)"
            launchAtLogin = false
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            syncError = nil
        } catch {
            syncError = "Launch at login failed: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
