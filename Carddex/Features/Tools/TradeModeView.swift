import SwiftUI

/// Trade mode: add cards to both sides of a trade, see running values with a
/// fairness indicator. Blue ocean — no competitor has this.
struct TradeModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionStore.self) private var store
    @Environment(MarketStore.self) private var marketStore
    @State private var showAddSheet = false
    @State private var activeSide: TradeSide = .you
    @State private var youCards: [TradeCard] = []
    @State private var themCards: [TradeCard] = []
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            fairnessIndicator
                            sideSection("You give", side: .you, cards: youCards)
                            sideSection("They give", side: .them, cards: themCards)
                        }
                        .padding()
                    }

                    bottomBar
                }
            }
            .navigationTitle("Trade Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        Haptics.impact(.light)
                        youCards.removeAll()
                        themCards.removeAll()
                    }
                    .disabled(youCards.isEmpty && themCards.isEmpty)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                TradeCardPicker(side: activeSide) { card in
                    let tradeCard = TradeCard(
                        card: card,
                        price: marketStore.market[card.id]?.topPrice ?? card.marketPrice ?? .zero
                    )
                    if activeSide == .you {
                        if !youCards.contains(where: { $0.id == card.id }) {
                            youCards.append(tradeCard)
                        }
                    } else {
                        if !themCards.contains(where: { $0.id == card.id }) {
                            themCards.append(tradeCard)
                        }
                    }
                    Haptics.selection()
                }
            }
            .sheet(isPresented: $showResult) {
                TradeResultSheet(
                    youTotal: youTotal,
                    themTotal: themTotal,
                    onConfirm: { dismiss() }
                )
            }
        }
        .preferredColorScheme(Theme.appColorScheme)
    }

    enum TradeSide {
        case you, them
    }

    struct TradeCard: Identifiable {
        let card: Card
        let price: Money
        var id: String { card.id }
    }

    private var youTotal: Money {
        Money(amount: youCards.reduce(Decimal.zero) { $0 + $1.price.amount })
    }

    private var themTotal: Money {
        Money(amount: themCards.reduce(Decimal.zero) { $0 + $1.price.amount })
    }

    private var diff: Money {
        Money(amount: youTotal.amount - themTotal.amount)
    }

    private var diffPercent: Double {
        guard themTotal.amount > 0 else { return 0 }
        return NSDecimalNumber(decimal: diff.amount).doubleValue /
               NSDecimalNumber(decimal: themTotal.amount).doubleValue * 100
    }

    @ViewBuilder private var fairnessIndicator: some View {
        let youVal = NSDecimalNumber(decimal: youTotal.amount).doubleValue
        let themVal = NSDecimalNumber(decimal: themTotal.amount).doubleValue
        let balanced = abs(youVal - themVal) < max(youVal, themVal) * 0.05

        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(spacing: 2) {
                    Text("You")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(youTotal.formatted)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Image(systemName: balanced ? "scalemas.fill" : "scalemas")
                        .font(.title2)
                        .foregroundStyle(balanced ? Theme.gain : (diff.amount > 0 ? Theme.gain : Theme.loss))
                    if youCards.isEmpty && themCards.isEmpty {
                        Text("Add cards to both sides")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    } else if balanced {
                        Text("Fair trade")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.gain)
                    } else if diff.amount > 0 {
                        Text("You +\(diff.formatted)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.gain)
                            .monospacedDigit()
                    } else {
                        Text("You −\(Money(amount: abs(diff.amount)).formatted)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.loss)
                            .monospacedDigit()
                    }
                }

                VStack(spacing: 2) {
                    Text("Them")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(themTotal.formatted)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }

            if !youCards.isEmpty || !themCards.isEmpty {
                GeometryReader { geo in
                    let total = youTotal.amount + themTotal.amount
                    let youFrac = total > 0 ? CGFloat(NSDecimalNumber(decimal: youTotal.amount / total).doubleValue) : 0.5
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.loss.opacity(0.3))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.gain.opacity(0.6))
                            .frame(width: geo.size.width * youFrac)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    @ViewBuilder private func sideSection(_ title: String, side: TradeSide, cards: [TradeCard]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    activeSide = side
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(Theme.cream)
                }
                .buttonStyle(.plain)
            }

            if cards.isEmpty {
                HStack {
                    Image(systemName: "rectangle.dashed")
                        .foregroundStyle(Theme.textTertiary)
                    Text("No cards added")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .glassPanel(cornerRadius: Theme.Radius.card)
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(cards) { tc in
                        tradeCardRow(tc, side: side)
                    }
                }
            }
        }
    }

    @ViewBuilder private func tradeCardRow(_ tc: TradeCard, side: TradeSide) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            CardArtwork(game: tc.card.game, rarity: tc.card.rarity, price: tc.card.marketPrice, imageURL: tc.card.imageURL, sport: tc.card.sport)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(tc.card.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(tc.card.setName)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(tc.price.formatted)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()

            Button {
                Haptics.impact(.light)
                if side == .you {
                    youCards.removeAll { $0.id == tc.id }
                } else {
                    themCards.removeAll { $0.id == tc.id }
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.loss.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    @ViewBuilder private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.hairline)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(youCards.count) vs \(themCards.count) cards")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                    if !youCards.isEmpty && !themCards.isEmpty {
                        Text("\(diff.amount >= 0 ? "+" : "−")\(Money(amount: abs(diff.amount)).formatted) (\(String(format: "%.0f", abs(diffPercent)))%)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(diff.amount >= 0 ? Theme.gain : Theme.loss)
                            .monospacedDigit()
                    }
                }
                Spacer()
                PrimaryButton(title: "Finalize", systemImage: "checkmark.seal.fill") {
                    Haptics.success()
                    showResult = true
                }
                .disabled(youCards.isEmpty || themCards.isEmpty)
            }
            .padding(Theme.Spacing.md)
        }
        .background(.ultraThinMaterial.opacity(0.6))
    }
}

