import SwiftUI
import WidgetKit

@main
struct CarddexApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var environment = AppEnvironment()
    @State private var persistence = PersistenceController.shared
    @State private var store = CollectionStore(items: SampleData.collection, persistence: PersistenceController.shared)
    @State private var subscriptions = SubscriptionStore(persistence: PersistenceController.shared)
    @State private var router = AppRouter()
    @State private var marketStore = MarketStore(service: AppConfig.marketService)
    @State private var watchlist = WatchlistStore(
        followed: [SampleData.jordan.id, SampleData.brady.id],
        alerts: [
            PriceAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000)),
            PriceAlert(cardID: SampleData.brady.id, target: Money(amount: 60000)),
        ],
        persistence: PersistenceController.shared
    )
    @State private var wishlist = WishlistStore(
        grails: [
            GrailEntry(cardID: SampleData.charizard.id, target: Money(amount: 250)),
        ],
        persistence: PersistenceController.shared
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(environment)
                .environment(environment.auth)
                .environment(subscriptions)
                .environment(router)
                .environment(watchlist)
                .environment(wishlist)
                .environment(marketStore)
                .task {
                    wireSync()
                    SpotlightIndexer.index(SampleData.marketCards)
                    consumePendingTab()
                    await verifyEntitlement()
                    await marketStore.refresh()
                    if environment.auth.isSignedIn {
                        await pullRemoteState()
                    }
                    updateWidget()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        consumePendingTab()
                    } else {
                        updateWidget()
                    }
                }
                .onChange(of: environment.auth.isSignedIn) { _, signedIn in
                    if signedIn { Task { await pullRemoteState() } }
                }
                .fullScreenCover(isPresented: Binding(
                    get: { !hasOnboarded },
                    set: { presented in if !presented { hasOnboarded = true } }
                )) {
                    OnboardingView()
                }
        }
    }

    /// Connect the stores to the sync service once the composition root is up.
    /// Stores stay local-only (sync = nil) when no backend is configured.
    private func wireSync() {
        store.sync = environment.sync
        watchlist.sync = environment.sync
        wishlist.sync = environment.sync
        subscriptions.sync = environment.sync
    }

    /// Pull the user's remote state and merge into local stores. Called on app
    /// launch (when signed in) and on sign-in. Additive merge: remote items not
    /// present locally are appended; local items keep their state. A proper LWW
    /// merge needs `updated_at` timestamps (Phase 2).
    private func pullRemoteState() async {
        guard let remote = try? await environment.sync.pullAll() else { return }
        store.mergeRemote(remote.collectionItems)
        watchlist.mergeRemote(remote.priceAlerts)
        wishlist.mergeRemote(remote.wishlistEntries)
        if let sub = remote.subscription {
            subscriptions.applyRemote(sub)
        }
    }

    /// Verify the StoreKit 2 entitlement on launch. If the user has an active
    /// Pro subscription (verified via `Transaction.currentEntitlements`), flip
    /// `isPro` on. This catches subscriptions made on another device or restored
    /// after reinstall.
    private func verifyEntitlement() async {
        let isPro = await environment.storeKit.verifyEntitlement()
        if isPro && !subscriptions.isPro {
            subscriptions.activatePro()
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
