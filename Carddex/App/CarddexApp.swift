import SwiftUI

@main
struct CarddexApp: App {
    @State private var store = CollectionStore(items: SampleData.collection)
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(environment)
        }
    }
}
