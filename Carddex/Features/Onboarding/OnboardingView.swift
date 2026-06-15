import SwiftUI

/// First-run onboarding: three vault scenes that set up the magic moment and
/// prime the camera permission. Dismisses by setting `hasOnboarded`.
struct OnboardingView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var page = 0
    private let pages = OnboardingPage.all

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
                            .fill(index == page ? Theme.accent : Theme.textTertiary.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, Theme.Spacing.md)

                if page == pages.count - 1 {
                    Text("We'll ask for camera access when you scan your first card.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, Theme.Spacing.sm)
                }

                PrimaryButton(title: page == pages.count - 1 ? "Get started" : "Continue") {
                    if page == pages.count - 1 {
                        hasOnboarded = true
                    } else {
                        withAnimation(Theme.springUI) { page += 1 }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
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
                       headline: "Catch every card",
                       subtitle: "Collect Pokémon, Magic, and Yu-Gi-Oh! in one place — holos and all."),
        OnboardingPage(kind: .scan,
                       headline: "Snap to identify",
                       subtitle: "Point your camera at any card and The Case knows what it is and what it's worth."),
        OnboardingPage(kind: .value,
                       headline: "Watch your collection grow",
                       subtitle: "Track each card's value, complete your sets, and see your portfolio over time."),
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
            CardArtwork(game: .pokemon, rarity: "Holo Rare", price: Money(amount: 320),
                        imageURL: URL(string: "https://images.pokemontcg.io/base1/4_hires.png"))
                .frame(width: 184)
                .rotation3DEffect(.degrees(8), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(-8), axis: (x: 0, y: 1, z: 0))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 14)
        case .scan:
            ZStack {
                CardArtwork(game: .magic, rarity: "Mythic", price: Money(amount: 55))
                    .frame(width: 150)
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 3)
                    .frame(width: 208, height: 268)
                Image(systemName: "viewfinder")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent)
                    .offset(y: 150)
            }
        case .value:
            VStack(spacing: Theme.Spacing.md) {
                VStack(spacing: 4) {
                    Text("$1,284")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("▲ $98 (8.3%) this month")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.gain)
                }
                MiniAreaChart(values: [10, 12, 11, 14, 13, 16, 15, 19, 21, 24])
                    .frame(height: 96)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
