import Testing
import Foundation
import SwiftData
@testable import Carddex

/// SyncEngine correctness tests — the plan's testing priority #3: conflict
/// resolution (last-write-wins) + tombstone propagation. These exercise the
/// engine against a `FakeSyncService` transport and an in-memory
/// `PersistenceController`, asserting the push/pull/LWW/tombstone cycle without
/// any network.
@MainActor
@Suite struct SyncEngineTests {
    private func makeEngine(transport: FakeSyncService = FakeSyncService()) -> (SyncEngine, PersistenceController, FakeSyncService) {
        let controller = PersistenceController.forTesting()
        // Use a unique UserDefaults suite per test so lastSyncAt is isolated.
        let defaults = UserDefaults(suiteName: "sync-engine-test-\(UUID().uuidString)")!
        let engine = SyncEngine(
            transport: transport,
            persistence: controller,
            identification: nil,
            defaults: defaults
        )
        return (engine, controller, transport)
    }

    // MARK: - Push

    @Test func pushDirtyCollectionItemsSendsDTOsAndMarksClean() async {
        let (engine, controller, transport) = makeEngine()
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)
        store.add(SampleData.jordan)

        await engine.sync()

        #expect(transport.pushedCollectionItems.count == 2)
        #expect(transport.pushedCollectionItems.contains { $0.card_id == SampleData.charizard.id })
        #expect(transport.pushedCollectionItems.contains { $0.card_id == SampleData.jordan.id })