private struct TradeCardPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionStore.self) private var store
    let side: TradeModeView.TradeSide
    let onPick: (Card) -> Void
    @State private var searchText = ""

    private func filteredCards() -> [Card] {
        let collectionCards = store.items.map(\.card)
        let marketCards = SampleData.marketCards
        let seen = Set(marketCards.map(\.id))
        let extra = collectionCards.filter { !seen.contains($0.id) }
        let all = marketCards + extra
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.textSecondary)
                        TextField("Search cards", text: $searchText)
                            .font(.body)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(Theme.Spacing.md)
                    .glassPanel(cornerRadius: Theme.Radius.card)
                    .padding()

                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.xs) {
                            ForEach(filteredCards()) { card in
                                Button {
                                    onPick(card)
                                    dismiss()
                                } label: {
                                    HStack(spacing: Theme.Spacing.md) {
                                        CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                                            .frame(width: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Theme.textPrimary)
                                                .lineLimit(1)
                                            Text(card.setName)
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text((card.marketPrice ?? .zero).formatted)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .monospacedDigit()
                                    }
                                    .padding(Theme.Spacing.sm)
                                    .glassPanel(cornerRadius: Theme.Radius.card)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(side == .you ? "Add your card" : "Add their card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .preferredColorScheme(Theme.appColorScheme)
    }
}

private struct TradeResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    let youTotal: Money
    let themTotal: Money
    let onConfirm: () -> Void

    private var diff: Money {
        Money(amount: youTotal.amount - themTotal.amount)
    }

    private var verdict: (text: String, icon: String, color: Color) {
        let youVal = NSDecimalNumber(decimal: youTotal.amount).doubleValue
        let themVal = NSDecimalNumber(decimal: themTotal.amount).doubleValue
        let pct = themVal > 0 ? abs(youVal - themVal) / themVal * 100 : 100
        if pct < 5 {
            return ("Fair trade", "scalemas.fill", Theme.gain)
        } else if youVal > themVal {
            return ("You win by \(diff.formatted)", "arrow.up.circle.fill", Theme.gain)
        } else {
            return ("You lose by \(Money(amount: abs(diff.amount)).formatted)", "arrow.down.circle.fill", Theme.loss)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: verdict.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(verdict.color)

                    Text(verdict.text)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(verdict.color)

                    VStack(spacing: Theme.Spacing.sm) {
                        summaryRow("You gave", youTotal.formatted)
                        summaryRow("They gave", themTotal.formatted)
                        Divider().overlay(Theme.hairline)
                        summaryRow("Difference", "\(diff.amount >= 0 ? "+" : "−")\(Money(amount: abs(diff.amount)).formatted)")
                    }
                    .padding(Theme.Spacing.md)
                    .glassPanel(cornerRadius: Theme.Radius.card)

                    Spacer()
                    PrimaryButton(title: "Done", systemImage: "checkmark") {
                        onConfirm()
                    }
                }
                .padding()
            }
            .navigationTitle("Trade Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .preferredColorScheme(Theme.appColorScheme)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
    }
}
