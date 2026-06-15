import SwiftUI

@main
struct CarddexApp: App {
    @State private var store = CollectionStore(items: SampleData.collection)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
