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
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }

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
}
