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

/// Decision logic behind local price-alert notifications.
@Suite struct AlertReconcilerTests {
    private let alert = PriceAlert(cardID: "c1", target: Money(amount: 100))

    @Test func reachedAlertNotifiesOnceThenSuppresses() {
        let price: (PriceAlert) -> Decimal? = { _ in 120 } // above target
        let first = AlertReconciler.evaluate(alerts: [alert], price: price, notified: [])
        #expect(first.notify.count == 1)
        #expect(first.notified.contains(AlertReconciler.key(alert)))
        // Same elevated price again → already notified, stays quiet.
        let second = AlertReconciler.evaluate(alerts: [alert], price: price, notified: first.notified)
        #expect(second.notify.isEmpty)
    }

    @Test func belowTargetDoesNotNotify() {
        let result = AlertReconciler.evaluate(alerts: [alert], price: { _ in 80 }, notified: [])
        #expect(result.notify.isEmpty)
    }

    @Test func dropBelowReArmsForNextCrossing() {
        let notified: Set<String> = [AlertReconciler.key(alert)]
        let dropped = AlertReconciler.evaluate(alerts: [alert], price: { _ in 80 }, notified: notified)
        #expect(!dropped.notified.contains(AlertReconciler.key(alert)))
        let recrossed = AlertReconciler.evaluate(alerts: [alert], price: { _ in 130 }, notified: dropped.notified)
        #expect(recrossed.notify.count == 1)
    }

    @Test func removedAlertKeysArePruned() {
        let stale: Set<String> = ["gone@50", AlertReconciler.key(alert)]
        let result = AlertReconciler.evaluate(alerts: [alert], price: { _ in 90 }, notified: stale)
        #expect(!result.notified.contains("gone@50"))
    }
}
