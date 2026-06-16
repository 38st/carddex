import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            VaultBackground()

            Group {
                switch router.selectedTab {
                case .market: MarketView()
                case .collection: CollectionView()
                case .scan: ScanView()
                case .portfolio: PortfolioView()
                case .settings: SettingsView()
                }
            }

            // Bottom fade so content dissolves into the dark before the floating bar.
            LinearGradient(colors: [.clear, Theme.bg], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GlassTabBar(selection: $router.selectedTab)
                .padding(.bottom, 4)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(AppEnvironment())
        .environment(SubscriptionStore())
        .environment(AppRouter())
        .environment(WatchlistStore())
        .environment(MarketStore())
}
