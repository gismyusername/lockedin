import Foundation

/// Supabase credentials. Resolution order:
/// 1. Secrets.plist bundled into the app (how friends' builds ship pre-wired)
/// 2. UserDefaults (pasted into Settings during development)
/// Absent both, the app runs in solo mode — timer and streak work, no leaderboard.
struct Config {
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
