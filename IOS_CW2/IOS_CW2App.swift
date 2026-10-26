import SwiftUI

@main
struct IOS_CW2App: App {
    @StateObject private var appState = AppState()
    @StateObject private var locationService: LocationService
    @StateObject private var recorder: TrailRecorder
    private let persistence = PersistenceController.shared

    init() {
        let location = LocationService()
        _locationService = StateObject(wrappedValue: location)
        _recorder = StateObject(wrappedValue: TrailRecorder(location: location))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(locationService)
                .environmentObject(recorder)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
