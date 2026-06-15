import SwiftUI

/// A set's binder page: owned cards (holo if rare) and ghosted missing slots,
/// with a completion ring — the "Pokédex" view.
struct BinderPageView: View {
    @Environment(CollectionStore.self) private var store
    let set: CardSet

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: Theme.Spacing.sm)]

    var body: some View {
        let progress = store.completion(for: set)
        let fraction = progress.total > 0 ? Double(progress.owned) / Double(progress.total) : 0

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(set.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    GamePill(game: set.game)
                }
                Spacer()
                CompletionRing(fraction: fraction, label: "\(progress.owned)/\(progress.total)")
            }

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(set.slots) { slot in
                    if let card = store.ownedCard(setName: set.name, number: slot.number) {
                        CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice)
                    } else {
                        GhostSlot(number: slot.number)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.lg)
    }
}

/// Circular set-completion indicator.
struct CompletionRing: View {
    var fraction: Double
    var label: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .frame(width: 56, height: 56)
    }
}

/// An empty, ghosted slot for a card the user is missing.
struct GhostSlot: View {
    let number: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.02))
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            VStack(spacing: 4) {
                Image(systemName: "questionmark")
                    .font(.title3)
                    .foregroundStyle(Theme.textTertiary)
                Text(number)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
            }
        }
        .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
    }
}
