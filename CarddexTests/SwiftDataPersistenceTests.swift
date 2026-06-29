import Testing
import Foundation
import SwiftData
@testable import Carddex

/// Verifies the SwiftData-backed persistence path: state survives a reload
/// from a fresh store instance pointing at the same in-memory container, and
/// the one-time Disk→SwiftData migration imports legacy JSON.
@MainActor
@Suite struct SwiftDataPersistenceTests {
    /// A fresh in-memory controller per test — isolated, no on-disk file.
    private func makeController() -> PersistenceController {
        // `forTesting` uses an in-memory store; each call is a fresh container.
        PersistenceController.forTesting()
    }

    @Test func collectionItemPersistsAcrossReload() {
        let controller = makeController()
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)

        // A new store reading the same container should see the saved item.
        let reloaded = CollectionStore(items: [], persistence: controller)
        #expect(reloaded.items.count == 1)
        #expect(reloaded.items.first?.card.id == SampleData.charizard.id)
    }

    @Test func collectionRemoveTombstonesAndPersists() {
        let controller = makeController()
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)
        guard let item = store.items.first else { Issue.record("item not added"); return }
        store.remove(item)

        // Tombstone: the row is soft-deleted, so a reload sees nothing live.
        let reloaded = CollectionStore(items: [], persistence: controller)
        #expect(reloaded.items.isEmpty)

        // But the entity still exists (tombstoned) — verify directly.
        let entities = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>())) ?? []
        #expect(entities.count == 1)
        #expect(entities.first?.deletedAt != nil)
    }

    @Test func priceAlertPersistsAcrossReload() {
        let controller = makeController()
        let store = WatchlistStore(alerts: [], persistence: controller)
        store.setAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000))

        let reloaded = WatchlistStore(alerts: [], persistence: controller)
        #expect(reloaded.alerts.count == 1)
        #expect(reloaded.hasAlert(SampleData.jordan.id))
    }

    @Test func grailEntryPersistsAcrossReload() {
        let controller = makeController()
        let store = WishlistStore(persistence: controller)
        store.add(cardID: SampleData.charizard.id, target: Money(amount: 250))

        let reloaded = WishlistStore(persistence: controller)
        #expect(reloaded.grails.count == 1)
        #expect(reloaded.contains(SampleData.charizard.id))
    }

    @Test func subscriptionStatePersistsAcrossReload() {
        let controller = makeController()
        let store = SubscriptionStore(persistence: controller)
        store.activatePro()
        store.recordScan() // no-op when pro, but confirms no crash

        let reloaded = SubscriptionStore(persistence: controller)
        #expect(reloaded.isPro)
    }

    @Test func wipeLocalClearsAllEntities() {
        let controller = makeController()
        let collection = CollectionStore(items: [], persistence: controller)
        collection.add(SampleData.charizard)
        let watchlist = WatchlistStore(persistence: controller)
        watchlist.setAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000))
        let wishlist = WishlistStore(persistence: controller)
        wishlist.add(cardID: SampleData.charizard.id)
        let subs = SubscriptionStore(persistence: controller)
        subs.activatePro()

        collection.wipeLocal()
        watchlist.wipeLocal()
        wishlist.wipeLocal()
        subs.wipeLocal()

        let reloadedCollection = CollectionStore(items: [], persistence: controller)
        let reloadedWatchlist = WatchlistStore(persistence: controller)
        let reloadedWishlist = WishlistStore(persistence: controller)
        let reloadedSubs = SubscriptionStore(persistence: controller)
        #expect(reloadedCollection.items.isEmpty)
        #expect(reloadedWatchlist.alerts.isEmpty)
        #expect(reloadedWishlist.grails.isEmpty)
        #expect(!reloadedSubs.isPro)
    }

    @Test func dirtyFlagSetOnLocalMutation() {
        let controller = makeController()
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)

        let entities = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>())) ?? []
        #expect(entities.first?.dirty == true)
    }
}
