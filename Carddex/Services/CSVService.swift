import Foundation

/// CSV import/export for collection data. Supports common formats from
/// Collectr, TCGplayer, and Card Atlas exports, plus our own format.
struct CSVService {

    // MARK: - Export

    /// Export the collection to a CSV string.
    static func export(_ items: [CollectionItem]) -> String {
        var lines: [String] = []
        lines.append("Game,Name,Set,Number,Rarity,Condition,Quantity,PurchasePrice,MarketPrice,DateAdded")

        for item in items {
            let row = [
                item.card.game.rawValue,
                escape(item.card.name),
                escape(item.card.setName),
                escape(item.card.number),
                escape(item.card.rarity ?? ""),
                item.condition.rawValue,
                "\(item.quantity)",
                item.purchasePrice.map { "\(NSDecimalNumber(decimal: $0.amount).doubleValue)" } ?? "",
                item.card.marketPrice.map { "\(NSDecimalNumber(decimal: $0.amount).doubleValue)" } ?? "",
                ISO8601DateFormatter().string(from: item.dateAdded),
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Import

    /// Parsed row from a CSV import.
    struct ImportedRow {
        var game: String
        var name: String
        var setName: String
        var number: String
        var rarity: String?
        var condition: String?
        var quantity: Int
        var purchasePrice: Double?
    }

    /// Parse CSV text into imported rows. Tries to detect the source format
    /// (Collectr, TCGplayer, Card Atlas, or our own) by inspecting the header.
    static func parse(_ csv: String) -> [ImportedRow] {
        let lines = csv
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let header = lines.first else { return [] }
        let headerLower = header.lowercased()
        let columns = parseRow(header)

        // Map column indices based on detected format.
        let gameIdx = findColumn(columns, candidates: ["game", "sport", "category"])
        let nameIdx = findColumn(columns, candidates: ["name", "card name", "card", "player"])
        let setIdx = findColumn(columns, candidates: ["set", "set name", "edition", "series"])
        let numberIdx = findColumn(columns, candidates: ["number", "card number", "#", "collector number"])
        let rarityIdx = findColumn(columns, candidates: ["rarity"])
        let conditionIdx = findColumn(columns, candidates: ["condition", "grade"])
        let qtyIdx = findColumn(columns, candidates: ["quantity", "qty", "count"])
        let priceIdx = findColumn(columns, candidates: ["purchase price", "price paid", "cost", "acquired price", "purchaseprice"])

        var rows: [ImportedRow] = []
        for line in lines.dropFirst() {
            let fields = parseRow(line)
            func field(_ idx: Int?) -> String {
                guard let idx, idx < fields.count else { return "" }
                return fields[idx]
            }
            let name = field(nameIdx).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            let qtyStr = field(qtyIdx)
            let qty = Int(qtyStr) ?? 1
            let priceStr = field(priceIdx)
            let price = Double(priceStr.filter { $0.isNumber || $0 == "." })

            rows.append(ImportedRow(
                game: field(gameIdx),
                name: name,
                setName: field(setIdx),
                number: field(numberIdx),
                rarity: field(rarityIdx).isEmpty ? nil : field(rarityIdx),
                condition: field(conditionIdx).isEmpty ? nil : field(conditionIdx),
                quantity: qty,
                purchasePrice: price
            ))
        }

        return rows
    }

    /// Convert parsed rows into `CollectionItem`s by matching against the
    /// catalog (SampleData or a future remote catalog). Unmatched rows
    /// get a synthetic Card with the imported metadata.
    @MainActor
    static func toCollectionItems(_ rows: [ImportedRow]) -> [CollectionItem] {
        rows.compactMap { row in
            let game: CardGame
            if let g = CardGame(rawValue: row.game.lowercased()) {
                game = g
            } else if row.game.lowercased().contains("pokemon") || row.game.lowercased().contains("pokémon") {
                game = .pokemon
            } else if row.game.lowercased().contains("magic") || row.game.lowercased().contains("mtg") {
                game = .magic
            } else if row.game.lowercased().contains("yugioh") || row.game.lowercased().contains("yu-gi-oh") {
                game = .yugioh
            } else if row.game.lowercased().contains("sport") || row.game.lowercased().contains("basketball") || row.game.lowercased().contains("baseball") || row.game.lowercased().contains("football") {
                game = .sports
            } else {
                game = .pokemon
            }

            let condition: CardCondition
            if let c = row.condition, let parsed = CardCondition(rawValue: c) {
                condition = parsed
            } else if let c = row.condition {
                let lower = c.lowercased()
                if lower.contains("mint") && !lower.contains("near") { condition = .mint }
                else if lower.contains("near") { condition = .nearMint }
                else if lower.contains("light") { condition = .lightlyPlayed }
                else if lower.contains("moderate") { condition = .moderatelyPlayed }
                else if lower.contains("heavy") { condition = .heavilyPlayed }
                else if lower.contains("damag") { condition = .damaged }
                else { condition = .nearMint }
            } else {
                condition = .nearMint
            }

            let id = "\(game.rawValue)-\(row.setName)-\(row.number)-\(row.name)"
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")

            let card = Card(
                id: id,
                game: game,
                name: row.name,
                setName: row.setName,
                number: row.number,
                rarity: row.rarity,
                imageURL: nil,
                marketPrice: nil
            )

            let purchasePrice = row.purchasePrice.map { Money(amount: Decimal($0)) }

            return CollectionItem(
                card: card,
                quantity: row.quantity,
                condition: condition,
                purchasePrice: purchasePrice
            )
        }
    }

    // MARK: - CSV parsing helpers

    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }

    private static func parseRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let char = chars[i]
            if char == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 2
                    continue
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
            i += 1
        }
        fields.append(current)

        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func findColumn(_ columns: [String], candidates: [String]) -> Int? {
        let lower = columns.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        for candidate in candidates {
            if let idx = lower.firstIndex(of: candidate) { return idx }
        }
        // Partial match fallback.
        for candidate in candidates {
            if let idx = lower.firstIndex(where: { $0.contains(candidate) }) { return idx }
        }
        return nil
    }
}
