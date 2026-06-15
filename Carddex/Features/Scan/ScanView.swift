import SwiftUI

/// Phase 0 scan screen. The live camera + AI identification pipeline lands in
/// Phase 1; for now a "simulate scan" button exercises the identify → add flow.
struct ScanView: View {
    @Environment(CollectionStore.self) private var store
    @State private var identifiedCard: Card?

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [9])
                        )
                        .foregroundStyle(.secondary.opacity(0.4))
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.accent)
                        Text("Point at a card to scan")
                            .foregroundStyle(.secondary)
                    }
                }
                .aspectRatio(0.82, contentMode: .fit)

                Text("Live camera scanning and AI identification arrive next. For now, simulate a scan to try the flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                PrimaryButton(title: "Simulate scan", systemImage: "wand.and.stars") {
                    identifiedCard = SampleData.cards.randomElement()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Scan")
            .sheet(item: $identifiedCard) { card in
                IdentifyResultSheet(card: card) {
                    store.add(card)
                    identifiedCard = nil
                }
            }
        }
    }
}

/// Bottom sheet that shows an identification result and lets the user save it.
private struct IdentifyResultSheet: View {
    let card: Card
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice)
                    .frame(maxWidth: 160)
                    .padding(.top)
                GamePill(game: card.game)
                Text(card.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("\(card.setName) · \(card.number)")
                    .foregroundStyle(.secondary)
                if let price = card.marketPrice {
                    Text(price.formatted)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                PrimaryButton(title: "Add to collection", systemImage: "plus", action: onAdd)
            }
            .padding()
            .navigationTitle("Identified")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.regularMaterial)
        }
    }
}

#Preview {
    ScanView()
        .environment(CollectionStore(items: SampleData.collection))
}
