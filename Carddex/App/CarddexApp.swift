import SwiftUI
import WidgetKit

@main
struct CarddexApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var store = CollectionStore(items: SampleData.collection, persistKey: "collection.json")
    @State private var environment = AppEnvironment()
    @State private var subscriptions = SubscriptionStore(persistKey: "subscription.json")
    @State private var router = AppRouter()
    @State private var marketStore = MarketStore(service: AppConfig.marketService)
    @State private var watchlist = WatchlistStore(
        followed: [SampleData.jordan.id, SampleData.brady.id],
        alerts: [
            PriceAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000)),
            PriceAlert(cardID: SampleData.brady.id, target: Money(amount: 60000)),
        ],
        persistKey: "watchlist.json"
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(environment)
                .environment(subscriptions)
                .environment(router)
                .environment(watchlist)
                .environment(marketStore)
                .task {
                    SpotlightIndexer.index(SampleData.marketCards)
                    consumePendingTab()
                    await marketStore.refresh()
                    updateWidget()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        consumePendingTab()
                    } else {
                        updateWidget()
                    }
                }
                .fullScreenCover(isPresented: Binding(
                    get: { !hasOnboarded },
                    set: { presented in if !presented { hasOnboarded = true } }
                )) {
                    OnboardingView()
                }
        }
    }

    /// Route to a tab requested by an App Intent (e.g. "Scan a card" via Siri).
    private func consumePendingTab() {
        guard let tab = IntentRouter.pendingTab else { return }
        switch tab {
        case "scan": router.selectedTab = .scan
        case "market": router.selectedTab = .market
        case "portfolio": router.selectedTab = .portfolio
        case "collection": router.selectedTab = .collection
        default: break
        }
        IntentRouter.pendingTab = nil
    }

    /// Snapshot the current market + portfolio into the App Group for the widgets.
    private func updateWidget() {
        let idx = marketStore.index
        let gain = NSDecimalNumber(decimal: store.totalGainLoss.amount).doubleValue
        let mover = SampleData.marketCards.max {
            abs(marketStore.market[$0.id]?.change30d ?? 0) < abs(marketStore.market[$1.id]?.change30d ?? 0)
        }
        let snapshot = WidgetSnapshot(
            indexValue: idx.value,
            indexChange: idx.change(for: .month),
            indexSeries: idx.series(for: .month),
            portfolioValue: store.totalValue.formatted,
            portfolioGain: "\(gain >= 0 ? "+" : "−")\(Money(amount: Decimal(abs(gain))).formatted) (\(String(format: "%.0f", abs(store.gainLossPercent)))%)",
            gainUp: gain >= 0,
            topMoverName: mover?.name ?? "—",
            topMoverChange: marketStore.market[mover?.id ?? ""]?.change30d ?? 0,
            updatedAt: Date()
        )
        WidgetBridge.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
