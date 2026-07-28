import SwiftUI
import AppKit

/// The move prompt needs a running NSApplication, so it waits for launch
/// rather than firing from the App initialiser.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        InstallToApplications.promptIfNeeded()
        Updater.checkInBackground()
    }
}

@main
struct LockedInApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState()

    init() {
        // Two copies (say, a dev build and the installed one) share a bundle id
        // and therefore the same UserDefaults store, so both tickers credit the
        // same day and the timer runs at double speed. Hand off to whichever
        // copy got here first and leave.
        let id = Bundle.main.bundleIdentifier ?? "com.lockedin.app"
        let me = ProcessInfo.processInfo.processIdentifier
        let existing = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter { $0.processIdentifier != me }
        if let other = existing.first {
            other.activate(options: .activateIgnoringOtherApps)
            exit(0)
        }
    }

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
