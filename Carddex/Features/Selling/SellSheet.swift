import SwiftUI

/// eBay listing composer. Pre-fills a title, price, and condition from the card,
/// estimates payout after fees, links to sold comps (affiliate), and publishes via
/// the eBay Sell API once the user's eBay account is connected (Phase 3).
struct SellSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let item: CollectionItem

    @State private var title: String
    @State private var priceText: String
    @State private var condition: CardCondition
    @State private var quantity: Int

    init(item: CollectionItem) {
        self.item = item
        _title = State(initialValue: "\(item.card.name) — \(item.card.setName) \(item.card.number)")
        let amount = item.card.marketPrice?.amount ?? 0
        _priceText = State(initialValue: NSDecimalNumber(decimal: amount).stringValue)
        _condition = State(initialValue: item.condition)
        _quantity = State(initialValue: item.quantity)
    }

    private var priceDouble: Double { Double(priceText) ?? 0 }
    private var estimatedPayout: Double { max(0, priceDouble - priceDouble * 0.1325 - 1.0) }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header

                        field("Listing title") {
                            TextField("Title", text: $title, axis: .vertical)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        field("Price (USD)") {
                            TextField("0.00", text: $priceText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        field("Condition") {
                            Picker("Condition", selection: $condition) {
                                ForEach(CardCondition.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.cream)
                        }
                        field("Quantity") {
                            Stepper("\(quantity)", value: $quantity, in: 1...max(1, item.quantity))
                                .foregroundStyle(Theme.textPrimary)
                        }

                        payoutRow

                        PrimaryButton(title: "List on eBay", systemImage: "tag") {
                            // Phase 3: ensure eBay is connected (OAuth) then call `ebay-list`.
                        }

                        Button {
                            if let url = Marketplace.ebaySoldSearchURL(for: item.card) { openURL(url) }
                        } label: {
                            Label("See recent sold prices on eBay", systemImage: "chart.bar")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.cream)
                        }

                        Text("Connect your eBay account in Settings to publish listings.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Sell")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            CardArtwork(game: item.card.game, rarity: item.card.rarity, price: item.card.marketPrice, imageURL: item.card.imageURL, sport: item.card.sport)
                .frame(width: 84)
            VStack(alignment: .leading, spacing: 4) {
                GamePill(game: item.card.game, sport: item.card.sport)
                Text(item.card.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if let price = item.card.marketPrice {
                    Text("Market \(price.formatted)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
            }
            Spacer()
        }
    }

    private var payoutRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Est. payout after fees")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text("eBay ~13.25% + $1.00 shipping")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text(Money(amount: Decimal(estimatedPayout)).formatted)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.gain)
                .monospacedDigit()
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    @ViewBuilder private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.xms)
                .glassPanel(cornerRadius: Theme.Radius.md)
        }
    }
}

#Preview {
    SellSheet(item: SampleData.collection[0])
}
