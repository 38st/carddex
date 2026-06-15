import SwiftUI

/// The Market — a Card Ladder-style view of the card market: the Carddex Index,
/// movers, and a searchable, sports-first card database.
struct MarketView: View {
    @State private var search = ""

    private func change(_ card: Card) -> Double { SampleData.market[card.id]?.change30d ?? 0 }

    private var results: [Card] {
        guard !search.isEmpty else { return SampleData.marketCards }
        let q = search.lowercased()
        return SampleData.marketCards.filter {
            $0.name.lowercased().contains(q) || $0.setName.lowercased().contains(q)
        }
    }

    private var movers: [Card] {
        SampleData.marketCards.sorted { abs(change($0)) > abs(change($1)) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    indexCard

                    if search.isEmpty {
                        sectionTitle("Movers")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.md) {
                                ForEach(movers) { card in
                                    NavigationLink(value: card) { MoverCard(card: card) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    sectionTitle(search.isEmpty ? "Top cards" : "Results")
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(results) { card in
                            NavigationLink(value: card) { MarketRow(card: card) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Market")
            .searchable(text: $search, prompt: "Search the market")
            .navigationDestination(for: Card.self) { card in
                MarketCardView(card: card)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal)
    }

    private var indexCard: some View {
        let index = SampleData.marketIndex
        let up = index.changeToday >= 0
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Carddex Index")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(index.value, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                Text("\(up ? "▲ +" : "▼ ")\(String(format: "%.1f", index.changeToday))% today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(up ? Theme.gain : Theme.loss)
            }
            MiniAreaChart(values: index.series, tint: up ? Theme.gain : Theme.loss)
                .frame(height: 80)
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.lg)
        .padding(.horizontal)
    }
}

private struct MarketRow: View {
    let card: Card

    var body: some View {
        let market = SampleData.market[card.id]
        HStack(spacing: Theme.Spacing.md) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(card.setName).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text((market?.topPrice ?? card.marketPrice ?? .zero).formatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if let change = market?.change30d {
                    Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

private struct MoverCard: View {
    let card: Card

    var body: some View {
        let market = SampleData.market[card.id]
        VStack(alignment: .leading, spacing: 8) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                .frame(width: 94)
            Text(card.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text((market?.topPrice ?? .zero).formatted)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
            if let change = market?.change30d {
                Text("\(change >= 0 ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(change)))%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
            }
        }
        .frame(width: 114)
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

#Preview {
    MarketView()
        .environment(CollectionStore(items: SampleData.collection))
        .preferredColorScheme(.dark)
}
