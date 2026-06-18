import Foundation
import StoreKit

/// StoreKit 2 seam — protocol so the app can inject a fake in previews/tests
/// where real `Product`/`Transaction` types can't be constructed.
protocol StoreKitServiceProtocol: Sendable {
    /// Fetch available subscription products from App Store Connect.
    func fetchProducts() async throws -> [Product]
    /// Initiate a purchase. Returns the verified transaction on success, nil on
    /// user-cancel / pending.
    func purchase(_ product: Product) async throws -> Transaction?
    /// Check whether the user has an active Pro entitlement by iterating
    /// currentEntitlements. Called on app launch.
    func verifyEntitlement() async -> Bool
}

/// Real StoreKit 2 service. Product IDs are set in App Store Connect:
///   `com.carddex.pro.monthly`  — $6.99/mo
///   `com.carddex.pro.annual`   — $39.99/yr (7-day free trial)
struct StoreKitService: StoreKitServiceProtocol {
    let productIDs: Set<String> = [
        "com.carddex.pro.monthly",
        "com.carddex.pro.annual",
    ]

    func fetchProducts() async throws -> [Product] {
        let products = try await Product.products(for: productIDs)
        return products.sorted { $0.price < $1.price } // monthly first, annual second
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            // JWS verification — StoreKit 2 signs transactions; verify before trusting.
            let transaction = try verification.payloadValue
            await transaction.finish() // acknowledge delivery to Apple
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func verifyEntitlement() async -> Bool {
        // Iterate all current entitlements. If any active (non-revoked, non-expired)
        // transaction matches our product IDs, the user is Pro.
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                guard productIDs.contains(transaction.productID) else { continue }
                let notRevoked = transaction.revocationDate == nil
                let notExpired = (transaction.expirationDate ?? .distantFuture) > Date()
                if notRevoked && notExpired {
                    return true
                }
            }
        }
        return false
    }
}

/// No-op StoreKit service — used in previews/tests and when no backend is
/// configured. Returns no products, no purchases, no entitlement.
struct NoOpStoreKitService: StoreKitServiceProtocol {
    func fetchProducts() async throws -> [Product] { [] }
    func purchase(_ product: Product) async throws -> Transaction? { nil }
    func verifyEntitlement() async -> Bool { false }
}
