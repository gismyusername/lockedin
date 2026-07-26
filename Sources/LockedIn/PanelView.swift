import SwiftUI

struct PanelView: View {
    @EnvironmentObject var state: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showSettings {
                SettingsView(showSettings: $showSettings)
            } else if state.displayName.isEmpty {
                NamePromptView()
            } else {
                mainPanel
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusHeader()
            if state.configured {
                if state.inGroup {
                    let friends = state.board.filter { $0.userId != state.userId }
                    if friends.isEmpty {
                        InviteView(compact: true)
                    } else {
                        LiveSection(friends: friends)
                        LeaderboardSection()
                    }
                } else {
                    InviteView(compact: false)
                }
            } else {
                Divider().padding(.vertical, 10)
                Text("Solo mode — add a backend in settings to compete with friends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            FooterView(showSettings: $showSettings)
        }
    }
}

// MARK: - Sections

struct StatusHeader: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TimeFormat.long(state.todaySeconds))
                .font(.system(size: 34, weight: .bold, design: .monospaced))
            HStack(spacing: 6) {
                Circle()
                    .fill(state.isLockedIn ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(state.isLockedIn ? "LOCKED IN" : (state.todaySeconds == 0 ? "0m — lock in?" : "idle"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(state.isLockedIn ? Color.green : Color.secondary)
            }
            .padding(.vertical, 3).padding(.horizontal, 10)
            .overlay(Capsule().strokeBorder(
                state.isLockedIn ? Color.green.opacity(0.6) : Color.secondary.opacity(0.4)))
        }
    }
}

struct LiveSection: View {
    @EnvironmentObject var state: AppState
    let friends: [BoardRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Live")
            // Grinding friends first — they're the reason to open the panel.
            ForEach(friends.sorted {
                (Presence(row: $0) == .grinding ? 0 : 1) < (Presence(row: $1) == .grinding ? 0 : 1)
            }) { row in
                HStack(spacing: 8) {
                    Avatar(name: row.displayName)
                    Text(row.displayName).lineLimit(1)
                    Spacer(minLength: 4)
                    PresenceLabel(presence: Presence(row: row))
                }
                .font(.system(size: 13))
            }
        }
        .padding(.top, 10)
        .overlay(Divider(), alignment: .top)
        .padding(.top, 10)
    }
}

struct PresenceLabel: View {
    let presence: Presence

    var body: some View {
        switch presence {
        case .grinding:
            HStack(spacing: 5) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                    .shadow(color: .green, radius: 3)
                Text("grinding now").foregroundStyle(Color.green)
            }.font(.caption)
        case .idle(let minutes):
            Text("idle \(minutes)m").font(.caption).foregroundStyle(.secondary)
        case .lastSeen(let date):
            Text(TimeFormat.ago(date)).font(.caption).foregroundStyle(.tertiary)
        }
    }
}

struct LeaderboardSection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let rows = state.board
        let top = max(rows.first?.seconds ?? 0, 1)
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Today")
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                let isMe = row.userId == state.userId
                HStack(spacing: 8) {
                    Text(index == 0 ? "👑" : "\(index + 1)")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .center)
                    Avatar(name: isMe ? "You" : row.displayName)
                    Text(isMe ? "You" : row.displayName).lineLimit(1)
                        .font(.system(size: 13))
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: max(geo.size.width * CGFloat(row.seconds) / CGFloat(top), 4),
                                   height: 6)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    Text(TimeFormat.long(row.seconds))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3).padding(.horizontal, 4)
                .background(isMe ? RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.12)) : nil)
            }
        }
        .padding(.top, 10)
        .overlay(Divider(), alignment: .top)
        .padding(.top, 10)
    }
}

struct InviteView: View {
    @EnvironmentObject var state: AppState
    let compact: Bool
    @State private var joinCode = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if compact, let code = state.groupCode {
                // In a group but alone: surface the code to share.
                SectionTitle("Invite friends")
                HStack {
                    Text("Share code:")
                    Text(code).font(.system(.body, design: .monospaced)).bold()
                        .textSelection(.enabled)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                    }
                }.font(.system(size: 13))
                Text("The board fills in as friends join and grind.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                SectionTitle("Compete with friends")
                Button {
                    busy = true
                    Task { await state.createGroup(); busy = false }
                } label: {
                    Text("Create a group").frame(maxWidth: .infinity)
                }
                .disabled(busy)
                HStack {
                    TextField("Invite code", text: $joinCode)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { join() }
                    Button("Join") { join() }.disabled(busy || joinCode.isEmpty)
                }
            }
        }
        .padding(.top, 10)
        .overlay(Divider(), alignment: .top)
        .padding(.top, 10)
    }

    private func join() {
        busy = true
        Task { await state.joinGroup(code: joinCode); busy = false }
    }
}

struct NamePromptView: View {
    @EnvironmentObject var state: AppState
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Locked In").font(.title3.bold())
            Text("Your timer is already running. What should friends call you?")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Display name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await state.saveDisplayName(name) } }
                Button("Go") { Task { await state.saveDisplayName(name) } }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Binding var showSettings: Bool
    @State private var url = UserDefaults.standard.string(forKey: "supabaseUrl") ?? ""
    @State private var key = UserDefaults.standard.string(forKey: "supabaseKey") ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { showSettings = false }
            }
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }))
            if let code = state.groupCode {
                HStack {
                    Text("Group code: \(code)").font(.caption)
                    Spacer()
                    Button("Leave group") { state.leaveGroup() }
                        .font(.caption)
                }
            }
            Divider()
            Text("Backend (Supabase)").font(.caption.bold())
            TextField("https://xyz.supabase.co", text: $url)
                .textFieldStyle(.roundedBorder).font(.caption)
            SecureField("anon key", text: $key)
                .textFieldStyle(.roundedBorder).font(.caption)
            Button("Save backend") { state.saveSupabaseConfig(url: url, key: key) }
            Divider()
            Button("Quit Locked In") { NSApp.terminate(nil) }
        }
    }
}

// MARK: - Bits

struct FooterView: View {
    @EnvironmentObject var state: AppState
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            let streak = state.streak
            Text(streak > 0 ? "🔥 \(streak) day streak" : "🔥 no streak yet")
                .font(.caption)
                .foregroundStyle(streak > 0 ? .primary : .secondary)
            Spacer()
            if state.syncError != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
                    .help(state.syncError ?? "")
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(.top, 10)
        .overlay(Divider(), alignment: .top)
        .padding(.top, 10)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(1)
            .foregroundStyle(.secondary)
    }
}

struct Avatar: View {
    let name: String

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: 11, weight: .medium))
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color.secondary.opacity(0.25)))
            .overlay(Circle().strokeBorder(Color.secondary.opacity(0.4)))
    }
}
