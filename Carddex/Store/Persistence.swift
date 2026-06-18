import Foundation
import os

/// Tiny Codable-to-disk persistence so the in-memory stores survive relaunch.
/// Writes JSON into the App Group container when one is configured (shared with
/// future widgets), otherwise Application Support. Cloud sync is Supabase (Phase 2).
enum Disk {
    static let appGroupID = "group.com.carddex.app"

    private static let logger = Logger(subsystem: "com.carddex.app", category: "persistence")

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
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // A missing file is expected on first launch; only log decode/read
            // errors so a corrupted store doesn't silently look like "empty".
            if FileManager.default.fileExists(atPath: url.path) {
                logger.error("Disk.load \(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            }
            return nil
        }
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        let url = directory.appendingPathComponent(name)
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            // Persistence is best-effort (in-memory state stays correct for the
            // session), but a failed save means the change won't survive relaunch.
            // Log so disk-full / App-Group-entitlement issues are visible.
            logger.error("Disk.save \(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }
}
