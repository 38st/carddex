import SwiftUI

/// A sub-index of the market — a category (Basketball, Baseball, …) or, later, a
/// player. Its value/series is derived from its member cards.
struct MarketIndexEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let symbolName: String
    let memberIDs: [String]
    let accentHex: UInt

    var accent: Color { Color(hex: accentHex) }

    static func == (lhs: MarketIndexEntry, rhs: MarketIndexEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