        // Dirty entities are now clean + stamped.
        let entities = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>())) ?? []
        #expect(entities.allSatisfy { !$0.dirty })
        #expect(entities.allSatisfy { $0.remoteUpdatedAt != nil })
    }

    @Test func pushTombstonedItemCarriesDeletedAt() async {
        let (engine, controller, transport) = makeEngine()
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)
        guard let item = store.items.first else { Issue.record("not added"); return }
        store.remove(item)  // tombstone + dirty

        await engine.sync()

        #expect(transport.pushedCollectionItems.count == 1)
        #expect(transport.pushedCollectionItems.first?.deleted_at != nil)
    }

    @Test func pushSkipsCleanEntities() async {
        let (engine, controller, transport) = makeEngine()
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)

        await engine.sync()
        transport.resetDTORecordings()

        // Second cycle with no new mutations → no pushes.
        await engine.sync()
        #expect(transport.pushedCollectionItems.isEmpty)
    }

    @Test func pushDirtyAlertsAndGrails() async {
        let (engine, controller, transport) = makeEngine()
        let watchlist = WatchlistStore(persistence: controller)
        watchlist.setAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000))
        let wishlist = WishlistStore(persistence: controller)
        wishlist.add(cardID: SampleData.charizard.id, target: Money(amount: 250))

        await engine.sync()

        #expect(transport.pushedPriceAlerts.count == 1)
        #expect(transport.pushedPriceAlerts.first?.card_id == SampleData.jordan.id)
        #expect(transport.pushedGrailEntries.count == 1)
        #expect(transport.pushedGrailEntries.first?.card_id == SampleData.charizard.id)
    }

    // MARK: - Pull + LWW

    @Test func pullInsertsNewRemoteItem() async {
        let transport = FakeSyncService()
        let (engine, controller, _) = makeEngine(transport: transport)

        let cardDTO = CardDTO(id: SampleData.jordan.id, game: "sports",
                              name: SampleData.jordan.name, set_name: SampleData.jordan.setName,
                              number: SampleData.jordan.number, rarity: nil, image_url: nil,
                              market_price: nil, sport: nil)
        transport.remoteChanges = RemoteChanges(
            collectionItems: [CollectionItemDTO(
                id: UUID(), card_id: SampleData.jordan.id, quantity: 1,
                condition: "Near Mint", purchase_price: nil, currency: nil,
                date_added: .now, updated_at: .now, deleted_at: nil, card: cardDTO
            )],
            priceAlerts: [], wishlistEntries: [], subscription: nil
        )

        await engine.sync()

        let store = CollectionStore(items: [], persistence: controller)
        #expect(store.items.count == 1)
        #expect(store.items.first?.card.id == SampleData.jordan.id)
    }

    @Test func pullLWWRemoteNewerOverwritesLocal() async {
        let transport = FakeSyncService()
        let (engine, controller, _) = makeEngine(transport: transport)

        // Local item with quantity 1, stamped at t0.
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)
        await engine.sync()  // push → stamps remoteUpdatedAt = t0

        // Remote arrives with a newer updated_at and quantity 5.
        let localEntity = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>()))?.first
        let newerTimestamp = (localEntity?.remoteUpdatedAt ?? .now).addingTimeInterval(60)
        let cardDTO = CardDTO(id: SampleData.charizard.id, game: "pokemon",
                              name: SampleData.charizard.name, set_name: SampleData.charizard.setName,
                              number: SampleData.charizard.number, rarity: nil, image_url: nil,
                              market_price: nil, sport: nil)
        let existingID = localEntity?.id ?? UUID()
        transport.remoteChanges = RemoteChanges(
            collectionItems: [CollectionItemDTO(
                id: existingID, card_id: SampleData.charizard.id, quantity: 5,
                condition: "Near Mint", purchase_price: nil, currency: nil,
                date_added: .now, updated_at: newerTimestamp, deleted_at: nil, card: cardDTO
            )],
            priceAlerts: [], wishlistEntries: [], subscription: nil
        )

        await engine.sync()

        // The remote (newer) wins → quantity updated to 5.
        let reloaded = CollectionStore(items: [], persistence: controller)
        #expect(reloaded.items.first?.quantity == 5)
    }

    @Test func pullLWWStaleRemoteIsIgnored() async {
        let transport = FakeSyncService()
        let (engine, controller, _) = makeEngine(transport: transport)

        // Local item stamped at t0.
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)
        await engine.sync()
        let localEntity = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>()))?.first
        let localStamp = localEntity?.remoteUpdatedAt ?? .now

        // Remote arrives with an OLDER timestamp and different quantity.
        let cardDTO = CardDTO(id: SampleData.charizard.id, game: "pokemon",
                              name: SampleData.charizard.name, set_name: SampleData.charizard.setName,
                              number: SampleData.charizard.number, rarity: nil, image_url: nil,
                              market_price: nil, sport: nil)
        transport.remoteChanges = RemoteChanges(
            collectionItems: [CollectionItemDTO(
                id: localEntity?.id ?? UUID(), card_id: SampleData.charizard.id, quantity: 99,
                condition: "Near Mint", purchase_price: nil, currency: nil,
                date_added: .now, updated_at: localStamp.addingTimeInterval(-120),
                deleted_at: nil, card: cardDTO
            )],
            priceAlerts: [], wishlistEntries: [], subscription: nil
        )

        await engine.sync()

        // Stale remote ignored → quantity stays at 1 (the local value).
        let reloaded = CollectionStore(items: [], persistence: controller)
        #expect(reloaded.items.first?.quantity == 1)
    }

    // MARK: - Tombstone propagation

    @Test func pullTombstoneRemovesItemFromLiveSet() async {
        let transport = FakeSyncService()
        let (engine, controller, _) = makeEngine(transport: transport)

        // Seed a local item.
        let store = CollectionStore(items: [], persistence: controller)
        store.add(SampleData.charizard)
        await engine.sync()
        let localEntity = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>()))?.first
        let id = localEntity?.id ?? UUID()

        // Remote says it was deleted.
        transport.remoteChanges = RemoteChanges(
            collectionItems: [CollectionItemDTO(
                id: id, card_id: SampleData.charizard.id, quantity: 1,
                condition: "Near Mint", purchase_price: nil, currency: nil,
                date_added: .now, updated_at: .now, deleted_at: .now, card: nil
            )],
            priceAlerts: [], wishlistEntries: [], subscription: nil
        )

        await engine.sync()

        // The live set no longer contains it.
        let reloaded = CollectionStore(items: [], persistence: controller)
        #expect(reloaded.items.isEmpty)

        // The entity is tombstoned (still present, deletedAt set).
        let entities = (try? controller.context.fetch(FetchDescriptor<CollectionItemEntity>())) ?? []
        #expect(entities.count == 1)
        #expect(entities.first?.deletedAt != nil)
    }

    @Test func pullTombstoneForAlertPropagates() async {
        let transport = FakeSyncService()
        let (engine, controller, _) = makeEngine(transport: transport)

        let watchlist = WatchlistStore(persistence: controller)
        watchlist.setAlert(cardID: "c1", target: Money(amount: 500))
        await engine.sync()

        transport.remoteChanges = RemoteChanges(
            collectionItems: [],
            priceAlerts: [PriceAlertDTO(id: nil, card_id: "c1", target_price: nil,
                                        updated_at: .now, deleted_at: .now)],
            wishlistEntries: [], subscription: nil
        )
        await engine.sync()

        let reloaded = WatchlistStore(persistence: controller)
        #expect(reloaded.alerts.isEmpty)
    }

    @Test func pullTombstoneForGrailPropagates() async {
        let transport = FakeSyncService()
        let (engine, controller, _) = makeEngine(transport: transport)

        let wishlist = WishlistStore(persistence: controller)
        wishlist.add(cardID: "c1", target: Money(amount: 250))
        await engine.sync()

        transport.remoteChanges = RemoteChanges(
            collectionItems: [], priceAlerts: [],
            wishlistEntries: [GrailEntryDTO(id: nil, card_id: "c1", target: nil,
                                            note: nil, date_added: .now,
                                            updated_at: .now, deleted_at: .now)],
            subscription: nil
        )
        await engine.sync()

        let reloaded = WishlistStore(persistence: controller)
        #expect(reloaded.grails.isEmpty)
    }

    // MARK: - Watermark

    @Test func pullAdvancesWatermarkAfterSuccess() async {
        let transport = FakeSyncService()
        let (engine, _, _) = makeEngine(transport: transport)

        #expect(await engine.lastSyncAt == nil)  // full pull first
        await engine.sync()
        let firstStamp = await engine.lastSyncAt
        #expect(firstStamp != nil)

        try? await Task.sleep(for: .milliseconds(10))
        await engine.sync()
        let secondStamp = await engine.lastSyncAt
        #expect(secondStamp! > firstStamp!)
    }

    @Test func pullPassesSinceArgForIncrementalPull() async {
        let transport = FakeSyncService()
        let (engine, _, _) = makeEngine(transport: transport)

        await engine.sync()
        #expect(transport.pullSinceArgs.count == 1)
        #expect(transport.pullSinceArgs[0] == nil)  // first pull = full

        await engine.sync()
        #expect(transport.pullSinceArgs.count == 2)
        #expect(transport.pullSinceArgs[1] != nil)  // subsequent = incremental
    }

    @Test func pullFailureDoesNotAdvanceWatermark() async {
        let transport = FakeSyncService()
        let (engine, _, _) = makeEngine(transport: transport)

        await engine.sync()
        let stamp = await engine.lastSyncAt
        #expect(stamp != nil)

        // Make the next pull fail.
        transport.shouldFail = true
        await engine.sync()
        // Watermark unchanged → next successful cycle retries from the same point.
        #expect(await engine.lastSyncAt == stamp)
    }

    @Test func resetWatermarkForcesFullPull() async {
        let transport = FakeSyncService()
        let (engine, _, _) = makeEngine(transport: transport)

        await engine.sync()
        #expect(transport.pullSinceArgs[0] == nil)  // first pull = full

        await engine.sync()
        #expect(transport.pullSinceArgs[1] != nil)  // second = incremental

        await engine.resetWatermark()
        await engine.sync()
        #expect(transport.pullSinceArgs[2] == nil)  // full pull again after reset
    }

    /// Mirrors the CarddexApp sign-in path on a new device/reinstall: after a
    /// prior incremental watermark exists, `resetWatermark()` must precede the
    /// pull so the account is restored via a FULL pull. Guards the ordering fix
    /// in `CarddexApp.onChange(of: isSignedIn)`.
    @Test func resetThenSyncRestoresCollectionOnNewDevice() async {
        let transport = FakeSyncService()
        let (engine, controller, _) = makeEngine(transport: transport)

        // Establish a non-nil watermark (as if this install had synced before).
        await engine.sync()
        #expect(transport.pullSinceArgs[0] == nil)  // first pull = full

        // Remote now holds the user's collection; the local device is empty.
        let cardDTO = CardDTO(id: SampleData.jordan.id, game: "sports",
                              name: SampleData.jordan.name, set_name: SampleData.jordan.setName,
                              number: SampleData.jordan.number, rarity: nil, image_url: nil,
                              market_price: nil, sport: nil)
        transport.remoteChanges = RemoteChanges(
            collectionItems: [CollectionItemDTO(
                id: UUID(), card_id: SampleData.jordan.id, quantity: 1,
                condition: "Near Mint", purchase_price: nil, currency: nil,
                date_added: .now, updated_at: .now, deleted_at: nil, card: cardDTO
            )],
            priceAlerts: [], wishlistEntries: [], subscription: nil
        )

        // Sign-in sequence: reset (full pull) THEN sync.
        await engine.resetWatermark()
        await engine.sync()

        #expect(transport.pullSinceArgs[1] == nil)  // restore pull was full, not incremental
        let store = CollectionStore(items: [], persistence: controller)
        #expect(store.items.count == 1)
        #expect(store.items.first?.card.id == SampleData.jordan.id)
    }

    // MARK: - Pending scan replay

    @Test func pendingScanReplayedAndDeletedOnSuccess() async {
        let identification = FakeIdentificationService()
        let transport = FakeSyncService()
        let controller = PersistenceController.forTesting()
        let defaults = UserDefaults(suiteName: "pending-\(UUID().uuidString)")!
        let engine = SyncEngine(
            transport: transport, persistence: controller,
            identification: identification, defaults: defaults
        )

        await engine.enqueuePendingScan(ScanInput(imageData: Data(), ocrText: ["Charizard"], gameHint: .pokemon))
        let beforeCount = (try? controller.context.fetch(FetchDescriptor<PendingScanEntity>()))?.count ?? 0
        #expect(beforeCount == 1)

        await engine.sync()

        let afterCount = (try? controller.context.fetch(FetchDescriptor<PendingScanEntity>()))?.count ?? 0
        #expect(afterCount == 0)  // replayed successfully → deleted
    }

    @Test func pendingScanRetainedOnIdentificationFailure() async {
        // FakeIdentificationService always succeeds, so use a throwing service.
        struct ThrowingID: IdentificationService {
            func identify(_ input: ScanInput) async throws -> IdentificationOutcome {
                throw IdentificationError.server("vision down")
            }
            func searchCatalog(query: String, gameHint: CardGame?) async throws -> [IdentificationCandidate] { [] }
        }
        let transport = FakeSyncService()
        let controller = PersistenceController.forTesting()
        let defaults = UserDefaults(suiteName: "pending-fail-\(UUID().uuidString)")!
        let engine = SyncEngine(
            transport: transport, persistence: controller,
            identification: ThrowingID(), defaults: defaults
        )

        await engine.enqueuePendingScan(ScanInput(imageData: Data(), ocrText: ["x"], gameHint: nil))
        await engine.sync()

        let afterCount = (try? controller.context.fetch(FetchDescriptor<PendingScanEntity>()))?.count ?? 0
        #expect(afterCount == 1)  // retained for next cycle
    }
}
