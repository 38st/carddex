import SwiftUI

/// The Grail List — cards the user is hunting but doesn't own. Each row shows the
/// current top price vs an optional target and how far the market is from that
/// target. Tap a grail to open its market detail (and, when acquired, log a buy).
struct GrailsView: View {
    @Environment(WishlistStore.self) private var wishlist
    @Environment(MarketStore.self) private var marketStore
    @Environment(CollectionStore.self) private var collection
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            ScrollView {
                if wishlist.grails.isEmpty {
                    EmptyState(
                        icon: "heart",
                        title: "No grails yet",
                        message: "Open a set's missing cards and tap the heart to start your grail list — cards you're hunting, tracked separately from the ones you own.",
                        actionTitle: "Browse sets",
                        actionIcon: "square.grid.2x2",
                        action: { router.selectedTab = .collection }
                    )
                    .padding(.top, Theme.Spacing.xl)
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(wishlist.grails) { entry in
                            if let card = SampleData.card(id: entry.cardID) {
                                NavigationLink(value: card) { grailRow(card, entry) }
                                    .buttonStyle(.plain)
                            } else {
                                orphanRow(entry)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Grail List")
            .tabBarSafeArea()
            .navigationDestination(for: Card.self) { card in
                MarketCardView(card: card)
            }
        }
    }

    @ViewBuilder
    private func grailRow(_ card: Card, _ entry: GrailEntry) -> some View {
        let current = (marketStore.market[card.id]?.topPrice ?? card.marketPrice ?? .zero).amount
        let owned = collection.items.contains { $0.card.id == card.id }
        HStack(spacing: Theme.Spacing.md) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice,
                        imageURL: card.imageURL, sport: card.sport)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(card.name).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    if owned {
                        Text("OWNED")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.gain.opacity(0.2), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.gain.opacity(0.5)))
                            .foregroundStyle(Theme.gain)
                    }
                }
                Text("\(card.setName) · \(card.number)")
                    .font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                if let target = entry.target {
                    targetLine(current: current, target: target.amount)
                } else {
                    Text("No target · tracking price")
                        .font(.caption2).foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money(amount: current).formatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if entry.target != nil {
                    Image(systemName: "heart.fill").foregroundStyle(Theme.cream).font(.caption)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.cream.opacity(owned ? 0 : 0.16))
        )
    }

    @ViewBuilder
    private func targetLine(current: Decimal, target: Decimal) -> some View {
        let atOrBelow = current <= target && target > 0
        if atOrBelow {
            Label("At target — time to buy", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.gain)
        } else if target > 0 {
            let distance = NSDecimalNumber(decimal: (target - current)).doubleValue
            let pct = NSDecimalNumber(decimal: current).doubleValue > 0
                ? abs(distance) / NSDecimalNumber(decimal: current).doubleValue * 100
                : 0
            Text("\(Money(amount: current).formatted) → \(Money(amount: target).formatted) · \(String(format: "%.0f%%", pct)) to go")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .monospacedDigit()
        }
    }

    /// A grail whose card isn't in the bundled sample catalog (e.g. added from a
    /// real catalog later). Still removable so the list never strands entries.
    private func orphanRow(_ entry: GrailEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.note ?? "Grail").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
                Text(entry.cardID).font(.caption2).foregroundStyle(Theme.textTertiary).lineLimit(1)
            }
            Spacer()
            Button(role: .destructive) { wishlist.remove(entry.cardID) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

#Preview {
    GrailsView()
        .environment(WishlistStore(grails: [
            GrailEntry(cardID: SampleData.charizard.id, target: Money(amount: 250)),
            GrailEntry(cardID: SampleData.jordan.id, target: Money(amount: 90000)),
        ]))
        .environment(CollectionStore(items: SampleData.collection))
        .environment(MarketStore())
        .environment(AppRouter())
        .preferredColorScheme(Theme.appColorScheme)
}
