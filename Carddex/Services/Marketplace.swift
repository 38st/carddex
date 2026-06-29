import Foundation

/// Marketplace links. The eBay search carries our eBay Partner Network campaign
/// id so outbound traffic earns affiliate revenue — the zero-approval first
/// revenue stream. The campaign id is read from `Secrets.plist` (`AppConfig`); if
/// absent the link is still valid, just untagged.
enum Marketplace {
    /// eBay sold/completed listings for a card (price comps), affiliate-tagged
    /// with the campaign id from `AppConfig`.
    static func ebaySoldSearchURL(for card: Card) -> URL? {
        ebaySoldSearchURL(for: card, campaignID: AppConfig.affiliateCampaignID)
    }

    /// Testable core — builds the sold-search URL with an explicit campaign id.
    /// `campaignID` empty → omits `campid` (still valid, just untagged).
    static func ebaySoldSearchURL(for card: Card, campaignID: String) -> URL? {
        let query = "\(card.name) \(card.setName) \(card.number)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        var path = "https://www.ebay.com/sch/i.html?_nkw=\(encoded)&LH_Sold=1&LH_Complete=1"
        if !campaignID.isEmpty {
            path += "&campid=\(campaignID)"
        }
        return URL(string: path)
    }

    /// eBay *active* listings for a card (buy now / auctions), sorted by lowest
    /// price + shipping. The "go buy your grail" link, affiliate-tagged.
    static func ebayBuySearchURL(for card: Card) -> URL? {
        ebayBuySearchURL(for: card, campaignID: AppConfig.affiliateCampaignID)
    }

    /// Testable core for the active-listings buy URL.
    static func ebayBuySearchURL(for card: Card, campaignID: String) -> URL? {
        let query = "\(card.name) \(card.setName) \(card.number)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        // _sop=15 → sort by price + shipping, lowest first (buy intent).
        var path = "https://www.ebay.com/sch/i.html?_nkw=\(encoded)&_sop=15"
        if !campaignID.isEmpty {
            path += "&campid=\(campaignID)"
        }
        return URL(string: path)
    }
}
