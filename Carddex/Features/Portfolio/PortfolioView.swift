import SwiftUI

/// Portfolio value summary, broken down by game.
struct PortfolioView: View {
    @Environment(CollectionStore.self) private var store

    private var gamesWithValue: [CardGame] {
        CardGame.allCases.filter { store.value(for: $0).amount > 0 }
    }

    private func fraction(_ game: CardGame) -> CGFloat {
        let total = NSDecimalNumber(decimal: store.totalValue.amount).doubleValue
        guard total > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: store.value(for: game).amount).doubleValue
        return CGFloat(value / total)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Total value")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Text(store.totalValue.formatted)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(store.totalCards) cards · \(store.items.count) unique")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if !gamesWithValue.isEmpty {
                        Text("By game")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(gamesWithValue) { game in
                                VStack(spacing: Theme.Spacing.sm) {
                                    HStack {
                                        GamePill(game: game)
                                        Spacer()
                                        Text(store.value(for: game).formatted)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .monospacedDigit()
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.white.opacity(0.07))
                                            Capsule().fill(game.accent)
                                                .frame(width: geo.size.width * fraction(game))
                                        }
                                    }
                                    .frame(height: 8)
                                }
                                .padding(Theme.Spacing.md)
                                .glassPanel(cornerRadius: Theme.Radius.card)
                            }
                        }
                    }

                    Text("Live pricing, value history charts, and eBay sync arrive in Phase 2–3.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding()
            }
            .navigationTitle("Portfolio")
        }
    }
}

#Preview {
    PortfolioView()
        .environment(CollectionStore(items: SampleData.collection))
        .preferredColorScheme(.dark)
}
