import SwiftUI

/// Price alerts manager (Card Ladder-style): every card you've set a target on,
/// with its current value and distance to the target.
struct AlertsView: View {
    @Environment(WatchlistStore.self) private var watchlist
    @Environment(\.dismiss) private var dismiss

    private var rows: [(card: Card, alert: PriceAlert)] {
        watchlist.alerts.compactMap { alert in
            SampleData.marketCards.first { $0.id == alert.cardID }.map { (card: $0, alert: alert) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                if rows.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(rows, id: \.alert.id) { row in
                                AlertRow(card: row.card, alert: row.alert) {
                                    withAnimation { watchlist.removeAlert(row.alert.cardID) }
                                    Haptics.selection()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Price alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textTertiary)
            Text("No price alerts")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Tap the bell on any card to get notified when it hits your target price.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
    }
}

private struct AlertRow: View {
    let card: Card
    let alert: PriceAlert
    let onRemove: () -> Void

    private var current: Money {
        SampleData.market[card.id]?.topPrice ?? card.marketPrice ?? .zero
    }

    var body: some View {
        let cur = NSDecimalNumber(decimal: current.amount).doubleValue
        let tgt = NSDecimalNumber(decimal: alert.target.amount).doubleValue
        let reached = cur >= tgt
        let distance = tgt > 0 ? (tgt - cur) / tgt * 100 : 0
        HStack(spacing: Theme.Spacing.md) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).font(.subheadline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text("Target \(alert.target.formatted)").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(current.formatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if reached {
                    Label("Reached", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.gain)
                } else {
                    Text("\(String(format: "%.0f", abs(distance)))% to go")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Button { onRemove() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
        .overlay(alignment: .leading) {
            if reached {
                Capsule().fill(Theme.gain).frame(width: 3).padding(.vertical, 10)
            }
        }
    }
}

#Preview {
    AlertsView()
        .environment(WatchlistStore(alerts: [
            PriceAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000)),
            PriceAlert(cardID: SampleData.brady.id, target: Money(amount: 60000)),
        ]))
        .preferredColorScheme(.dark)
}
