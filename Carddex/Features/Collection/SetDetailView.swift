import SwiftUI

/// Drill-in for a single set: the binder page (owned holo + ghosted missing
/// slots) plus a "Missing cards" list. Catalog-grounded missing slots show a
/// market price and an "add to grail list" action — the set-completion → grail
/// loop that drives retention.
struct SetDetailView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(WishlistStore.self) private var wishlist
    @Environment(MarketStore.self) private var marketStore
    @Environment(\.dismiss) private var dismiss
    let cardSet: CardSet

    @State private var grailSlot: SetSlot?

    private var missingSlots: [SetSlot] {
        cardSet.slots.filter { store.ownedCard(setName: cardSet.name, number: $0.number) == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack {
                    CircleIconButton(systemImage: "chevron.left") { dismiss() }
                    Spacer()
                    Text(cardSet.name)
                        .font(.display(17))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal)

                BinderPageView(set: cardSet, onSlotTap: { slot in
                    if slot.cardID != nil { grailSlot = slot }
                })
                .padding(.horizontal)

                if !missingSlots.isEmpty {
                    SectionHeader("Missing cards")
                        .padding(.horizontal)

                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(missingSlots) { slot in
                            missingRow(slot)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .tabBarSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $grailSlot) { slot in
            if let cardID = slot.cardID, let card = SampleData.card(id: cardID) {
                AddGrailSheet(card: card, isGrail: wishlist.contains(cardID)) {
                    wishlist.add(cardID: cardID, target: nil, note: nil)
                    Haptics.success()
                } onRemove: {
                    wishlist.remove(cardID)
                }
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private func missingRow(_ slot: SetSlot) -> some View {
        let owned = store.ownedCard(setName: cardSet.name, number: slot.number) != nil
        let isGrail = slot.cardID.map { wishlist.contains($0) } ?? false
        HStack(spacing: Theme.Spacing.md) {
            if let cardID = slot.cardID, let card = SampleData.card(id: cardID) {
                CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice,
                            imageURL: card.imageURL, sport: card.sport)
                    .frame(width: 40)
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
                    .frame(width: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.name).foregroundStyle(Theme.textPrimary).lineLimit(1)
                HStack(spacing: 6) {
                    Text(slot.number).foregroundStyle(Theme.textSecondary)
                    if let rarity = slot.rarity { Text("· \(rarity)").foregroundStyle(Theme.textTertiary) }
                }
                .font(.caption)
                .monospacedDigit()
            }
            Spacer()

            if let cardID = slot.cardID, let card = SampleData.card(id: cardID) {
                Text((marketStore.market[cardID]?.topPrice ?? card.marketPrice ?? .zero).formatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }

            if let cardID = slot.cardID {
                Button {
                    if isGrail {
                        wishlist.remove(cardID)
                        Haptics.impact(.light)
                    } else {
                        grailSlot = slot
                    }
                } label: {
                    Image(systemName: isGrail ? "heart.fill" : "heart")
                        .foregroundStyle(isGrail ? Theme.accent : Theme.textTertiary)
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)
                .disabled(owned)
                .opacity(owned ? 0.3 : 1)
            }
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

/// Minimal "add to grail list" sheet. Keeps the loop one tap from a binder slot;
/// a richer target-price composer can follow.
struct AddGrailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: Card
    let isGrail: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice,
                            imageURL: card.imageURL, sport: card.sport)
                    .frame(maxWidth: 140)
                VStack(spacing: 2) {
                    Text(card.name).font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("\(card.setName) · \(card.number)").font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                Text("Add this to your grail list and The Case will track its market price. You'll see it alongside your collection, separate from the cards you own.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
                if isGrail {
                    PrimaryButton(title: "Remove from grail list", systemImage: "heart.slash") {
                        onRemove(); dismiss()
                    }
                } else {
                    PrimaryButton(title: "Add to grail list", systemImage: "heart") {
                        onAdd(); dismiss()
                    }
                }
            }
            .padding()
            .navigationTitle("Grail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}
