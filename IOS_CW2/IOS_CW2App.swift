import SwiftUI

@main
struct IOS_CW2App: App {
    @StateObject private var appState = AppState()
    @StateObject private var locationService: LocationService
    @StateObject private var recorder: TrailRecorder
    @StateObject private var settings: SafetySettings
    @StateObject private var notifications: NotificationService
    @StateObject private var zones: SafeZoneMonitor
    @StateObject private var sos: SOSManager
    @StateObject private var coordinator: SafetyCoordinator
    private let persistence = PersistenceController.shared

    init() {
        let location = LocationService()
        let recorder = TrailRecorder(location: location)
        let settings = SafetySettings()
        let notifications = NotificationService.shared
        let zones = SafeZoneMonitor()
        let sos = SOSManager(location: location, notifications: notifications)
        let coordinator = SafetyCoordinator(location: location, recorder: recorder, zones: zones,
                                            notifications: notifications, settings: settings)

        _locationService = StateObject(wrappedValue: location)
        _recorder = StateObject(wrappedValue: recorder)
        _settings = StateObject(wrappedValue: settings)
        _notifications = StateObject(wrappedValue: notifications)
        _zones = StateObject(wrappedValue: zones)
        _sos = StateObject(wrappedValue: sos)
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(locationService)
                .environmentObject(recorder)
                .environmentObject(settings)
                .environmentObject(notifications)
                .environmentObject(zones)
                .environmentObject(sos)
                .environmentObject(coordinator)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
