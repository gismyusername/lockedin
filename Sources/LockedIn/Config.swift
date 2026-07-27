import Foundation

/// Supabase credentials. Resolution order:
/// 1. Secrets.plist bundled into the app (how friends' builds ship pre-wired)
/// 2. UserDefaults (pasted into Settings during development)
/// Absent both, the app runs in solo mode — timer and streak work, no leaderboard.
struct Config {
    /// Group every fresh install joins by itself, so friends never type a code.
    /// Same resolution order as the backend credentials.
    static func defaultGroupCode() -> String? {
        let raw: String?
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: String],
           let code = dict["DEFAULT_GROUP_CODE"] {
            raw = code
        } else {
            raw = UserDefaults.standard.string(forKey: "defaultGroupCode")
        }
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    static func supabase() -> SyncClient? {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: String],
           let urlString = dict["SUPABASE_URL"], let key = dict["SUPABASE_ANON_KEY"],
           let base = URL(string: urlString), !key.isEmpty {
            return SyncClient(baseURL: base, anonKey: key)
        }
        let defaults = UserDefaults.standard
        if let urlString = defaults.string(forKey: "supabaseUrl"),
           let key = defaults.string(forKey: "supabaseKey"),
           let base = URL(string: urlString), !key.isEmpty {
            return SyncClient(baseURL: base, anonKey: key)
        }
        return nil
    }
}
