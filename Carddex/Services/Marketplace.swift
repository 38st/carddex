import Foundation

/// Marketplace links. The eBay search carries our Partner Network campaign id so
/// outbound traffic earns affiliate revenue — the zero-approval first revenue stream.
enum Marketplace {
    /// eBay sold/completed listings for a card (price comps), affiliate-tagged.
    static func ebaySoldSearchURL(for card: Card) -> URL? {
        let query = "\(card.name) \(card.setName) \(card.number)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.ebay.com/sch/i.html?_nkw=\(encoded)&LH_Sold=1&LH_Complete=1&campid=EPN_CAMPAIGN_ID")
    }
}
