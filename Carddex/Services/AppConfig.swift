import Foundation

/// Supabase connection values, loaded from a gitignored `Secrets.plist` at runtime.
/// Absent → the app runs against the fake identification service.
struct SupabaseConfig {
    let projectRef: String
    let anonKey: String

    var baseURL: URL { URL(string: "https://\(projectRef).supabase.co")! }
    var identifyURL: URL { URL(string: "https://\(projectRef).functions.supabase.co/identify")! }
}

enum AppConfig {
    /// Present only when `Carddex/Resources/Secrets.plist` exists with real values.
    static let supabase: SupabaseConfig? = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any],
            let ref = dict["SUPABASE_PROJECT_REF"] as? String, !ref.isEmpty, ref != "your-project-ref",
            let key = dict["SUPABASE_ANON_KEY"] as? String, !key.isEmpty
        else { return nil }
        return SupabaseConfig(projectRef: ref, anonKey: key)
    }()
}
