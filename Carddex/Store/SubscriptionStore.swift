import SwiftUI
import Observation
import SwiftData

/// Tracks Carddex Pro entitlement + the free scan quota. Backed by SwiftData
/// as a 1:1 singleton row; keeps the same in-memory surface views use.
@MainActor
@Observable
final class SubscriptionStore {
    var isPro: Bool = false
    var scansThisMonth: Int = 0
    let freeScanLimit = 25
    private let persistence: PersistenceController?
    var sync: (any SyncServiceProtocol)? = nil

    /// Codable state snapshot persisted to disk. Internal so the one-time
    /// Disk→SwiftData migration can read the legacy file.
    struct State: Codable {
        var isPro: Bool
        var scansThisMonth: Int
    }

    /// `persistence` enables SwiftData-backed persistence (production). Pass
    /// nil for previews/tests to stay purely in-memory.
    init(persistence: PersistenceController? = nil, sync: (any SyncServiceProtocol)? = nil) {
        self.persistence = persistence
        self.sync = sync
        if let persistence {
            // Load the singleton row if present.
            if let entity = (try? persistence.context.fetch(FetchDescriptor<SubscriptionEntity>()))?.first {
                self.isPro = entity.isPro
                self.scansThisMonth = entity.scansThisMonth
            }
        }
    }

    var remainingFreeScans: Int { max(0, freeScanLimit - scansThisMonth) }
    var canScan: Bool { isPro || scansThisMonth < freeScanLimit }

    func recordScan() {
        if !isPro { scansThisMonth += 1; save(); syncState() }
    }

    /// Stub — replaced by a verified StoreKit 2 transaction at go-live.
    func activatePro() {
        isPro = true
        save()
        syncState()
    }

    /// Apply remote subscription state from a pull (e.g. entitlement verified
    /// on the server). Does NOT trigger a sync push (the state came from remote).
    func applyRemote(_ state: SubscriptionStateDTO) {
        isPro = state.isPro
        scansThisMonth = state.scansThisMonth
        upsertEntity(state, dirty: false)
        save()
    }

    /// Clear all local state and persist the empty snapshot. Used after a
    /// successful account deletion so a re-launch doesn't restore wiped data.
    func wipeLocal() {
        isPro = false
        scansThisMonth = 0
        if let persistence {
            let all = (try? persistence.context.fetch(FetchDescriptor<SubscriptionEntity>())) ?? []
            for entity in all { persistence.context.delete(entity) }
            persistence.save()
        }
    }

    private func syncState() {
        guard let sync else { return }
        let dto = SubscriptionStateDTO(isPro: isPro, scansThisMonth: scansThisMonth)
        Task { try? await sync.upsertSubscriptionState(dto) }
    }

    private func save() {
        upsertEntity(SubscriptionStateDTO(isPro: isPro, scansThisMonth: scansThisMonth), dirty: true)
        persistence?.save()
    }

    private func upsertEntity(_ state: SubscriptionStateDTO, dirty: Bool) {
        guard let persistence else { return }
        let ctx = persistence.context
        let existing = (try? ctx.fetch(FetchDescriptor<SubscriptionEntity>()))?.first
        if let existing {
            existing.isPro = state.isPro
            existing.scansThisMonth = state.scansThisMonth
            existing.dirty = dirty
        } else {
            let entity = SubscriptionEntity.insert(from: state, into: ctx)
            entity.dirty = dirty
        }
    }
}
