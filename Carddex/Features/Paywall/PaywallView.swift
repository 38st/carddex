import SwiftUI
import StoreKit

/// Carddex Pro upsell. Fetches real StoreKit 2 products, shows live prices, and
/// processes verified purchases. Falls back to placeholder pricing when products
/// aren't available (simulator without a StoreKit configuration file).
struct PaywallView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(SubscriptionStore.self) private var subs
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var selectedProductID: String?

    private let perks: [(String, String)] = [
        ("infinity", "Unlimited scans"),
        ("chart.line.uptrend.xyaxis", "Price history & analytics"),
        ("square.grid.3x3", "Track every set"),
        ("rectangle.stack", "Bulk scan"),
        ("bell.badge", "Price-movement alerts"),
        ("tag", "eBay auto-listing"),
    ]

    var body: some View {
        ZStack {
            VaultBackground()
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header
                    perksList
                    planCards
                    subscribeButton
                    legalText
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding()
        }
        .task { await fetchProducts() }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
                .padding(.top, Theme.Spacing.lg)
            Text("Case Pro")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Unlimited scans, full analytics, and one-tap selling.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var perksList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(perks, id: \.1) { perk in
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: perk.0)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    Text(perk.1)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.gain)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .glassPanel()
    }

    @ViewBuilder private var planCards: some View {
        if products.isEmpty {
            // No StoreKit products (simulator without config, or App Store Connect
            // not set up). Show the planned pricing as placeholders.
            HStack(spacing: Theme.Spacing.md) {
                placeholderPlan(title: "Annual", price: "$39.99", caption: "7-day free trial", badge: "Best value", isDefault: true)
                placeholderPlan(title: "Monthly", price: "$6.99", caption: "per month", badge: nil, isDefault: false)
            }
        } else {
            HStack(spacing: Theme.Spacing.md) {
                ForEach(products, id: \.id) { product in
                    planCard(for: product)
                }
            }
        }
    }

    private func planCard(for product: Product) -> some View {
        let selected = selectedProductID == product.id
        let isAnnual = product.id.contains("annual")
        return Button {
            Haptics.selection()
            withAnimation(Theme.springTap) { selectedProductID = product.id }
        } label: {
            VStack(spacing: 6) {
                if isAnnual {
                    Text("Best value")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent, in: Capsule())
                }
                Text(isAnnual ? "Annual" : "Monthly")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                Text(product.displayPrice)
                    .font(.title2.weight(.bold)).foregroundStyle(Theme.textPrimary).monospacedDigit()
                Text(isAnnual ? "7-day free trial" : "per month")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Theme.hairline, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func placeholderPlan(title: String, price: String, caption: String, badge: String?, isDefault: Bool) -> some View {
        let selected = (isDefault && selectedProductID == nil) || selectedProductID == title.lowercased()
        return Button {
            Haptics.selection()
            withAnimation(Theme.springTap) { selectedProductID = title.lowercased() }
        } label: {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent, in: Capsule())
                }
                Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
                Text(price).font(.title2.weight(.bold)).foregroundStyle(Theme.textPrimary).monospacedDigit()
                Text(caption).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Theme.hairline, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var subscribeButton: some View {
        if isPurchasing {
            PrimaryButton(title: "Processing…", systemImage: "hourglass") {}
                .disabled(true)
        } else if let product = selectedProduct() {
            PrimaryButton(title: buttonTitle(for: product), systemImage: "crown") {
                Task { await purchase(product) }
            }
        } else if !products.isEmpty {
            PrimaryButton(title: "Select a plan", systemImage: "crown") {}
                .disabled(true)
        } else {
            PrimaryButton(title: "Start 7-day free trial", systemImage: "crown") {
                subs.activatePro()
                Haptics.success()
                dismiss()
            }
        }

        if let purchaseError {
            Text(purchaseError)
                .font(.caption)
                .foregroundStyle(Theme.loss)
                .multilineTextAlignment(.center)
        }
    }

    private var legalText: some View {
        Text("Cancel anytime. Free includes \(subs.freeScanLimit) scans/month and current prices.")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - StoreKit

    private func fetchProducts() async {
        do {
            products = try await env.storeKit.fetchProducts()
            // Default-select the annual plan (best value).
            selectedProductID = products.first(where: { $0.id.contains("annual") })?.id ?? products.first?.id
        } catch {
            // No products available — the placeholder UI handles this.
            products = []
        }
    }

    private func selectedProduct() -> Product? {
        products.first { $0.id == selectedProductID }
    }

    private func buttonTitle(for product: Product) -> String {
        if product.id.contains("annual") {
            return "Start 7-day free trial"
        }
        return "Subscribe for \(product.displayPrice)/mo"
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            if let transaction = try await env.storeKit.purchase(product) {
                // Purchase succeeded — activate Pro locally + sync.
                subs.activatePro()
                Haptics.success()
                dismiss()
                _ = transaction // acknowledged via transaction.finish() in the service
            }
            // nil = user cancelled or pending — no action needed.
        } catch {
            purchaseError = error.localizedDescription
            Haptics.warning()
        }
    }
}

#Preview {
    PaywallView()
        .environment(AppEnvironment(identification: FakeIdentificationService()))
        .environment(SubscriptionStore())
        .preferredColorScheme(.dark)
}
