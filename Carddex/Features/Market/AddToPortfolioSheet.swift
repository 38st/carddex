import SwiftUI

/// "Log a buy" — captures cost basis and quantity when adding a card to the
/// portfolio, so ROI and attribution reflect what the user actually paid.
struct AddToPortfolioSheet: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let card: Card
    let suggestedPrice: Money
    var onAdded: () -> Void = {}

    @State private var priceText: String
    @State private var quantity = 1

    init(card: Card, suggestedPrice: Money, onAdded: @escaping () -> Void = {}) {
        self.card = card
        self.suggestedPrice = suggestedPrice
        self.onAdded = onAdded
        let value = NSDecimalNumber(decimal: suggestedPrice.amount).doubleValue
        _priceText = State(initialValue: value > 0 ? String(format: "%.0f", value) : "")
    }

    private var parsedPrice: Money? {
        guard let amount = Decimal(string: priceText.filter { $0.isNumber || $0 == "." }), amount > 0 else { return nil }
        return Money(amount: amount)
    }

    private var totalCost: Money {
        Money(amount: (parsedPrice?.amount ?? 0) * Decimal(quantity))
    }

    private var currentValue: Money {
        Money(amount: suggestedPrice.amount * Decimal(quantity))
    }

    private var projectedGain: Double {
        NSDecimalNumber(decimal: currentValue.amount - totalCost.amount).doubleValue
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                            .frame(maxWidth: 110)
                            .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
                        VStack(spacing: 2) {
                            Text(card.name).font(.headline).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
                            Text("Market \(suggestedPrice.formatted)").font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }

                        costField
                        quantityField
                        summary

                        PrimaryButton(title: "Add to portfolio", systemImage: "plus") {
                            store.add(card, purchasePrice: parsedPrice, quantity: quantity)
                            Haptics.success()
                            onAdded()
                            dismiss()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Log a buy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var costField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("What you paid (each)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack {
                Text("$").foregroundStyle(Theme.textSecondary)
                TextField("0", text: $priceText)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Use market") { priceText = String(format: "%.0f", NSDecimalNumber(decimal: suggestedPrice.amount).doubleValue) }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.cream)
            }
            .padding(Theme.Spacing.md)
            .glassPanel(cornerRadius: Theme.Radius.card)
        }
    }

    private var quantityField: some View {
        HStack {
            Text("Quantity").foregroundStyle(Theme.textPrimary)
            Spacer()
            Stepper("\(quantity)", value: $quantity, in: 1...99)
                .labelsHidden()
            Text("\(quantity)").font(.headline).monospacedDigit().foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 28)
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private var summary: some View {
        VStack(spacing: Theme.Spacing.sm) {
            row("Total cost", totalCost.formatted)
            row("Current value", currentValue.formatted)
            Divider().overlay(Theme.hairline)
            HStack {
                Text("Projected gain").foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(projectedGain >= 0 ? "+" : "−")\(Money(amount: Decimal(abs(projectedGain))).formatted)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(projectedGain >= 0 ? Theme.gain : Theme.loss)
                    .monospacedDigit()
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary).monospacedDigit()
        }
        .font(.subheadline)
    }
}

#Preview {
    AddToPortfolioSheet(card: SampleData.jordan, suggestedPrice: Money(amount: 95000))
        .environment(CollectionStore())
        .preferredColorScheme(.dark)
}
