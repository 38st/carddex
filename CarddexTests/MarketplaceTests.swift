import Testing
import Foundation
@testable import Carddex

@Suite struct MarketplaceTests {
    private func makeCard(name: String = "Charizard", setName: String = "Base Set", number: String = "004") -> Card {
        Card(id: "test-\(name)", game: .pokemon, name: name, setName: setName, number: number,
             rarity: "Holo Rare", imageURL: nil, marketPrice: Money(amount: 320))
    }

    @Test func urlContainsSoldAndCompleteFlags() throws {
        let url = try #require(Marketplace.ebaySoldSearchURL(for: makeCard(), campaignID: ""))
        let s = url.absoluteString
        #expect(s.contains("https://www.ebay.com/sch/i.html?"))
        #expect(s.contains("LH_Sold=1"))
        #expect(s.contains("LH_Complete=1"))
    }

    @Test func urlPercentEncodesTheQuery() throws {
        let url = try #require(Marketplace.ebaySoldSearchURL(for: makeCard(name: "Blue-Eyes", setName: "LOB", number: "001"), campaignID: ""))
        // Spaces and the hyphen-bearing name must be encoded into _nkw.
        #expect(url.absoluteString.contains("_nkw=Blue-Eyes%20LOB%20001"))
    }

    @Test func urlOmitsCampidWhenCampaignIDEmpty() throws {
        let url = try #require(Marketplace.ebaySoldSearchURL(for: makeCard(), campaignID: ""))
        #expect(!url.absoluteString.contains("campid"))
    }

    @Test func urlAppendsCampidWhenConfigured() throws {
        let url = try #require(Marketplace.ebaySoldSearchURL(for: makeCard(), campaignID: "53378012345"))
        #expect(url.absoluteString.contains("campid=53378012345"))
    }

    @Test func publicEntryPointIsUntaggedWithoutSecrets() throws {
        // In the test bundle there is no Secrets.plist, so AppConfig resolves
        // an empty campaign id and the public link stays untagged (but valid).
        let url = try #require(Marketplace.ebaySoldSearchURL(for: makeCard()))
        #expect(!url.absoluteString.contains("campid"))
        #expect(url.absoluteString.contains("LH_Sold=1"))
    }
}
