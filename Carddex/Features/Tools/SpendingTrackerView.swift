import SwiftUI

/// Spending tracker: total invested vs current value, monthly spend breakdown,
/// biggest wins and losses. Complements the portfolio view.
struct SpendingTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionStore.self) private var store

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        summaryCard
                        monthlyBreakdown
                        winsAndLosses
                        statsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Spending Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(Theme.appColorScheme)
    }

    private var itemsWithCost: [CollectionItem] {
        store.items.filter { $0.hasCostBasis }
    }

    private var totalInvested: Double {
        itemsWithCost.reduce(0.0) { $0 + $1.costBasis.amount.doubleValue }
    }

    private var totalValue: Double {
        store.items.reduce(0.0) { $0 + $1.estimatedValue.amount.doubleValue }
    }

    private var totalGainLoss: Double {
        totalValue - totalInvested
    }

    private var totalGainPercent: Double {
        guard totalInvested > 0 else { return 0 }
        return totalGainLoss / totalInvested * 100
    }

    @ViewBuilder private var summaryCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(spacing: 4) {
                    Text(Money(amount: Decimal(totalInvested)).formatted)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("Total invested")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40).overlay(Theme.hairline)

                VStack(spacing: 4) {
                    Text(Money(amount: Decimal(totalValue)).formatted)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("Current value")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            Divider().overlay(Theme.hairline)

            HStack {
                Text("Net gain / loss")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    Text("\(totalGainLoss >= 0 ? "+" : "−")\(Money(amount: Decimal(abs(totalGainLoss))).formatted)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(totalGainLoss >= 0 ? Theme.gain : Theme.loss)
                        .monospacedDigit()
                    Text("(\(totalGainLoss >= 0 ? "+" : "")\(String(format: "%.1f", totalGainPercent))%)")
                        .font(.caption)
                        .foregroundStyle(totalGainLoss >= 0 ? Theme.gain : Theme.loss)
                        .monospacedDigit()
                }
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private struct MonthlySpend: Identifiable {
        let month: String
        let sortDate: Date
        let spent: Double
        let count: Int
        var id: String { month }
    }

    private var monthlySpends: [MonthlySpend] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: itemsWithCost) { item in
            let components = calendar.dateComponents([.year, .month], from: item.dateAdded)
            return calendar.date(from: components) ?? item.dateAdded
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return grouped.map { (date, items) in
            MonthlySpend(
                month: formatter.string(from: date),
                sortDate: date,
                spent: items.reduce(0.0) { $0 + $1.costBasis.amount.doubleValue },
                count: items.count
            )
        }.sorted { $0.sortDate > $1.sortDate }
    }

    @ViewBuilder private var monthlyBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Monthly Spending")
            if monthlySpends.isEmpty {
                Text("No purchases logged yet")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(Theme.Spacing.md)
                    .glassPanel(cornerRadius: Theme.Radius.card)
            } else {
                let maxSpent = monthlySpends.map(\.spent).max() ?? 1
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(monthlySpends.prefix(6)) { ms in
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(ms.month)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 64, alignment: .leading)
                                .monospacedDigit()

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Theme.cream.opacity(0.6))
                                    .frame(width: geo.size.width * (ms.spent / maxSpent))
                            }
                            .frame(height: 16)

                            Text(Money(amount: Decimal(ms.spent)).formatted)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .monospacedDigit()
                                .frame(width: 64, alignment: .trailing)

                            Text("\(ms.count)")
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                                .monospacedDigit()
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var sortedByGain: [(item: CollectionItem, gain: Double, pct: Double)] {
        itemsWithCost.map { item in
            let gain = item.gainLoss.amount.doubleValue
            let pct = item.gainPercent ?? 0
            return (item, gain, pct)
        }.sorted { $0.gain > $1.gain }
    }

    @ViewBuilder private var winsAndLosses: some View {
        let sorted = sortedByGain
        let wins = sorted.filter { $0.gain > 0 }.prefix(3)
        let losses = sorted.filter { $0.gain < 0 }.suffix(3).reversed()

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if !wins.isEmpty {
                SectionHeader("Biggest Wins")
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(Array(wins), id: \.item.id) { entry in
                        gainLossRow(entry.item, gain: entry.gain, pct: entry.pct)
                    }
                }
            }

            if !losses.isEmpty {
                SectionHeader("Biggest Losses").padding(.top, Theme.Spacing.sm)
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(Array(losses), id: \.item.id) { entry in
                        gainLossRow(entry.item, gain: entry.gain, pct: entry.pct)
                    }
                }
            }

            if wins.isEmpty && losses.isEmpty {
                Text("Log purchase prices to see wins and losses")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(Theme.Spacing.md)
                    .glassPanel(cornerRadius: Theme.Radius.card)
            }
        }
    }

    @ViewBuilder private func gainLossRow(_ item: CollectionItem, gain: Double, pct: Double) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            CardArtwork(game: item.card.game, rarity: item.card.rarity, price: item.card.marketPrice, imageURL: item.card.imageURL, sport: item.card.sport)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.card.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("Paid \(item.costBasis.formatted)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(gain >= 0 ? "+" : "−")\(Money(amount: Decimal(abs(gain))).formatted)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(gain >= 0 ? Theme.gain : Theme.loss)
                    .monospacedDigit()
                Text("\(gain >= 0 ? "+" : "")\(String(format: "%.0f", pct))%")
                    .font(.system(size: 10))
                    .foregroundStyle(gain >= 0 ? Theme.gain : Theme.loss)
                    .monospacedDigit()
            }
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    @ViewBuilder private var statsCard: some View {
        let avgCost = itemsWithCost.isEmpty ? 0 : totalInvested / Double(itemsWithCost.count)
        let tracked = itemsWithCost.count
        let untracked = store.items.count - tracked

        VStack(spacing: Theme.Spacing.sm) {
            statRow("Avg cost per card", Money(amount: Decimal(avgCost)).formatted)
            statRow("Cards with cost basis", "\(tracked)")
            if untracked > 0 {
                statRow("Cards without purchase price", "\(untracked)")
            }
            statRow("Total cards in collection", "\(store.items.count)")
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
    }
}
