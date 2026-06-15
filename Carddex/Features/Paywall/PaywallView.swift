import SwiftUI

/// Carddex Pro upsell. Plans are display-only here; StoreKit 2 purchase + receipt
/// validation land at go-live (see docs/setup-runbook.md).
struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var subs
    @Environment(\.dismiss) private var dismiss
    @State private var plan: Plan = .annual

    enum Plan { case monthly, annual }

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

                    HStack(spacing: Theme.Spacing.md) {
                        planCard(.annual, title: "Annual", price: "$39.99", caption: "7-day free trial", badge: "Best value")
                        planCard(.monthly, title: "Monthly", price: "$6.99", caption: "per month", badge: nil)
                    }

                    PrimaryButton(title: plan == .annual ? "Start 7-day free trial" : "Subscribe for $6.99/mo") {
                        subs.activatePro()
                        dismiss()
                    }

                    Text("Cancel anytime. Free includes \(subs.freeScanLimit) scans/month and current prices.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
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
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
                .padding(.top, Theme.Spacing.lg)
            Text("Carddex Pro")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Unlimited scans, full analytics, and one-tap selling.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func planCard(_ value: Plan, title: String, price: String, caption: String, badge: String?) -> some View {
        let selected = plan == value
        return Button {
            withAnimation(Theme.springTap) { plan = value }
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
}

#Preview {
    PaywallView()
        .environment(SubscriptionStore())
}
