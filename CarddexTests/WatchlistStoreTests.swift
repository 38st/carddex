import Testing
import Foundation
@testable import Carddex

@MainActor
@Suite struct WatchlistStoreTests {
    @Test func toggleFollowAddsThenRemoves() {
        let store = WatchlistStore()
        let id = SampleData.jordan.id
        #expect(!store.isFollowing(id))
        store.toggleFollow(id)
        #expect(store.isFollowing(id))
        store.toggleFollow(id)
        #expect(!store.isFollowing(id))
    }

    @Test func setAlertReplacesExistingForSameCard() {
        let store = WatchlistStore()
        let id = SampleData.charizard.id
        store.setAlert(cardID: id, target: Money(amount: 1000))
        store.setAlert(cardID: id, target: Money(amount: 2000))
        #expect(store.alerts.count == 1)
        #expect(store.hasAlert(id))
        #expect(store.alerts.first?.target.amount == 2000)
    }

    @Test func removeAlertClearsIt() {
        let store = WatchlistStore()
        let id = SampleData.charizard.id
        store.setAlert(cardID: id, target: Money(amount: 1000))
        #expect(store.hasAlert(id))
        store.removeAlert(id)
        #expect(!store.hasAlert(id))
        #expect(store.alerts.isEmpty)
    }

    @Test func alertsOnDifferentCardsCoexist() {
        let store = WatchlistStore()
        store.setAlert(cardID: SampleData.jordan.id, target: Money(amount: 90000))
        store.setAlert(cardID: SampleData.brady.id, target: Money(amount: 60000))
        #expect(store.alerts.count == 2)
        #expect(store.hasAlert(SampleData.jordan.id))
        #expect(store.hasAlert(SampleData.brady.id))
    }
}
