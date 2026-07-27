import SwiftUI

struct PanelView: View {
    @EnvironmentObject var state: AppState
    @State private var showHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showHistory {
                HistoryView(showHistory: $showHistory)
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
                        LeaderboardSection()
                    }
                } else {
                    InviteView(compact: false)
                }
            } else {
                Divider().padding(.vertical, 10)
                Text("Solo mode — this build has no backend, so it's just your timer. See the README to point it at one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            FooterView(showHistory: $showHistory)
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

struct LeaderboardSection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let rows = state.board
        let top = max(rows.first?.seconds ?? 0, 1)
        let grinding = state.grindingFriendCount + (state.isLockedIn ? 1 : 0)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                ForEach(BoardRange.allCases) { option in
                    let selected = option == state.range
                    Button { state.setRange(option) } label: {
                        Text(option.label)
                            .font(.system(size: 10, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                            .padding(.vertical, 2).padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 4)
                                .fill(selected ? Color.white.opacity(0.1) : .clear))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 2)
                if grinding > 0 {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("\(grinding)").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.green)
                    }
                    .help("\(grinding) grinding right now")
                }
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                let isMe = row.userId == state.userId
                let presence = isMe
                    ? (state.isLockedIn ? Presence.grinding : Presence.idle(minutes: nil))
                    : Presence(row: row)
                let live = presence == .grinding
                let gone = { if case .lastSeen = presence { return true } else { return false } }()
                HStack(spacing: 8) {
                    Text(index == 0 ? "\u{1F451}" : "\(index + 1)")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .center)
                    Avatar(name: row.displayName)
                    Text(isMe ? "You" : row.displayName).lineLimit(1)
                        .font(.system(size: 13))
                        .foregroundStyle(gone ? .tertiary : .primary)
                    if live {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                            .shadow(color: .green, radius: 3)
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(live ? Color.green.opacity(0.75) : Color.secondary.opacity(0.3))
                            .frame(width: max(geo.size.width * CGFloat(row.seconds) / CGFloat(top), 4),
                                   height: 6)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    Text(TimeFormat.long(row.seconds))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(gone ? .tertiary : .secondary)
                }
                .padding(.vertical, 3).padding(.horizontal, 4)
                .background(isMe ? RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.07)) : nil)
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
            Text(Config.defaultGroupCode() != nil
                 ? "Your timer is already running. Pick a name and you're on the board — no code needed."
                 : "Your timer is already running. What should friends call you?")
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

struct FooterView: View {
    @EnvironmentObject var state: AppState
    @Binding var showHistory: Bool

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
            Button { showHistory = true } label: {
                Text("History").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Your previous days")
            Button { NSApp.terminate(nil) } label: {
                Text("Quit").font(.caption).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
            .help("Quit Locked In")
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
