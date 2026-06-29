import Testing
import Foundation
import SwiftData
@testable import Carddex

@MainActor
@Suite struct SyncServiceTests {
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
