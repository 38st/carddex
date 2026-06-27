import Foundation
import SwiftData
import os

/// Owns the `ModelContainer` and the one-time Disk JSON → SwiftData migration.
///
/// Production uses an on-disk store in the App Group container (so the store
/// data is shared with future extensions if needed). Tests/previews use an
/// in-memory store via `forTesting()`. The container is created once and
/// injected into stores the same way `Disk` was — stores keep their in-memory
/// array surface; they read/write through SwiftData behind it.
@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    /// Shared app-group container URL, matching the legacy `Disk` location so
    /// the on-disk store lives where the JSON files used to.
    static let appGroupID = Disk.appGroupID

    let container: ModelContainer

    /// The model context used by the stores. MainActor-isolated; SwiftData
    /// autosaves on significant changes.
    var context: ModelContext { container.mainContext }

    private static let logger = Logger(subsystem: "com.carddex.app", category: "persistence")

    private init(inMemory: Bool = false) {
        let schema = Schema([
            CollectionItemEntity.self,
            PriceAlertEntity.self,
            GrailEntryEntity.self,
            SubscriptionEntity.self,
            PendingScanEntity.self,
            PortfolioSnapshotEntity.self,
        ])
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Store in the App Group container if available (matches the old
            // `Disk` location), else Application Support. SwiftData creates the
            // `.store` file; we just point it at the right directory.
            let url = PersistenceController.storeURL()
            config = ModelConfiguration(schema: schema, url: url)
        }
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            Self.logger.error("ModelContainer init failed: \(String(describing: error), privacy: .public)")
            // Fall back to in-memory so a corrupt on-disk store never blocks launch.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // `try?` would shadow the container type; this is a last resort.
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }

        if !inMemory {
            migrateFromDiskIfNeeded()
        }
    }

    /// In-memory store for previews/tests — no on-disk file, no migration.
    static func forTesting() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    // MARK: - Disk → SwiftData one-time migration

    /// On first launch of the SwiftData build, read the legacy `Disk` JSON
    /// files, insert into SwiftData, then archive the JSON files so the
    /// migration never re-runs. Idempotent: a marker file gates the whole pass.
    private func migrateFromDiskIfNeeded() {
        let fm = FileManager.default
        guard let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
            ?? appSupportDir() else { return }

        let marker = dir.appendingPathComponent("swiftdata-migrated.marker")
        guard !fm.fileExists(atPath: marker.path) else { return }

        Self.logger.info("Migrating Disk JSON → SwiftData (one-time)…")
        let ctx = context

        // Each legacy file → its entity. Skip files that don't exist.
        if let items = Disk.load([CollectionItem].self, from: "collection.json") {
            for item in items where fetch(CollectionItemEntity.self, id: item.id) == nil {
                CollectionItemEntity.insert(from: item, into: ctx)
            }
        }
        if let state = Disk.load(WatchlistStore.State.self, from: "watchlist.json") {
            for alert in state.alerts where fetch(PriceAlertEntity.self, id: alert.cardID) == nil {
                PriceAlertEntity.insert(from: alert, into: ctx)
            }
        }
        if let grails = Disk.load([GrailEntry].self, from: "wishlist.json") {
            for entry in grails where fetch(GrailEntryEntity.self, id: entry.cardID) == nil {
                GrailEntryEntity.insert(from: entry, into: ctx)
            }
        }
        if let sub = Disk.load(SubscriptionStore.State.self, from: "subscription.json") {
            if fetch(SubscriptionEntity.self, id: "default") == nil {
                SubscriptionEntity.insert(
                    from: SubscriptionStateDTO(isPro: sub.isPro, scansThisMonth: sub.scansThisMonth),
                    into: ctx
                )
            }
        }

        // Mark migrated entities as clean (they came from disk, not a fresh
        // local mutation) so the SyncEngine doesn't push them all on first run.
        for entity in (try? ctx.fetch(FetchDescriptor<CollectionItemEntity>())) ?? [] { entity.dirty = false }
        for entity in (try? ctx.fetch(FetchDescriptor<PriceAlertEntity>())) ?? [] { entity.dirty = false }
        for entity in (try? ctx.fetch(FetchDescriptor<GrailEntryEntity>())) ?? [] { entity.dirty = false }
        for entity in (try? ctx.fetch(FetchDescriptor<SubscriptionEntity>())) ?? [] { entity.dirty = false }

        save()

        // Archive the legacy JSON files (move to a subfolder) and write the marker.
        let archive = dir.appendingPathComponent("legacy-disk-archive")
        try? fm.createDirectory(at: archive, withIntermediateDirectories: true)
        for name in ["collection.json", "watchlist.json", "wishlist.json", "subscription.json"] {
            let from = dir.appendingPathComponent(name)
            if fm.fileExists(atPath: from.path) {
                try? fm.moveItem(at: from, to: archive.appendingPathComponent(name))
            }
        }
        try? Data().write(to: marker)
        Self.logger.info("Migration complete; legacy JSON archived.")
    }

    // MARK: - Helpers

    /// Fetch an entity by its unique id property. SwiftData can't parameterize
    /// a generic id predicate cleanly, so we load (small, single-user tables)
    /// and filter in-memory. Callers pass the concrete id type.
    private func fetch<T: PersistentModel>(_ type: T.Type, id: AnyHashable) -> T? {
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        return all.first { entity in
            switch entity {
            case let e as CollectionItemEntity: (id as? UUID) == e.id
            case let e as PriceAlertEntity: (id as? String) == e.cardID
            case let e as GrailEntryEntity: (id as? String) == e.cardID
            case let e as SubscriptionEntity: (id as? String) == e.key
            default: false
            }
        }
    }

    func save() {
        guard context.hasChanges else { return }
        do { try context.save() } catch {
            Self.logger.error("SwiftData save failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func storeURL() -> URL {
        let fm = FileManager.default
        let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("Carddex.store")
    }

    private func appSupportDir() -> URL? {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
