import SwiftUI
import UIKit

/// Detail screen for a single owned card — holo hero with gyroscope tilt,
/// stats, and actions.
struct CardDetailView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(MarketStore.self) private var marketStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showSell = false
    @State private var showRemoveConfirm = false
    @State private var showCertLookup = false
    @State private var shareImage: Image?
    let item: CollectionItem

    private var setCompletion: (owned: Int, total: Int)? {
        guard let set = SampleData.sets.first(where: { $0.name == item.card.setName }) else { return nil }
        return store.completion(for: set)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                HStack {
                    CircleIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
                    Spacer()
                    Text(item.card.name)
                        .font(.display(17))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview(item.card.name, image: shareImage)) {
                            Image(systemName: "square.and.arrow.up").circleIconChip(label: "Share")
                        }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }

                FlipCardView {
                    LivingCardView(
                        game: item.card.game,
                        rarity: item.card.rarity,
                        price: item.card.marketPrice,
                        imageURL: item.card.imageURL,
                        sport: item.card.sport,
                        maxWidth: 220
                    )
                } back: {
                    CardBackView(
                        card: item.card,
                        condition: item.condition,
                        setCompletion: setCompletion
                    )
                    .frame(maxWidth: 220)
                }
                .padding(.top, Theme.Spacing.sm)

                VStack(spacing: Theme.Spacing.sm) {
                    GamePill(game: item.card.game, sport: item.card.sport)
                    Text(item.card.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(item.card.setName) · \(item.card.number)\(item.quantity > 1 ? " · ×\(item.quantity)" : "")")
                        .foregroundStyle(Theme.textSecondary)
                    if let rarity = item.card.rarity {
                        Text(rarity)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(icon: "tag.fill", title: "Market", value: item.card.marketPrice?.formatted ?? "—")
                    StatPill(icon: "chart.line.uptrend.xyaxis", title: "Value", value: item.estimatedValue.formatted, accent: Theme.gain)
                }

                if item.hasCostBasis {
                    let gain = NSDecimalNumber(decimal: item.gainLoss.amount).doubleValue
                    HStack(spacing: Theme.Spacing.sm) {
                        StatPill(icon: "creditcard.fill", title: "Paid", value: item.costBasis.formatted)
                        StatPill(
                            icon: gain >= 0 ? "arrow.up.right" : "arrow.down.right",
                            title: gain >= 0 ? "Gain" : "Loss",
                            value: "\(gain >= 0 ? "+" : "−")\(Money(amount: Decimal(abs(gain))).formatted)",
                            accent: gain >= 0 ? Theme.gain : Theme.loss
                        )
                    }
                }

                CardPriceChart(
                    basePrice: NSDecimalNumber(decimal: item.card.marketPrice?.amount ?? 0).doubleValue,
                    series: marketStore.market[item.card.id]?.priceSeries
                )
                .padding(Theme.Spacing.md)
                .glassPanel(cornerRadius: Theme.Radius.card)

                VStack(spacing: Theme.Spacing.sm) {
                    LabeledContent("Condition", value: item.condition.rawValue)
                    Divider().overlay(Theme.hairline)
                    LabeledContent("Added", value: item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    if let cert = item.certNumber {
                        Divider().overlay(Theme.hairline)
                        LabeledContent("Cert #", value: cert)
                        if let company = item.gradingCompany,
                           let url = CertLookupService.lookupURL(company: CertLookupService.GradingCompany(rawValue: company) ?? .psa, certNumber: cert) {
                            Button { openURL(url) } label: {
                                Label("Verify on \(company)", systemImage: "checkmark.seal")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.cream)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .padding(Theme.Spacing.md)
                .glassPanel(cornerRadius: Theme.Radius.card)

                PrimaryButton(title: "List on eBay", systemImage: "tag") { showSell = true }

                Button { showCertLookup = true } label: {
                    Label("Verify a graded card", systemImage: "checkmark.seal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.cream)
                }

                Button(role: .destructive) {
                    showRemoveConfirm = true
                } label: {
                    Label("Remove from collection", systemImage: "trash")
                }
                .tint(Theme.loss)
                .padding(.top, Theme.Spacing.xs)
                .confirmationDialog("Remove this card?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) {
                        Haptics.warning()
                        store.remove(item)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .padding()
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSell) { SellSheet(item: item) }
        .sheet(isPresented: $showCertLookup) { CertLookupView() }
        .onAppear { renderShareImage() }
    }

    @MainActor private func renderShareImage() {
        let poster = ShareableCardPoster(
            name: item.card.name,
            setLine: "\(item.card.setName) · \(item.card.number)",
            price: item.card.marketPrice?.formatted ?? "—",
            game: item.card.game,
            sport: item.card.sport
        )
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(item: SampleData.collection[0])
            .environment(CollectionStore(items: SampleData.collection))
            .environment(MarketStore())
    }
    .preferredColorScheme(.dark)
}
