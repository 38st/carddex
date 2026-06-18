import AppIntents
import CoreSpotlight
import UniformTypeIdentifiers

// MARK: - Query intents (read the App Group snapshot the widget writes)

struct CaseIndexIntent: AppIntent {
    static let title: LocalizedStringResource = "Check the Case Index"
    static let description = IntentDescription("Get the current Case Index value and this month's change.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snap = WidgetBridge.read() ?? .placeholder
        let value = snap.indexValue.formatted(.number.precision(.fractionLength(2)))
        let dir = snap.indexChange >= 0 ? "up" : "down"
        let pct = String(format: "%.1f", abs(snap.indexChange))
        return .result(dialog: "The Case Index is \(value), \(dir) \(pct)% this month.")
    }
}

struct PortfolioValueIntent: AppIntent {
    static let title: LocalizedStringResource = "Check my collection value"
    static let description = IntentDescription("Get your collection's total value and gain.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snap = WidgetBridge.read() ?? .placeholder
        return .result(dialog: "Your collection is worth \(snap.portfolioValue), \(snap.portfolioGain).")
    }
}

struct ScanCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a card"
    static let description = IntentDescription("Open The Case to scan a card.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.pendingTab = "scan"
        return .result()
    }
}

// MARK: - Siri / Shortcuts phrases

struct CaseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaseIndexIntent(),
            phrases: [
                "What's the Case Index in \(.applicationName)",
                "Check the index in \(.applicationName)",
            ],
            shortTitle: "Case Index",
            systemImageName: "chart.xyaxis.line"
        )
        AppShortcut(
            intent: PortfolioValueIntent(),
            phrases: [
                "What's my collection worth in \(.applicationName)",
                "Check my portfolio in \(.applicationName)",
            ],
            shortTitle: "Collection Value",
            systemImageName: "square.stack"
        )
        AppShortcut(
            intent: ScanCardIntent(),
            phrases: [
                "Scan a card in \(.applicationName)",
            ],
            shortTitle: "Scan a card",
            systemImageName: "viewfinder"
        )
    }
}

// MARK: - Intent → app routing (App Group, consumed on foreground)

enum IntentRouter {
    private static let key = "pendingTab"
    private static var defaults: UserDefaults { UserDefaults(suiteName: WidgetBridge.appGroupID) ?? .standard }

    static var pendingTab: String? {
        get { defaults.string(forKey: key) }
        set {
            if let newValue { defaults.set(newValue, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
    }
}

// MARK: - Spotlight indexing (cards surface in system search)

enum SpotlightIndexer {
    static func index(_ cards: [Card]) {
        let items = cards.map { card -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = card.name
            var description = "\(card.setName) · \(card.number)"
            if let price = card.marketPrice { description += " · \(price.formatted)" }
            attrs.contentDescription = description
            return CSSearchableItem(uniqueIdentifier: card.id, domainIdentifier: "cards", attributeSet: attrs)
        }
        CSSearchableIndex.default().indexSearchableItems(items)
    }
}
