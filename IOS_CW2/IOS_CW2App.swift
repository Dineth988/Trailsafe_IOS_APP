import SwiftUI

@main
struct IOS_CW2App: App {
    @StateObject private var appState = AppState()
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
