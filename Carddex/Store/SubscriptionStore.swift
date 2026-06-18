import SwiftUI

/// Tracks Carddex Pro entitlement + the free scan quota. In-memory for now;
/// wired to StoreKit 2 + the Supabase `subscriptions` table at go-live.
@Observable
final class SubscriptionStore {
    var isPro: Bool = false
    var scansThisMonth: Int = 0
    let freeScanLimit = 25
    private let persistKey: String?
    var sync: (any SyncServiceProtocol)? = nil

    private struct State: Codable {
        var isPro: Bool
        var scansThisMonth: Int
    }

    /// `persistKey` enables Codable-to-disk persistence (production). Pass nil for
    /// previews/tests to stay purely in-memory. `sync` mirrors entitlement/usage
    /// to Supabase; nil = local-only.
    init(persistKey: String? = nil, sync: (any SyncServiceProtocol)? = nil) {
        self.persistKey = persistKey
        self.sync = sync
        if let persistKey, let saved = Disk.load(State.self, from: persistKey) {
            self.isPro = saved.isPro
            self.scansThisMonth = saved.scansThisMonth
        }
    }

    var remainingFreeScans: Int { max(0, freeScanLimit - scansThisMonth) }
    var canScan: Bool { isPro || scansThisMonth < freeScanLimit }

    func recordScan() {
        if !isPro { scansThisMonth += 1; persist(); syncState() }
    }

    /// Stub — replaced by a verified StoreKit 2 transaction at go-live.
    func activatePro() {
        isPro = true
        persist()
        syncState()
    }

    /// Apply remote subscription state from a pull (e.g. entitlement verified
    /// on the server). Does NOT trigger a sync push (the state came from remote).
    func applyRemote(_ state: SubscriptionStateDTO) {
        isPro = state.isPro
        scansThisMonth = state.scansThisMonth
        persist()
    }

    private func syncState() {
        guard let sync else { return }
        let dto = SubscriptionStateDTO(isPro: isPro, scansThisMonth: scansThisMonth)
        Task { try? await sync.upsertSubscriptionState(dto) }
    }

    private func persist() {
        if let persistKey { Disk.save(State(isPro: isPro, scansThisMonth: scansThisMonth), to: persistKey) }
    }
}
