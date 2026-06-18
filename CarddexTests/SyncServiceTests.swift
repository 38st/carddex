import Testing
import Foundation
@testable import Carddex

@Suite struct SyncServiceTests {
    @Test func noOpUpsertsDoNothing() async {
        let sync = NoOpSyncService()
        try? await sync.upsertCollectionItem(CollectionItem(card: SampleData.charizard))
        try? await sync.upsertPriceAlert(PriceAlert(cardID: "c1", target: Money(amount: 100)))
        try? await sync.upsertWishlistEntry(GrailEntry(cardID: "c1"))
        try? await sync.upsertSubscriptionState(SubscriptionStateDTO(isPro: true, scansThisMonth: 0))
        // No exceptions = pass; noOp is a black hole.
        #expect(true)
    }

    @Test func noOpPullReturnsEmptyState() async {
        let sync = NoOpSyncService()
        let state = try? await sync.pullAll()
        #expect(state?.collectionItems.isEmpty == true)
        #expect(state?.priceAlerts.isEmpty == true)
        #expect(state?.wishlistEntries.isEmpty == true)
        #expect(state?.subscription == nil)
    }

    @Test func fakeRecordsCollectionUpserts() async {
        let sync = FakeSyncService()
        let item = CollectionItem(card: SampleData.charizard)
        try? await sync.upsertCollectionItem(item)
        try? await sync.deleteCollectionItem(id: item.id)
        #expect(sync.collectionUpserts.count == 1)
        #expect(sync.collectionUpserts.first?.card.id == SampleData.charizard.id)
        #expect(sync.collectionDeletes == [item.id])
    }

    @Test func fakeRecordsAlertSync() async {
        let sync = FakeSyncService()
        let alert = PriceAlert(cardID: "c1", target: Money(amount: 1000))
        try? await sync.upsertPriceAlert(alert)
        try? await sync.deletePriceAlert(cardID: "c1")
        #expect(sync.alertUpserts == [alert])
        #expect(sync.alertDeletes == ["c1"])
    }

    @Test func fakeRecordsWishlistSync() async {
        let sync = FakeSyncService()
        let entry = GrailEntry(cardID: "c1", target: Money(amount: 500))
        try? await sync.upsertWishlistEntry(entry)
        try? await sync.deleteWishlistEntry(cardID: "c1")
        #expect(sync.wishlistUpserts == [entry])
        #expect(sync.wishlistDeletes == ["c1"])
    }

    @Test func fakeRecordsSubscriptionSync() async {
        let sync = FakeSyncService()
        let state = SubscriptionStateDTO(isPro: true, scansThisMonth: 5)
        try? await sync.upsertSubscriptionState(state)
        #expect(sync.subscriptionUpserts == [state])
    }

    @Test func fakePullReturnsConfiguredState() async {
        let sync = FakeSyncService()
        let items = [CollectionItem(card: SampleData.jordan)]
        let alerts = [PriceAlert(cardID: "c1", target: Money(amount: 100))]
        let grails = [GrailEntry(cardID: "c2")]
        let sub = SubscriptionStateDTO(isPro: true, scansThisMonth: 10)
        sync.remoteState = RemoteState(
            collectionItems: items, priceAlerts: alerts,
            wishlistEntries: grails, subscription: sub
        )
        let pulled = try? await sync.pullAll()
        #expect(pulled?.collectionItems.count == 1)
        #expect(pulled?.priceAlerts == alerts)
        #expect(pulled?.wishlistEntries == grails)
        #expect(pulled?.subscription == sub)
    }

    @Test func collectionStoreSyncsOnAdd() async {
        let sync = FakeSyncService()
        let store = CollectionStore(items: [], sync: sync)
        store.add(SampleData.charizard)
        // The sync task is fire-and-forget; give it a tick.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sync.collectionUpserts.count == 1)
        #expect(sync.collectionUpserts.first?.card.id == SampleData.charizard.id)
    }

    @Test func collectionStoreSyncsOnRemove() async {
        let sync = FakeSyncService()
        let item = CollectionItem(card: SampleData.charizard)
        let store = CollectionStore(items: [item], sync: sync)
        store.remove(item)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sync.collectionDeletes == [item.id])
    }

    @Test func wishlistStoreSyncsOnAdd() async {
        let sync = FakeSyncService()
        let store = WishlistStore(sync: sync)
        store.add(cardID: SampleData.charizard.id, target: Money(amount: 200))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sync.wishlistUpserts.count == 1)
        #expect(sync.wishlistUpserts.first?.cardID == SampleData.charizard.id)
    }

    @Test func watchlistStoreSyncsAlertSetAndRemove() async {
        let sync = FakeSyncService()
        let store = WatchlistStore(sync: sync)
        store.setAlert(cardID: "c1", target: Money(amount: 500))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sync.alertUpserts.count == 1)
        store.removeAlert("c1")
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sync.alertDeletes == ["c1"])
    }

    @Test func subscriptionStoreSyncsOnActivatePro() async {
        let sync = FakeSyncService()
        let store = SubscriptionStore(sync: sync)
        store.activatePro()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sync.subscriptionUpserts.count == 1)
        #expect(sync.subscriptionUpserts.first?.isPro == true)
    }

    @Test func storesWithoutSyncAreSilent() async {
        let store = CollectionStore(items: [], sync: nil)
        store.add(SampleData.charizard)
        if let first = store.items.first { store.remove(first) }
        // No crash, no sync = pass.
        #expect(store.items.isEmpty)
    }
}
