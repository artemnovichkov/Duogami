import SwiftUI

@main
struct DuogamiApp: App {
    @State private var store = WorkshopStore()
    var body: some Scene {
        WindowGroup {
            CollectionView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
