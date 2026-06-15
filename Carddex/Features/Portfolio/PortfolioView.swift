import SwiftUI

/// Portfolio value summary, broken down by game.
struct PortfolioView: View {
    @Environment(CollectionStore.self) private var store

    private var gamesWithValue: [CardGame] {
        CardGame.allCases.filter { store.value(for: $0).amount > 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Total value")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(store.totalValue.formatted)
                            .font(.system(size: 40, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(store.totalCards) cards · \(store.items.count) unique")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !gamesWithValue.isEmpty {
                        Text("By game")
                            .font(.headline)
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(gamesWithValue) { game in
                                HStack {
                                    GamePill(game: game)
                                    Spacer()
                                    Text(store.value(for: game).formatted)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(Theme.Spacing.md)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                            }
                        }
                    }

                    Text("Live pricing, value history charts, and eBay sync arrive in Phase 2–3.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
}
