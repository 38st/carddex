import Testing
import Foundation
@testable import Carddex

@Suite struct WishlistStoreTests {
    @Test func addPutsCardInGrails() {
        let store = WishlistStore()
        let id = SampleData.charizard.id
        #expect(!store.contains(id))
        store.add(cardID: id, target: Money(amount: 250), note: "birthday grail")
        #expect(store.contains(id))
        #expect(store.grails.count == 1)
        #expect(store.grails.first?.target?.amount == 250)
        #expect(store.grails.first?.note == "birthday grail")
    }

    @Test func addReplacesExistingForSameCard() {
        let store = WishlistStore()
        let id = SampleData.jordan.id
        store.add(cardID: id, target: Money(amount: 90000))
        store.add(cardID: id, target: Money(amount: 80000), note: "lowered target")
        #expect(store.grails.count == 1)
        #expect(store.grails.first?.target?.amount == 80000)
        #expect(store.grails.first?.note == "lowered target")
    }

    @Test func removeClearsEntry() {
        let store = WishlistStore()
        let id = SampleData.charizard.id
        store.add(cardID: id)
        #expect(store.contains(id))
        store.remove(id)
        #expect(!store.contains(id))
        #expect(store.grails.isEmpty)
    }

    @Test func setTargetUpdatesOnlyTheTarget() {
        let store = WishlistStore()
        let id = SampleData.charizard.id
        store.add(cardID: id, target: nil, note: "watching")
        store.setTarget(id, target: Money(amount: 300))
        #expect(store.grails.first?.target?.amount == 300)
        // note survives a target-only update
        #expect(store.grails.first?.note == "watching")
    }

    @Test func setTargetIsNoOpForUnknownCard() {
        let store = WishlistStore()
        store.setTarget("not-a-grail", target: Money(amount: 100))
        #expect(store.grails.isEmpty)
    }

    @Test func grailEntryIdIsCardID() {
        let entry = GrailEntry(cardID: "c1")
        #expect(entry.id == "c1")
        #expect(entry.target == nil)
        #expect(entry.note == nil)
    }

    @Test func grailEntryCodableRoundTrips() throws {
        let original = GrailEntry(cardID: "c1", target: Money(amount: 1200), note: "PSA 9 target")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GrailEntry.self, from: data)
        #expect(decoded.cardID == original.cardID)
        #expect(decoded.target?.amount == 1200)
        #expect(decoded.note == "PSA 9 target")
    }
}
