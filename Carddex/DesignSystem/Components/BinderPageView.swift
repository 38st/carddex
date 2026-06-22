import SwiftUI

/// A set's binder page: owned cards (holo if rare) and ghosted missing slots,
/// with a completion ring — the "Pokédex" view.
struct BinderPageView: View {
    @Environment(CollectionStore.self) private var store
    let set: CardSet
    /// When set, missing slots become tappable (e.g. to open an "add to grail"
    /// sheet). Catalog-grounded slots (`cardID != nil`) show a "+" badge.
    var onSlotTap: ((SetSlot) -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: Theme.Spacing.sm)]

    var body: some View {
        let progress = store.completion(for: set)
        let fraction = progress.total > 0 ? Double(progress.owned) / Double(progress.total) : 0

        let isComplete = progress.total > 0 && progress.owned == progress.total

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(set.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    if isComplete {
                        Label("Set complete · 100%", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.warning)
                    } else {
                        GamePill(game: set.game)
                    }
                }
                Spacer()
                CompletionRing(fraction: fraction, label: "\(progress.owned)/\(progress.total)")
            }

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(set.slots) { slot in
                    if let card = store.ownedCard(setName: set.name, number: slot.number) {
                        CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL)
                    } else {
                        ghostSlot(slot)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.lg)
        .overlay {
            if isComplete {
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Theme.warning, Theme.gain, Theme.warning],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.5
                    )
            }
        }
        .shadow(color: isComplete ? Theme.gain.opacity(0.22) : .clear, radius: 18)
    }

    @ViewBuilder
    private func ghostSlot(_ slot: SetSlot) -> some View {
        let grounded = slot.cardID != nil
        if onSlotTap != nil {
            Button {
                onSlotTap?(slot)
                Haptics.selection()
            } label: {
                GhostSlot(number: slot.number, addable: grounded)
            }
            .buttonStyle(.plain)
        } else {
            GhostSlot(number: slot.number, addable: false)
        }
    }
}

/// Circular set-completion indicator that fills in on appear.
struct CompletionRing: View {
    var fraction: Double
    var label: String
    @State private var animated: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 6)
            Circle()
                .trim(from: 0, to: animated)
                .stroke(fraction >= 1 ? Theme.gain : Theme.cream, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .frame(width: 56, height: 56)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                animated = fraction
            }
        }
    }
}

/// An empty, ghosted slot for a card the user is missing. `addable` shows a
/// subtle "+" badge when the slot is catalog-grounded and can be added to the
/// grail list.
struct GhostSlot: View {
    let number: String
    var addable: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.02))
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            VStack(spacing: 4) {
                Image(systemName: addable ? "plus" : "questionmark")
                    .font(.title3)
                    .foregroundStyle(addable ? Theme.cream : Theme.textTertiary)
                Text(number)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
            }
            if addable {
                Text("grail")
                    .font(.system(size: 8, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Theme.cream.opacity(0.2), in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.cream.opacity(0.5)))
                    .foregroundStyle(Theme.cream)
                    .padding(4)
            }
        }
        .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
    }
}
