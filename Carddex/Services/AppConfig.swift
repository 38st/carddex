import Foundation

/// Supabase connection values, loaded from a gitignored `Secrets.plist` at runtime.
/// Absent → the app runs against the fake identification service.
struct SupabaseConfig {
    let baseURL: URL
    let identifyURL: URL
    let marketDataURL: URL
    let anonKey: String

    /// Builds the three endpoint URLs from a project ref. Returns nil if the ref
    /// produces any invalid URL — the caller then falls back to the fake backend
    /// instead of crashing on a malformed `Secrets.plist` value.
    init?(projectRef: String, anonKey: String) {
        guard
            let baseURL = URL(string: "https://\(projectRef).supabase.co"),
            let identifyURL = URL(string: "https://\(projectRef).functions.supabase.co/identify"),
            let marketDataURL = URL(string: "https://\(projectRef).functions.supabase.co/market-data")
        else { return nil }
        self.baseURL = baseURL
        self.identifyURL = identifyURL
        self.marketDataURL = marketDataURL
        self.anonKey = anonKey
    }
}

enum AppConfig {
    /// The parsed `Secrets.plist` contents (empty when the file is absent or unreadable).
    /// `nonisolated(unsafe)` is safe: it's an immutable `let` only ever read (String casts).
    private nonisolated(unsafe) static let secrets: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any]
        else { return [:] }
        return dict
    }()

    /// Present only when `Carddex/Resources/Secrets.plist` exists with real values.
    static let supabase: SupabaseConfig? = {
        guard
            let ref = secrets["SUPABASE_PROJECT_REF"] as? String, !ref.isEmpty, ref != "your-project-ref",
            let key = secrets["SUPABASE_ANON_KEY"] as? String, !key.isEmpty
        else { return nil }
        return SupabaseConfig(projectRef: ref, anonKey: key)
    }()

    /// eBay Partner Network campaign id for outbound affiliate links. Empty when
    /// not configured → the sold-search URL omits `campid` (still works, just
    /// untagged). Set `EBAY_AFFILIATE_CAMPAIGN_ID` in `Secrets.plist` to earn.
    static let affiliateCampaignID: String = {
        let id = secrets["EBAY_AFFILIATE_CAMPAIGN_ID"] as? String ?? ""
        return (id.isEmpty || id == "your-epn-campaign-id") ? "" : id
    }()

    /// The market-data source. In DEBUG we default to the local Supabase stack so
    /// the app shows live data out of the box; release uses the cloud project if
    /// `Secrets.plist` is present, otherwise nil (the store stays on sample data).
    static let marketService: (any MarketServiceProtocol)? = {
        #if DEBUG
        return MarketService.localDev
        #else
        if let s = supabase {
            return MarketService(baseURL: s.marketDataURL, apiKey: s.anonKey)
        }
        return nil
        #endif
    }()
}
