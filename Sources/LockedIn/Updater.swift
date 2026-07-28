import AppKit

/// Checks GitHub Releases for a newer build and installs it on request.
///
/// Deliberately not Sparkle: that means an embedded framework, signing keys and
/// an appcast to host, which is a lot of machinery for an app whose whole
/// backend is five REST calls. This asks the public releases API, downloads the
/// same DMG a person would download by hand, and reuses the install path from
/// InstallToApplications.
enum Updater {
    private static let repo = "gismyusername/lockedin"
    private static let checkInterval: TimeInterval = 60 * 60 * 24
    private static let lastCheckKey = "lastUpdateCheck"

    struct Release: Equatable {
        let version: String
        let dmg: URL
    }

    /// Compares dotted numeric versions. Anything unparseable means "no update"
    /// — never nag on a malformed tag.
    static func isNewer(_ remote: String, than local: String) -> Bool {
        func parts(_ s: String) -> [Int]? {
            let trimmed = s.hasPrefix("v") ? String(s.dropFirst()) : s
            let fields = trimmed.split(separator: ".").map(String.init)
            guard !fields.isEmpty else { return nil }
            var out: [Int] = []
            for f in fields {
                guard let n = Int(f) else { return nil }
                out.append(n)
            }
            return out
        }
        guard let r = parts(remote), let l = parts(local) else { return false }
        for i in 0..<max(r.count, l.count) {
            let a = i < r.count ? r[i] : 0
            let b = i < l.count ? l[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    static func latestRelease() async throws -> Release? {
        struct Payload: Codable {
            struct Asset: Codable { let name: String; let browser_download_url: URL }
            let tag_name: String
            let assets: [Asset]
        }
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let asset = payload.assets.first(where: { $0.name.hasSuffix(".dmg") }) else { return nil }
        return Release(version: payload.tag_name, dmg: asset.browser_download_url)
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Downloads the DMG, checks it really contains this app, and swaps it in.
    /// `destination` is injectable so the whole path can be exercised without
    /// touching the installed copy.
    static func downloadAndInstall(_ release: Release,
                                   destination: URL = URL(fileURLWithPath: "/Applications/LockedIn.app")) async throws {
        let (tmpFile, _) = try await URLSession.shared.download(from: release.dmg)
        let dmg = tmpFile.deletingLastPathComponent()
            .appendingPathComponent("LockedIn-\(release.version).dmg")
        try? FileManager.default.removeItem(at: dmg)
        try FileManager.default.moveItem(at: tmpFile, to: dmg)
        defer { try? FileManager.default.removeItem(at: dmg) }

        let mount = try attach(dmg)
        defer { detach(mount) }

        let app = mount.appendingPathComponent("LockedIn.app")
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == "com.lockedin.app" else {
            throw UpdateError.notOurApp
        }
        try InstallToApplications.install(source: app, destination: destination)
    }

    enum UpdateError: LocalizedError {
        case notOurApp
        case mountFailed

        var errorDescription: String? {
            switch self {
            case .notOurApp: return "That download didn't contain Locked In."
            case .mountFailed: return "Couldn't open the downloaded disk image."
            }
        }
    }

    private static func attach(_ dmg: URL) throws -> URL {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["attach", dmg.path, "-nobrowse", "-noverify", "-noautoopen"]
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        guard let line = out.split(separator: "\n").last(where: { $0.contains("/Volumes/") }),
              let range = line.range(of: "/Volumes/") else { throw UpdateError.mountFailed }
        return URL(fileURLWithPath: String(line[range.lowerBound...]).trimmingCharacters(in: .whitespaces))
    }

    private static func detach(_ mount: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["detach", mount.path, "-force", "-quiet"]
        try? p.run()
        p.waitUntilExit()
    }

    // MARK: - Entry point

    /// Runs at launch and once a day after that. Silent unless there is
    /// genuinely something newer.
    @MainActor
    static func checkInBackground() {
        // Skip while the app still lives in a DMG or Downloads — the
        // move-to-Applications prompt owns that moment instead.
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else { return }
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        guard Date().timeIntervalSince1970 - last > checkInterval else { return }

        Task {
            guard let release = try? await latestRelease(),
                  isNewer(release.version, than: currentVersion) else {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
                return
            }
            await MainActor.run { prompt(for: release) }
        }
    }

    @MainActor
    private static func prompt(for release: Release) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        let alert = NSAlert()
        alert.messageText = "Locked In \(release.version) is available"
        alert.informativeText = "You're on \(currentVersion). Updating takes a few seconds and your history is kept."
        alert.addButton(withTitle: "Update now")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            do {
                try await downloadAndInstall(release)
                await MainActor.run { relaunch() }
            } catch {
                await MainActor.run {
                    let failure = NSAlert()
                    failure.alertStyle = .warning
                    failure.messageText = "Update failed"
                    failure.informativeText = "\(error.localizedDescription)\n\nYou can grab it by hand from github.com/\(repo)/releases."
                    failure.runModal()
                }
            }
        }
    }

    @MainActor
    private static func relaunch() {
        // Detached, so the incoming copy doesn't meet the single-instance guard.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open /Applications/LockedIn.app"]
        try? p.run()
        NSApp.terminate(nil)
    }
}
