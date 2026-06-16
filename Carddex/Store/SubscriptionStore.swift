import SwiftUI

/// Tracks Carddex Pro entitlement + the free scan quota. In-memory for now;
/// wired to StoreKit 2 + the Supabase `subscriptions` table at go-live.
@Observable
final class SubscriptionStore {
    var isPro: Bool = false
    var scansThisMonth: Int = 0
    let freeScanLimit = 25
    private let persistKey: String?

    private struct State: Codable {
        var isPro: Bool
        var scansThisMonth: Int
    }

    /// `persistKey` enables Codable-to-disk persistence (production). Pass nil for
    /// previews/tests to stay purely in-memory.
    init(persistKey: String? = nil) {
        self.persistKey = persistKey
        if let persistKey, let saved = Disk.load(State.self, from: persistKey) {
            self.isPro = saved.isPro
            self.scansThisMonth = saved.scansThisMonth
        }
    }

    var remainingFreeScans: Int { max(0, freeScanLimit - scansThisMonth) }
    var canScan: Bool { isPro || scansThisMonth < freeScanLimit }

    func recordScan() {
        if !isPro { scansThisMonth += 1; persist() }
    }

    /// Stub — replaced by a verified StoreKit 2 transaction at go-live.
    func activatePro() {
        isPro = true
        persist()
    }

    private func persist() {
        if let persistKey { Disk.save(State(isPro: isPro, scansThisMonth: scansThisMonth), to: persistKey) }
    }
}
