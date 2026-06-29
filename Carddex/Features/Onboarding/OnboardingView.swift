import SwiftUI

/// First-run onboarding: three vault scenes that set up the magic moment and
/// prime the camera permission. Dismisses by setting `hasOnboarded`.
struct OnboardingView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(AppRouter.self) private var router
    @State private var page = 0
    private let pages = OnboardingPage.all

    private var isLastPage: Bool { page == pages.count - 1 }

    /// End onboarding straight into the magic moment: drop the user on the Scan
    /// tab so the first thing they do is scan a card (the North Star action).
    private func finishWithScan() {
        router.selectedTab = .scan
        hasOnboarded = true
    }

    var body: some View {
        ZStack {
            VaultBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { hasOnboarded = true }
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding()

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        OnboardingPageView(page: item).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Theme.cream : Theme.textTertiary.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, Theme.Spacing.md)

                if isLastPage {
                    Text("We'll ask for camera access when you scan your first card.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, Theme.Spacing.sm)
                }

                PrimaryButton(
                    title: isLastPage ? "Scan your first card" : "Continue",
                    systemImage: isLastPage ? "viewfinder" : nil
                ) {
                    if isLastPage {
                        finishWithScan()
                    } else {
                        withAnimation(Theme.springUI) { page += 1 }
                    }
                }
                .padding(.horizontal)

                if isLastPage {
                    Button("I'll explore first") { hasOnboarded = true }
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, Theme.Spacing.sm)
                }
            }
            .padding(.bottom, Theme.Spacing.lg)
        }
        .preferredColorScheme(Theme.appColorScheme)
    }
}

struct OnboardingPage: Identifiable {
    enum Kind { case holo, scan, value }
    let id = UUID()
    let kind: Kind
    let headline: String
    let subtitle: String

    static let all: [OnboardingPage] = [
        OnboardingPage(kind: .holo,
                       headline: "Your collection, alive",
                       subtitle: "Every card you own — tracked, valued, and shining like the real thing in your hand."),
        OnboardingPage(kind: .scan,
                       headline: "Snap to identify",
                       subtitle: "Point your camera at any card and The Case knows what it is and what it's worth."),
        OnboardingPage(kind: .value,
                       headline: "Watch your value move",
                       subtitle: "Live prices, market movers, and your portfolio's worth — a stock ticker for your cards."),
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            hero.frame(height: 300)
            VStack(spacing: Theme.Spacing.sm) {
                Text(page.headline)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }
        }
        .padding()
    }

    @ViewBuilder private var hero: some View {
        switch page.kind {
        case .holo:
            LivingCardView(game: .sports, price: SampleData.jordan.marketPrice,
                           imageURL: SampleData.jordan.imageURL, sport: .basketball, maxWidth: 188)
        case .scan:
            ZStack {
                CardArtwork(game: .sports, price: SampleData.brady.marketPrice,
                            imageURL: SampleData.brady.imageURL, sport: .football)
                    .frame(width: 150)
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.cream, lineWidth: 3)
                    .frame(width: 208, height: 268)
                Image(systemName: "viewfinder")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.cream)
                    .offset(y: 150)
            }
        case .value:
            VStack(spacing: Theme.Spacing.md) {
                VStack(spacing: 4) {
                    Text("$20,188")
                        .font(.display(46))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("▲ $3,098 (18%) all-time")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.gain)
                }
                MiniAreaChart(values: [10, 12, 11, 14, 13, 16, 15, 19, 21, 24], tint: Theme.gain)
                    .frame(height: 96)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppRouter())
}
