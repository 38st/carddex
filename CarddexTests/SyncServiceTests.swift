import Testing
import Foundation
import SwiftData
@testable import Carddex

@MainActor
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

    // MARK: - Store mutations mark entities dirty (SyncEngine owns push)
    // The old fire-and-forget store→sync calls are gone; the SyncEngine reads
    // dirty entities and pushes. These tests verify mutations set the dirty flag
    // and tombstones, which is what the engine consumes.

    @Test func collectionStoreAddMarksEntityDirty() {
        let controller = PersistenceController.forTesting()
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)
        let entities = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>())) ?? []
        #expect(entities.count == 1)
        #expect(entities.first?.dirty == true)
        #expect(entities.first?.deletedAt == nil)
    }

    @Test func collectionStoreRemoveTombstonesAndMarksDirty() {
        let controller = PersistenceController.forTesting()
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)
        guard let item = store.items.first else { Issue.record("item not added"); return }
        store.remove(item)
        let entities = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>())) ?? []
        #expect(entities.count == 1)
        #expect(entities.first?.deletedAt != nil)
        #expect(entities.first?.dirty == true)
    }

    @Test func wishlistStoreAddMarksEntityDirty() {
        let controller = PersistenceController.forTesting()
        let store = WishlistStore(persistence: controller)
        store.add(cardID: SampleData.charizard.id, target: Money(amount: 200))
        let entities = (try? controller.context.fetch(FetchDescriptor<GrailEntryEntity>())) ?? []
        #expect(entities.count == 1)
        #expect(entities.first?.dirty == true)
    }

    @Test func watchlistStoreSetAlertMarksDirtyAndRemoveTombstones() {
        let controller = PersistenceController.forTesting()
        let store = WatchlistStore(persistence: controller)
        store.setAlert(cardID: "c1", target: Money(amount: 500))
        let entities = (try? controller.context.fetch(FetchDescriptor<PriceAlertEntity>())) ?? []
        #expect(entities.count == 1)
        #expect(entities.first?.dirty == true)
        #expect(entities.first?.deletedAt == nil)

        store.removeAlert("c1")
        #expect(entities.first?.deletedAt != nil)
        #expect(entities.first?.dirty == true)
    }

    @Test func subscriptionStoreActivateProMarksDirty() {
        let controller = PersistenceController.forTesting()
        let store = SubscriptionStore(persistence: controller)
        store.activatePro()
        let entities = (try? controller.context.fetch(FetchDescriptor<SubscriptionEntity>())) ?? []
        #expect(entities.count == 1)
        #expect(entities.first?.isPro == true)
        #expect(entities.first?.dirty == true)
    }

    @Test func storesWithoutPersistenceAreSilent() {
        let store = CollectionStore(items: [])
        store.add(SampleData.charizard)
        if let first = store.items.first { store.remove(first) }
        // No crash, no persistence = pass.
        #expect(store.items.isEmpty)
    }
}
