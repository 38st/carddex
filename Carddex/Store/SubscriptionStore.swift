import SwiftUI

/// Tracks Carddex Pro entitlement + the free scan quota. In-memory for now;
/// wired to StoreKit 2 + the Supabase `subscriptions` table at go-live.
@Observable
final class SubscriptionStore {
    var isPro: Bool = false
    var scansThisMonth: Int = 0
    let freeScanLimit = 25

    var remainingFreeScans: Int { max(0, freeScanLimit - scansThisMonth) }
    var canScan: Bool { isPro || scansThisMonth < freeScanLimit }

    func recordScan() {
        if !isPro { scansThisMonth += 1 }
    }

    /// Stub — replaced by a verified StoreKit 2 transaction at go-live.
    func activatePro() {
        isPro = true
    }
}
