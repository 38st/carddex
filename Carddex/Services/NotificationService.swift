import Foundation
import UserNotifications

/// Local price-alert notifications. No push server / APNs needed: when a market
/// refresh reveals a watched card has reached its target, we fire a *local*
/// notification. Each (card, target) fires once and re-arms only after the price
/// falls back below target, so a user isn't spammed every refresh.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let notifiedKey = "alerts.notifiedKeys"

    private var notified: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: notifiedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: notifiedKey) }
    }

    /// Ask once for permission. Safe to call on every launch (no-op if decided).
    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Evaluate alerts against current prices and fire a notification for any
    /// that newly reached target. `name` resolves a card's display name.
    func evaluate(alerts: [PriceAlert], market: MarketStore, name: (String) -> String) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional else { return }

        let price: (PriceAlert) -> Decimal? = { alert in
            market.market[alert.cardID]?.topPrice.amount
        }
        let result = AlertReconciler.evaluate(alerts: alerts, price: price, notified: notified)
        notified = result.notified

        for alert in result.notify {
            let content = UNMutableNotificationContent()
            content.title = "Price target reached"
            content.body = "\(name(alert.cardID)) hit \(alert.target.formatted)."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "alert-\(AlertReconciler.key(alert))",
                content: content,
                trigger: nil // deliver now
            )
            try? await center.add(request)
        }
    }
}

/// Pure decision logic for price-alert notifications — which alerts newly reached
/// target, and the updated "already notified" key set. Kept separate so it's
/// unit-testable without UNUserNotificationCenter.
enum AlertReconciler {
    static func key(_ alert: PriceAlert) -> String {
        "\(alert.cardID)@\(alert.target.amount)"
    }

    /// - Returns: alerts to notify now, and the new notified-key set. An alert
    ///   fires once when it crosses target and re-arms only after it drops back
    ///   below. Keys for removed alerts are pruned.
    static func evaluate(
        alerts: [PriceAlert],
        price: (PriceAlert) -> Decimal?,
        notified: Set<String>
    ) -> (notify: [PriceAlert], notified: Set<String>) {
        var flags = notified
        var toNotify: [PriceAlert] = []
        for alert in alerts {
            guard let current = price(alert), alert.target.amount > 0 else { continue }
            let k = key(alert)
            if current >= alert.target.amount {
                if !flags.contains(k) {
                    toNotify.append(alert)
                    flags.insert(k)
                }
            } else {
                flags.remove(k) // re-arm for a future crossing
            }
        }
        // Drop keys for alerts that no longer exist.
        flags = flags.intersection(Set(alerts.map(key)))
        return (toNotify, flags)
    }
}
