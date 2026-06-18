import Testing
import Foundation
@testable import Carddex

@MainActor
@Suite struct PullMergeTests {
    @Test func collectionMergeAddsRemoteItemsNotPresentLocally() {
        let localCharizard = CollectionItem(card: SampleData.charizard)
        let store = CollectionStore(items: [localCharizard])
        // The remote has the same local item (by id) — should be skipped — plus
        // a new Jordan item — should be added.
        let remote = [
            CollectionItem(card: SampleData.jordan),
            localCharizard, // same id as local — should be skipped
        ]
        store.mergeRemote(remote)
        #expect(store.items.count == 2)
        #expect(store.items.contains { $0.card.id == SampleData.jordan.id })
    }

    @Test func collectionMergeEmptyRemoteIsNoOp() {
        let store = CollectionStore(items: [CollectionItem(card: SampleData.charizard)])
        store.mergeRemote([])
        #expect(store.items.count == 1)
    }

    @Test func watchlistMergeAddsRemoteAlertsNotPresentLocally() {
        let store = WatchlistStore(
            alerts: [PriceAlert(cardID: SampleData.charizard.id, target: Money(amount: 200))]
        )
        let remote = [
            PriceAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000)),
            PriceAlert(cardID: SampleData.charizard.id, target: Money(amount: 999)), // already local
        ]
        store.mergeRemote(remote)
        #expect(store.alerts.count == 2)
        #expect(store.hasAlert(SampleData.jordan.id))
    }

    @Test func wishlistMergeAddsRemoteGrailsNotPresentLocally() {
        let store = WishlistStore(grails: [GrailEntry(cardID: SampleData.charizard.id)])
        let remote = [
            GrailEntry(cardID: SampleData.jordan.id, target: Money(amount: 80000)),
            GrailEntry(cardID: SampleData.charizard.id), // already local
        ]
        store.mergeRemote(remote)
        #expect(store.grails.count == 2)
        #expect(store.contains(SampleData.jordan.id))
    }

    @Test func subscriptionApplyRemoteSetsState() {
        let store = SubscriptionStore()
        #expect(!store.isPro)
        store.applyRemote(SubscriptionStateDTO(isPro: true, scansThisMonth: 15))
        #expect(store.isPro)
        #expect(store.scansThisMonth == 15)
    }

    @Test func fullPullFlowMergesIntoAllStores() async {
        let sync = FakeSyncService()
        let collection = CollectionStore(items: [], sync: sync)
        let watchlist = WatchlistStore(sync: sync)
        let wishlist = WishlistStore(sync: sync)
        let subs = SubscriptionStore(sync: sync)

        // Configure the remote state the fake will return.
        let remoteItems = [CollectionItem(card: SampleData.jordan)]
        let remoteAlerts = [PriceAlert(cardID: SampleData.brady.id, target: Money(amount: 60000))]
        let remoteGrails = [GrailEntry(cardID: SampleData.charizard.id, target: Money(amount: 250))]
        let remoteSub = SubscriptionStateDTO(isPro: true, scansThisMonth: 10)
        sync.remoteState = RemoteState(
            collectionItems: remoteItems,
            priceAlerts: remoteAlerts,
            wishlistEntries: remoteGrails,
            subscription: remoteSub
        )

        // Simulate the pull + merge that CarddexApp.pullRemoteState() does.
        let pulled = try? await sync.pullAll()
        #expect(pulled != nil)
        collection.mergeRemote(pulled!.collectionItems)
        watchlist.mergeRemote(pulled!.priceAlerts)
        wishlist.mergeRemote(pulled!.wishlistEntries)
        if let sub = pulled!.subscription { subs.applyRemote(sub) }

        #expect(collection.items.count == 1)
        #expect(collection.items.first?.card.id == SampleData.jordan.id)
        #expect(watchlist.hasAlert(SampleData.brady.id))
        #expect(wishlist.contains(SampleData.charizard.id))
        #expect(subs.isPro)
        #expect(subs.scansThisMonth == 10)
    }
}

@MainActor
@Suite struct StoreKitEntitlementTests {
    @Test func noOpStoreKitReturnsNoProductsAndNoEntitlement() async {
        let service = NoOpStoreKitService()
        let products = try? await service.fetchProducts()
        #expect(products?.isEmpty == true)
        let entitled = await service.verifyEntitlement()
        #expect(!entitled)
    }

    @Test func appEnvironmentProvidesStoreKitService() {
        let env = AppEnvironment(identification: FakeIdentificationService())
        // Without Secrets.plist, the environment uses NoOpStoreKitService.
        #expect(env.storeKit is NoOpStoreKitService)
    }
}
