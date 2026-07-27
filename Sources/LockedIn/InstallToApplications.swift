import AppKit
import ServiceManagement

/// Offers to move the app into /Applications on first launch.
///
/// The DMG window shows an Applications folder, but nothing stops someone
/// double-clicking the app right there in the disk image or in Downloads. That
/// matters here beyond tidiness: macOS translocates a quarantined app to a
/// random read-only path, so registering it to start at login silently fails
/// and the app vanishes on the next reboot.
enum InstallToApplications {
    private static let destination = URL(fileURLWithPath: "/Applications/LockedIn.app")

    /// Only somewhere a download would land — never nag while developing out
    /// of a build directory.
    static func shouldOffer(bundlePath: String,
                            downloadsPath: String?,
                            fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> Bool {
        if bundlePath.hasPrefix("/Applications/") { return false }
        // Gatekeeper runs quarantined apps from a random read-only mirror.
        if bundlePath.contains("/AppTranslocation/") { return true }
        // Mounted disk image.
        if bundlePath.hasPrefix("/Volumes/") { return true }
        if let downloads = downloadsPath, bundlePath.hasPrefix(downloads + "/") { return true }
        return false
    }

    @MainActor
    static func promptIfNeeded() {
        let source = Bundle.main.bundleURL
        let downloads = FileManager.default.urls(for: .downloadsDirectory,
                                                 in: .userDomainMask).first?.path
        guard shouldOffer(bundlePath: source.path, downloadsPath: downloads) else { return }

        let alert = NSAlert()
        alert.messageText = "Move Locked In to your Applications folder?"
        alert.informativeText = """
            Running it from here means macOS can stop it from starting at login, \
            so your time would quietly go untracked. Moving takes a second.
            """
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not now")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try move(from: source)
        } catch {
            let failure = NSAlert()
            failure.alertStyle = .warning
            failure.messageText = "Couldn't move the app"
            failure.informativeText = "\(error.localizedDescription)\n\nDrag it into Applications yourself and it'll behave."
            failure.runModal()
        }
    }

    /// The destructive half, split out so it can be tested against a temp
    /// directory instead of /Applications.
    static func install(source: URL, destination: URL) throws {
        let fm = FileManager.default
        // Keep any existing copy recoverable rather than deleting outright.
        if fm.fileExists(atPath: destination.path) {
            try fm.trashItem(at: destination, resultingItemURL: nil)
        }
        try fm.copyItem(at: source, to: destination)

        // The copy inherits quarantine, which would make macOS block the very
        // app the user just approved. They consented by clicking Move.
        run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", destination.path])
    }

    @MainActor
    private static func move(from source: URL) throws {
        try install(source: source, destination: destination)

        // The old registration points at a path that is about to be wrong, and
        // the "already registered" flag would stop the new copy re-registering.
        try? SMAppService.mainApp.unregister()
        UserDefaults.standard.set(false, forKey: "didRegisterLoginItem")
        UserDefaults.standard.synchronize()

        // Relaunch from the new location. The helper outlives us by a second
        // so the single-instance guard in the new copy doesn't see this one
        // still running and immediately quit.
        run("/bin/sh", ["-c", "sleep 1; /usr/bin/open \"\(destination.path)\""])
        NSApp.terminate(nil)
    }

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        do { try p.run() } catch { return -1 }
        // The relaunch helper must not be waited on; it outlives this process.
        if tool == "/bin/sh" { return 0 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
