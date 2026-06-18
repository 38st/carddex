import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        // Native TabView gives the authentic iOS 26 Liquid Glass tab bar
        // (floating, morphing, scroll-edge refraction). Each tab sits on the
        // warm vault backdrop.
        TabView(selection: $router.selectedTab) {
            SwiftUI.Tab("Market", systemImage: "chart.line.uptrend.xyaxis", value: .market) {
                tab { MarketView() }
            }
            SwiftUI.Tab("Collection", systemImage: "square.grid.2x2", value: .collection) {
                tab { CollectionView() }
            }
            SwiftUI.Tab("Scan", systemImage: "viewfinder", value: .scan) {
                tab { ScanView() }
            }
            SwiftUI.Tab("Portfolio", systemImage: "dollarsign.circle", value: .portfolio) {
                tab { PortfolioView() }
            }
            SwiftUI.Tab("Settings", systemImage: "gearshape", value: .settings) {
                tab { SettingsView() }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.cream)
    }

    @ViewBuilder private func tab<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        ZStack {
            VaultBackground()
            content()
        }
    }
}

#Preview {
    RootView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(AppEnvironment())
        .environment(SubscriptionStore())
        .environment(AppRouter())
        .environment(WatchlistStore())
        .environment(WishlistStore())
        .environment(MarketStore())
}
