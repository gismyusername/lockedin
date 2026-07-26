import SwiftUI

@main
struct LockedInApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(state)
                .onAppear { Task { await state.refreshBoard() } }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: state.isLockedIn ? "bolt.fill" : "bolt")
                Text(state.menuBarTitle)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
