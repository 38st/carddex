import SwiftUI

@main
struct CarddexApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var store = CollectionStore(items: SampleData.collection)
    @State private var environment = AppEnvironment()
    @State private var subscriptions = SubscriptionStore()
    @State private var router = AppRouter()
    @State private var marketStore = MarketStore(service: AppConfig.marketService)
    @State private var watchlist = WatchlistStore(
        followed: [SampleData.jordan.id, SampleData.brady.id],
        alerts: [
            PriceAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000)),
            PriceAlert(cardID: SampleData.brady.id, target: Money(amount: 60000)),
        ]
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
                .task { await marketStore.refresh() }
                .fullScreenCover(isPresented: Binding(
                    get: { !hasOnboarded },
                    set: { presented in if !presented { hasOnboarded = true } }
                )) {
                    OnboardingView()
                }
        }
    }
}
