import Foundation

/// Tiny Codable-to-disk persistence so the in-memory stores survive relaunch.
/// Writes JSON into the App Group container when one is configured (shared with
/// future widgets), otherwise Application Support. Cloud sync is Supabase (Phase 2).
enum Disk {
    static let appGroupID = "group.com.carddex.app"

    private static let directory: URL = {
        let fm = FileManager.default
        if let shared = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return shared
        }
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }()

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        let url = directory.appendingPathComponent(name)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
