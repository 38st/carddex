import Foundation
import SwiftData
import os

/// The sync orchestrator. Replaces the per-store fire-and-forget upserts with
/// a single engine that owns the push/pull cycle:
///
/// 1. **Push** dirty entities (local mutations + tombstones) → DTOs → transport.
///    On success, marks them clean (`dirty = false`) and stamps `remoteUpdatedAt`.
/// 2. **Pull** incrementally (`updated_at > lastSync`) → `RemoteChanges`.
/// 3. **Apply LWW** into SwiftData: for each remote row, compare its `updated_at`
///    against the entity's stored `remoteUpdatedAt`. Newer remote wins; older
///    remote is ignored (local dirty state kept). Tombstones (`deleted_at`) are
///    applied as local tombstones + dropped from the live set.
/// 4. **Refresh** the stores' in-memory arrays from SwiftData.
/// 5. **Replay** `PendingScan`s (offline scan queue) — best-effort, one per cycle.
///
/// The engine is an actor so pushes/pulls are serialized and `lastSyncAt` is
/// race-free. It hops to `@MainActor` to read/write SwiftData entities (the
/// `ModelContext` is MainActor-isolated via `PersistenceController`).
actor SyncEngine {
    static let lastSyncKey = "sync.lastSyncAt"

    private let transport: any SyncServiceProtocol
    private let persistence: PersistenceController
    private let identification: (any IdentificationService)?
    private let logger = Logger(subsystem: "com.carddex.app", category: "sync-engine")
    private let defaults: UserDefaults

    init(
        transport: any SyncServiceProtocol,
        persistence: PersistenceController,
        identification: (any IdentificationService)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.transport = transport
        self.persistence = persistence
        self.identification = identification
        self.defaults = defaults
    }

    /// Last successful pull timestamp. Persisted in UserDefaults so incremental
    /// pull survives relaunch. Nil = full pull on first sync.
    var lastSyncAt: Date? {
        get { defaults.object(forKey: Self.lastSyncKey) as? Date }
        set { defaults.set(newValue, forKey: Self.lastSyncKey) }
    }

    /// Run one full push + pull + apply cycle. Throws on transport failure; in
    /// that case local dirty state is preserved and `lastSyncAt` is unchanged
    /// so the next cycle retries from the same point.
    func sync() async {
        do {
            try await pushDirty()
            try await pullAndApply()
        } catch {
            logger.error("sync cycle failed: \(String(describing: error), privacy: .public)")
        }
        // Pending-scan replay is independent of data sync; best-effort.
        await replayPendingScans()
    }

    // MARK: - Push

    private func pushDirty() async throws {
        try await pushDirtyCollection()
        try await pushDirtyAlerts()
        try await pushDirtyGrails()
        try await pushDirtySubscription()
    }

    @MainActor private func pushDirtyCollection() async throws {
        let dirty = (try? persistence.context.fetch(FetchDescriptor<CollectionItemEntity>(
            predicate: #Predicate { $0.dirty == true }
        ))) ?? []
        for entity in dirty {
            guard let card = entity.card else { continue }
            let price = entity.purchasePriceAmount.map {
                Money(amount: Decimal($0), currencyCode: entity.purchasePriceCurrency ?? "USD")
            }
            let item = CollectionItem(
                id: entity.id, card: card, quantity: entity.quantity,
                condition: CardCondition(rawValue: entity.conditionRaw) ?? .nearMint,
                dateAdded: entity.dateAdded, purchasePrice: price
            )
            let dto = CollectionItemDTO(
                id: item.id, card_id: card.id, quantity: item.quantity,
                condition: item.condition.rawValue,
                purchase_price: entity.purchasePriceAmount,
                currency: entity.purchasePriceCurrency,
                date_added: item.dateAdded,
                updated_at: entity.remoteUpdatedAt ?? .now,
                deleted_at: entity.deletedAt,
                card: nil  // push doesn't embed the card; the server joins by card_id
            )
            try await transport.pushCollectionItem(dto)
            entity.dirty = false
            entity.remoteUpdatedAt = .now
        }
        persistence.save()
    }

    @MainActor private func pushDirtyAlerts() async throws {
        let dirty = (try? persistence.context.fetch(FetchDescriptor<PriceAlertEntity>(
            predicate: #Predicate { $0.dirty == true }
        ))) ?? []
        for entity in dirty {
            let dto = PriceAlertDTO(
                id: nil, card_id: entity.cardID,
                target_price: entity.targetAmount,
                updated_at: entity.remoteUpdatedAt ?? .now,
                deleted_at: entity.deletedAt
            )
            try await transport.pushPriceAlert(dto)
            entity.dirty = false
            entity.remoteUpdatedAt = .now
        }
        persistence.save()
    }

    @MainActor private func pushDirtyGrails() async throws {
        let dirty = (try? persistence.context.fetch(FetchDescriptor<GrailEntryEntity>(
            predicate: #Predicate { $0.dirty == true }
        ))) ?? []
        for entity in dirty {
            let dto = GrailEntryDTO(
                id: nil, card_id: entity.cardID,
                target: entity.targetAmount, note: entity.note,
                date_added: entity.dateAdded,
                updated_at: entity.remoteUpdatedAt ?? .now,
                deleted_at: entity.deletedAt
            )
            try await transport.pushGrailEntry(dto)
            entity.dirty = false
            entity.remoteUpdatedAt = .now
        }
        persistence.save()
    }

    @MainActor private func pushDirtySubscription() async throws {
        let dirty = (try? persistence.context.fetch(FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.dirty == true }
        ))) ?? []
        guard let entity = dirty.first else { return }
        let dto = SubscriptionDTO(
            tier: entity.isPro ? "pro" : "free",
            updated_at: entity.remoteUpdatedAt ?? .now
        )
        try await transport.pushSubscription(dto)
        entity.dirty = false
        entity.remoteUpdatedAt = .now
        persistence.save()
    }

    // MARK: - Pull + LWW apply

    private func pullAndApply() async throws {
        let since = lastSyncAt
        let changes = try await transport.pullChanges(since: since)
        await applyChanges(changes)
        // Only advance the watermark after a successful apply.
        lastSyncAt = .now
    }

    /// Apply remote changes into SwiftData with last-write-wins. Hops to
    /// MainActor for entity access.
    @MainActor private func applyChanges(_ changes: RemoteChanges) async {
        for dto in changes.collectionItems { applyCollection(dto) }
        for dto in changes.priceAlerts { applyAlert(dto) }
        for dto in changes.wishlistEntries { applyGrail(dto) }
        if let sub = changes.subscription { applySubscription(sub) }
        persistence.save()
    }

    @MainActor private func applyCollection(_ dto: CollectionItemDTO) {
        let ctx = persistence.context
        let existing = (try? ctx.fetch(FetchDescriptor<CollectionItemEntity>(
            predicate: #Predicate { $0.id == dto.id }
        )))?.first

        // Tombstone: mark deleted locally regardless of LWW (a delete is terminal).
        if let deletedAt = dto.deleted_at {
            if let existing {
                existing.deletedAt = deletedAt
                existing.remoteUpdatedAt = dto.updated_at
                existing.dirty = false
            }
            return
        }

        // LWW: ignore stale remote (older than what we already have).
        if let existing, let remoteUpdated = dto.updated_at,
           let localRemoteUpdated = existing.remoteUpdatedAt,
           remoteUpdated <= localRemoteUpdated {
            return
        }

        guard let item = dto.toModel() else {
            // Card couldn't be reconstructed (join missing/parse fail). Leave
            // for a future cycle once card data is resolvable.
            logger.info("applyCollection: skipped \(dto.id, privacy: .public) — card unresolved")
            return
        }
        if let existing {
            existing.apply(from: item, remoteUpdatedAt: dto.updated_at, deletedAt: nil)
        } else {
            let entity = CollectionItemEntity.insert(from: item, into: ctx)
            entity.remoteUpdatedAt = dto.updated_at
            entity.dirty = false
        }
    }

    @MainActor private func applyAlert(_ dto: PriceAlertDTO) {
        let ctx = persistence.context
        let existing = (try? ctx.fetch(FetchDescriptor<PriceAlertEntity>(
            predicate: #Predicate { $0.cardID == dto.card_id }
        )))?.first

        if let deletedAt = dto.deleted_at {
            if let existing {
                existing.deletedAt = deletedAt
                existing.remoteUpdatedAt = dto.updated_at
                existing.dirty = false
            }
            return
        }
        if let existing, let remoteUpdated = dto.updated_at,
           let localRemoteUpdated = existing.remoteUpdatedAt,
           remoteUpdated <= localRemoteUpdated {
            return
        }
        let alert = dto.toModel()
        if let existing {
            existing.apply(from: alert, remoteUpdatedAt: dto.updated_at, deletedAt: nil)
        } else {
            let entity = PriceAlertEntity.insert(from: alert, into: ctx)
            entity.remoteUpdatedAt = dto.updated_at
            entity.dirty = false
        }
    }

    @MainActor private func applyGrail(_ dto: GrailEntryDTO) {
        let ctx = persistence.context
        let existing = (try? ctx.fetch(FetchDescriptor<GrailEntryEntity>(
            predicate: #Predicate { $0.cardID == dto.card_id }
        )))?.first

        if let deletedAt = dto.deleted_at {
            if let existing {
                existing.deletedAt = deletedAt
                existing.remoteUpdatedAt = dto.updated_at
                existing.dirty = false
            }
            return
        }
        if let existing, let remoteUpdated = dto.updated_at,
           let localRemoteUpdated = existing.remoteUpdatedAt,
           remoteUpdated <= localRemoteUpdated {
            return
        }
        let entry = dto.toModel()
        if let existing {
            existing.apply(from: entry, remoteUpdatedAt: dto.updated_at, deletedAt: nil)
        } else {
            let entity = GrailEntryEntity.insert(from: entry, into: ctx)
            entity.remoteUpdatedAt = dto.updated_at
            entity.dirty = false
        }
    }

    @MainActor private func applySubscription(_ dto: SubscriptionDTO) {
        let ctx = persistence.context
        let existing = (try? ctx.fetch(FetchDescriptor<SubscriptionEntity>()))?.first
        let state = dto.toDTO()
        if let existing {
            // LWW on the singleton.
            if let remoteUpdated = dto.updated_at,
               let localRemoteUpdated = existing.remoteUpdatedAt,
               remoteUpdated <= localRemoteUpdated {
                return
            }
            existing.apply(from: state, remoteUpdatedAt: dto.updated_at)
        } else {
            let entity = SubscriptionEntity.insert(from: state, into: ctx)
            entity.remoteUpdatedAt = dto.updated_at
            entity.dirty = false
        }
    }

    // MARK: - Pending scan replay

    /// Replay one queued offline scan. Called each cycle; on success the row is
    /// deleted. Failures leave the row for the next attempt.
    @MainActor private func replayPendingScans() async {
        guard let identification else { return }
        let pending = (try? persistence.context.fetch(FetchDescriptor<PendingScanEntity>())) ?? []
        guard let scan = pending.first else { return }
        let input = scan.toInput()
        do {
            _ = try await identification.identify(input)
            persistence.context.delete(scan)
            persistence.save()
            logger.info("replayed pending scan \(scan.id, privacy: .public)")
        } catch {
            logger.error("pending scan replay failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Queueing (called from the UI / stores)

    /// Enqueue a scan that couldn't complete (offline / transient failure) so
    /// it's retried on the next cycle. MainActor — the Scan flow calls this.
    @MainActor func enqueuePendingScan(_ input: ScanInput) {
        let entity = PendingScanEntity(
            imageData: input.imageData,
            ocrText: input.ocrText,
            gameHint: input.gameHint?.rawValue
        )
        persistence.context.insert(entity)
        persistence.save()
    }

    /// Drop the sync watermark so the next cycle does a full pull. Used after
    /// sign-in / account changes.
    func resetWatermark() {
        lastSyncAt = nil
    }
}
