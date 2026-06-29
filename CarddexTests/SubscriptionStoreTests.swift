import Testing
import Foundation
@testable import Carddex

@MainActor
@Suite struct SubscriptionStoreTests {
    @Test func freshAccountCanScanUpToLimit() {
        let subs = SubscriptionStore()
        #expect(subs.canScan)
        #expect(subs.remainingFreeScans == subs.freeScanLimit)
        #expect(!subs.isPro)
    }

    @Test func recordScanIncrementsUsage() {
        let subs = SubscriptionStore()
        subs.recordScan()
        subs.recordScan()
        #expect(subs.scansThisMonth == 2)
        #expect(subs.remainingFreeScans == subs.freeScanLimit - 2)
        #expect(subs.canScan)
    }

    @Test func hittingLimitBlocksFurtherScans() {
        let subs = SubscriptionStore()
        for _ in 0..<subs.freeScanLimit { subs.recordScan() }
        #expect(!subs.canScan)
        #expect(subs.remainingFreeScans == 0)
    }

    @Test func recordScanIsNoOpWhenPro() {
        let subs = SubscriptionStore()
        subs.activatePro()
        #expect(subs.isPro)
        subs.recordScan()
        #expect(subs.scansThisMonth == 0)
        #expect(subs.canScan)
    }

    @Test func remainingFreeScansNeverGoesNegative() {
        let subs = SubscriptionStore()
        for _ in 0..<(subs.freeScanLimit + 5) { subs.recordScan() }
        #expect(subs.remainingFreeScans == 0)
    }
}

@MainActor
@Suite struct StoreKitEntitlementTests {
    @Test func noOpStoreKitReturnsNoProductsAndNoEntitlement() async {
        let service = NoOpStoreKitService()
        let products = try? await service.fetchProducts()
        #expect(products?.isEmpty == true)
        let entitled = await service.verifyEntitlement()
        #expect(!entitled)
    }

    @Test func appEnvironmentProvidesStoreKitService() {
        let env = AppEnvironment(identification: FakeIdentificationService())
        // Without Secrets.plist, the environment uses NoOpStoreKitService.
        #expect(env.storeKit is NoOpStoreKitService)
    }
}
