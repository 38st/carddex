import Foundation

/// Snapshot the app writes to the shared App Group container for the widgets to
/// read. Small + pre-formatted so the widget needs no app logic.
struct WidgetSnapshot: Codable {
    var indexValue: Double
    var indexChange: Double          // percent, selected range
    var indexSeries: [Double]
    var portfolioValue: String       // formatted, e.g. "$20,188.00"
    var portfolioGain: String        // formatted + signed, e.g. "+$3,098 (18%)"
    var gainUp: Bool
    var topMoverName: String
    var topMoverChange: Double        // percent
    var updatedAt: Date

    static let placeholder = WidgetSnapshot(
        indexValue: 1284.50,
        indexChange: 3.1,
        indexSeries: [1180, 1195, 1188, 1210, 1225, 1218, 1240, 1255, 1262, 1271, 1284.5],
        portfolioValue: "$20,188.00",
        portfolioGain: "+$3,098 (18%)",
        gainUp: true,
        topMoverName: "Tom Brady RC",
        topMoverChange: 11.2,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

/// Reads/writes the widget snapshot in the shared App Group container.
enum WidgetBridge {
    static let appGroupID = "group.com.carddex.app"
    private static let fileName = "widget-snapshot.json"

    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func read() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
