import SwiftUI

/// "This week" retention panel for Portfolio: net 7-day value change, new
/// additions, and the week's biggest mover. Pure client-side derivation from
/// `CollectionStore` + `PortfolioHistoryStore` — no backend. Shows a graceful
/// "building" state until a few days of history accrue.
struct WeeklyRecapView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(PortfolioHistoryStore.self) private var history

    private var weekAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    private var currentValue: Double {
        NSDecimalNumber(decimal: store.totalValue.amount).doubleValue
    }

    /// Earliest recorded value within the last 7 days — only when we have at
    /// least two snapshots, so the change reflects real movement.
    private var weekStartValue: Double? {
        let points = history.points(since: weekAgo)
        guard points.count >= 2, let first = points.first else { return nil }
        return first.value
    }

    private var netChange: Double? {
        guard let start = weekStartValue else { return nil }
        return currentValue - start
    }

    private var netPercent: Double {
        guard let start = weekStartValue, start > 0, let net = netChange else { return 0 }
        return net / start * 100
    }

    private var newThisWeek: Int {
        store.items.filter { $0.dateAdded >= weekAgo }.count
    }

    /// Biggest absolute mover this week (gainer or loser); `movers` is already
    /// sorted by absolute gain/loss and only includes items with a cost basis.
    private var topMover: CollectionItem? { store.movers.first }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Theme.cream)
                Text("This week").font(.headline).foregroundStyle(Theme.textPrimary)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                changeLine
                tiles
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .glassCard(cornerRadius: Theme.Radius.xl)
        }
    }

    @ViewBuilder private var changeLine: some View {
        if let net = netChange {
            let up = net >= 0
            VStack(alignment: .leading, spacing: 2) {
                Text("Your collection moved")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 6) {
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    Text("\(up ? "+" : "−")\(money(abs(net))) (\(String(format: "%.1f", abs(netPercent)))%)")
                }
                .font(.title2.weight(.bold))
                .foregroundStyle(up ? Theme.gain : Theme.loss)
                .monospacedDigit()
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Building your first week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Weekly movement appears once a few days of value history accrue.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder private var tiles: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatTile(title: "New this week", value: "\(newThisWeek)")
            if let mover = topMover {
                let g = NSDecimalNumber(decimal: mover.gainLoss.amount).doubleValue
                StatTile(
                    title: g >= 0 ? "Top gainer" : "Top loser",
                    value: "\(g >= 0 ? "+" : "−")\(money(abs(g)))",
                    accent: g >= 0 ? Theme.gain : Theme.loss
                )
            }
        }
        if let mover = topMover {
            Text(mover.card.name)
                .font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
    }

    private func money(_ value: Double) -> String {
        Money(amount: Decimal(value)).formatted
    }
}

#Preview {
    WeeklyRecapView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(PortfolioHistoryStore())
        .padding()
        .background(VaultBackground())
        .preferredColorScheme(Theme.appColorScheme)
}
