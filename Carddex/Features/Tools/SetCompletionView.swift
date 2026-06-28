import SwiftUI

/// Portfolio-wide set completion overview: shows all tracked sets sorted by
/// completion %, with summary stats and quick navigation to set details.
/// Accessible from the Tools hub.
struct SetCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionStore.self) private var store
    @Environment(WishlistStore.self) private var wishlist
    @Environment(MarketStore.self) private var marketStore

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        summaryCard
                        ForEach(sortedSets) { entry in
                            SetProgressRow(set: entry.set, owned: entry.owned, total: entry.total)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Set Completion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private struct SetEntry: Identifiable {
        let id: String
        let set: CardSet
        let owned: Int
        let total: Int
        var fraction: Double { total > 0 ? Double(owned) / Double(total) : 0 }
    }

    private var sortedSets: [SetEntry] {
        SampleData.sets.map { set in
            let c = store.completion(for: set)
            return SetEntry(id: set.id, set: set, owned: c.owned, total: c.total)
        }.sorted { $0.fraction > $1.fraction }
    }

    private var summaryCard: some View {
        let sets = sortedSets
        let totalSlots = sets.reduce(0) { $0 + $1.total }
        let ownedSlots = sets.reduce(0) { $0 + $1.owned }
        let avgCompletion = totalSlots > 0 ? Double(ownedSlots) / Double(totalSlots) : 0
        let completedSets = sets.filter { $0.fraction >= 1.0 }.count
        let closest = sets.filter { $0.fraction > 0 && $0.fraction < 1.0 }.max(by: { $0.fraction < $1.fraction })

        return VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(spacing: 4) {
                    Text("\(Int(avgCompletion * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.cream)
                        .monospacedDigit()
                    Text("Avg completion")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 50).overlay(Theme.hairline)

                VStack(spacing: 4) {
                    Text("\(ownedSlots)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("Cards owned")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 50).overlay(Theme.hairline)

                VStack(spacing: 4) {
                    Text("\(completedSets)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.gain)
                        .monospacedDigit()
                    Text("Sets done")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            if let closest = closest, closest.fraction > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(Theme.cream)
                    Text("Closest: \(closest.set.name) — \(Int(closest.fraction * 100))%")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

private struct SetProgressRow: View {
    @Environment(CollectionStore.self) private var store
    @Environment(WishlistStore.self) private var wishlist
    let set: CardSet
    let owned: Int
    let total: Int

    private var fraction: Double { total > 0 ? Double(owned) / Double(total) : 0 }
    private var missingCount: Int { total - owned }
    private var grailsInSet: Int {
        var count = 0
        for slot in set.slots {
            if let cardID = slot.cardID, wishlist.contains(cardID) { count += 1 }
        }
        return count
    }

    var body: some View {
        NavigationLink(value: set) {
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(set.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            GamePill(game: set.game)
                            if missingCount > 0 {
                                Text("\(missingCount) missing")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                                    .monospacedDigit()
                            }
                            if grailsInSet > 0 {
                                Text("· \(grailsInSet) on grail")
                                    .font(.caption)
                                    .foregroundStyle(Theme.cream)
                                    .monospacedDigit()
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(owned)/\(total)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(fraction >= 1 ? Theme.gain : Theme.textPrimary)
                            .monospacedDigit()
                        Text("\(Int(fraction * 100))%")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                            .monospacedDigit()
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(fraction >= 1 ? Theme.gain : Theme.cream)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 6)
            }
            .padding(Theme.Spacing.md)
            .glassPanel(cornerRadius: Theme.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(fraction >= 1 ? Theme.gain.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .navigationDestination(for: CardSet.self) { set in
            SetDetailView(cardSet: set)
        }
    }
}
