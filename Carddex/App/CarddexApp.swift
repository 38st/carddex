import SwiftUI
import WidgetKit
import Foundation

@main
struct CarddexApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var environment = AppEnvironment()
    @State private var pushCenter = PushRegistrationCenter.shared
    @State private var ebayConnection = EbayConnection()
    @State private var persistence = PersistenceController.shared
    @State private var syncEngine: SyncEngine?
    @State private var store = CollectionStore(items: SampleData.collection, persistence: PersistenceController.shared)
    @State private var subscriptions = SubscriptionStore(persistence: PersistenceController.shared)
    @State private var router = AppRouter()
    @State private var marketStore = MarketStore(service: AppConfig.marketService)
    @State private var portfolioHistory = PortfolioHistoryStore(persistence: PersistenceController.shared)
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
                .environment(portfolioHistory)
                .environment(ebayConnection)
                .onOpenURL { ebayConnection.handle(url: $0) }
                .task {
                    wireSyncEngine()
                    SpotlightIndexer.index(SampleData.marketCards)
                    consumePendingTab()
                    await verifyEntitlement()
                    await NotificationService.shared.requestAuthorization()
                    await marketStore.refresh()
                    await evaluatePriceAlerts()
                    if environment.auth.isSignedIn {
                        await runSync()
                    }
                    portfolioHistory.record(value: NSDecimalNumber(decimal: store.totalValue.amount).doubleValue)
                    updateWidget()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        consumePendingTab()
                        Task {
                            await marketStore.refresh()
                            await evaluatePriceAlerts()
                            if environment.auth.isSignedIn { await runSync() }
                        }
                    } else {
                        updateWidget()
                    }
                }
                .onChange(of: pushCenter.deviceTokenHex) { _, _ in
                    Task { await uploadDeviceToken() }
                }
                .onChange(of: environment.auth.isSignedIn) { _, signedIn in
                    // A fresh sign-in (new device / reinstall) must do a FULL pull
                    // to restore the account. Reset the watermark and run the sync
                    // in one ordered task so the reset is applied before the pull
                    // reads `lastSyncAt` — otherwise the two actor hops can race and
                    // the pull goes incremental against a stale watermark, restoring
                    // nothing.
                    if signedIn {
                        Task {
                            await syncEngine?.resetWatermark()
                            await runSync()
                            await uploadDeviceToken()
                        }
                    } else {
                        pushCenter.reset()
                    }
                }
                .fullScreenCover(isPresented: Binding(
                    get: { !hasOnboarded },
                    set: { presented in if !presented { hasOnboarded = true } }
                )) {
                    OnboardingView()
                        .environment(router)
                }
        }
    }

    /// Build the SyncEngine once the composition root is available. The engine
    /// owns the push/pull cycle; stores only mark entities dirty on mutation.
    private func wireSyncEngine() {
        syncEngine = SyncEngine(
            transport: environment.sync,
            persistence: persistence,
            identification: environment.identification
        )
    }

    /// Run a sync cycle (push dirty + pull incremental + LWW apply), then
    /// refresh the stores' in-memory arrays from SwiftData. No-op when signed
    /// out or when no backend is configured (NoOpSyncService → empty pulls).
    private func runSync() async {
        guard let syncEngine else { return }
        await syncEngine.sync()
        store.refresh()
        watchlist.refresh()
        wishlist.refresh()
        subscriptions.refresh()
        updateWidget()
    }

    /// Fire local notifications for any watched card that just reached its target
    /// price (best-effort; no-op until the user grants notification permission).
    private func evaluatePriceAlerts() async {
        await NotificationService.shared.evaluate(
            alerts: watchlist.alerts,
            market: marketStore,
            name: { SampleData.card(id: $0)?.name ?? "Your card" }
        )
    }

    /// Upload the APNs device token to the backend so the server can push price
    /// alerts while the app is closed. No-op until signed in + token received.
    private func uploadDeviceToken() async {
        guard environment.auth.isSignedIn else { return }
        await environment.auth.refreshIfNeeded()
        let jwt = environment.auth.session?.accessToken
        await pushCenter.upload(endpoint: AppConfig.supabase?.registerDeviceURL, jwt: jwt)
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
