import Testing
import Foundation
@testable import Carddex

@MainActor
@Suite struct EbayConnectionTests {
    private func fresh() -> EbayConnection {
        UserDefaults.standard.removeObject(forKey: "ebay.connected")
        return EbayConnection()
    }

    @Test func connectedDeepLinkMarksConnected() {
        let c = fresh()
        #expect(!c.isConnected)
        let consumed = c.handle(url: URL(string: "carddex://ebay/connected")!)
        #expect(consumed)
        #expect(c.isConnected)
        #expect(c.lastError == nil)
    }

    @Test func errorDeepLinkSurfacesMessage() {
        let c = fresh()
        let consumed = c.handle(url: URL(string: "carddex://ebay/error?msg=token%20exchange%20failed")!)
        #expect(consumed)
        #expect(!c.isConnected)
        #expect(c.lastError == "token exchange failed")
    }

    @Test func unrelatedURLIsIgnored() {
        let c = fresh()
        let consumed = c.handle(url: URL(string: "https://example.com/ebay/connected")!)
        #expect(!consumed)
        #expect(!c.isConnected)
    }
}

@Suite struct FakeEbayServiceTests {
    @Test func connectedFakePublishes() async throws {
        let svc = FakeEbayService(connected: true)
        let listing = try await svc.list(EbayListRequest(
            collectionItemID: UUID(), price: Money(amount: 100), condition: .nearMint, quantity: 1, title: "x"))
        #expect(listing.status == "active")
        #expect(listing.viewURL != nil)
    }

    @Test func disconnectedFakeThrowsNotConnected() async {
        let svc = FakeEbayService(connected: false)
        await #expect(throws: EbayError.notConnected) {
            try await svc.list(EbayListRequest(
                collectionItemID: UUID(), price: Money(amount: 100), condition: .nearMint, quantity: 1, title: "x"))
        }
    }
}
