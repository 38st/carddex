import SwiftUI

/// Pure rollup of a freshly-scanned batch — total value, count, and the top
/// cards by value. Lives apart from the view so it's unit-testable.
struct ShoeboxSummary {
    let cards: [Card]

    var count: Int { cards.count }

    var total: Money {
        cards.reduce(Money.zero) { $0 + ($1.marketPrice ?? .zero) }
    }

    func topCards(_ limit: Int = 3) -> [Card] {
        cards
            .sorted { ($0.marketPrice?.amount ?? 0) > ($1.marketPrice?.amount ?? 0) }
            .prefix(limit)
            .map { $0 }
    }

    /// Distinct games in scan order, for the share poster's game tiles.
    func games(_ limit: Int) -> [CardGame] {
        var seen = Set<CardGame>()
        return Array(cards.map(\.game).filter { seen.insert($0).inserted }.prefix(limit))
    }
}

/// The bulk-scan payoff: "your box is worth $X." Shown the moment a scanned
/// stack finishes identifying — the Marcus acquisition wow-moment ("what's my
/// shoebox worth, with no typing"). Reveals total value, card count, the top
/// cards, and a one-tap share CTA, then routes back to review & add.
struct BatchValueSummaryView: View {
    let cards: [Card]
    /// Dismiss the reveal and return to the review list to curate & add.
    let onReviewAndAdd: () -> Void

    @State private var revealScale: CGFloat = 0.85
    @State private var revealOpacity: Double = 0
    @State private var shareImage: Image?

    private var summary: ShoeboxSummary { ShoeboxSummary(cards: cards) }
    private var total: Money { summary.total }
    private var totalDouble: Double { NSDecimalNumber(decimal: total.amount).doubleValue }
    private var topCards: [Card] { summary.topCards() }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header
                        if !topCards.isEmpty { topCardsRow }
                        disclaimer
                    }
                    .padding()
                }
                .safeAreaInset(edge: .bottom) { footer }
            }
            .navigationTitle("Your shoebox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let shareImage {
                        ShareLink(item: shareImage,
                                  preview: SharePreview("My shoebox · The Case", image: shareImage)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                Haptics.success()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    revealScale = 1
                    revealOpacity = 1
                }
                renderShareImage()
            }
        }
        .preferredColorScheme(Theme.appColorScheme)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(cards.count == 1 ? "Your card is worth" : "Your box is worth")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            RollingNumber(totalDouble,
                          format: { Money(amount: Decimal($0)).formatted },
                          size: 52, color: Theme.cream)
                .scaleEffect(revealScale)
                .opacity(revealOpacity)
            Text("\(cards.count) card\(cards.count == 1 ? "" : "s") identified")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }

    private var topCardsRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Top cards")
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                ForEach(Array(topCards.enumerated()), id: \.offset) { _, card in
                    VStack(spacing: 6) {
                        CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice,
                                    imageURL: card.imageURL, sport: card.sport)
                            .frame(width: 84)
                        Text(card.name)
                            .font(.caption2)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(card.marketPrice?.formatted ?? "—")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.cream)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("Estimated market value — not a guaranteed sale price.")
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        PrimaryButton(title: "Review & add to collection", systemImage: "plus") {
            onReviewAndAdd()
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    @MainActor private func renderShareImage() {
        let poster = ShareableShoeboxPoster(
            totalValue: total.formatted,
            cardCount: cards.count,
            tiles: summary.games(4)
        )
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        if let uiImage = renderer.uiImage { shareImage = Image(uiImage: uiImage) }
    }
}

#Preview {
    BatchValueSummaryView(cards: Array(SampleData.cards.prefix(5))) {}
}
