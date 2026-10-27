import SwiftUI

@main
struct IOS_CW2App: App {
    @StateObject private var appState: AppState
    @StateObject private var locationService: LocationService
    @StateObject private var recorder: TrailRecorder
    @StateObject private var settings: SafetySettings
    @StateObject private var notifications: NotificationService
    @StateObject private var zones: SafeZoneMonitor
    @StateObject private var sos: SOSManager
    @StateObject private var coordinator: SafetyCoordinator
    @StateObject private var liveShare: LiveShareManager
    private let persistence = PersistenceController.shared

    init() {
        let appState = AppState()
        let location = LocationService()
        let recorder = TrailRecorder(location: location)
        let settings = SafetySettings()
        let notifications = NotificationService.shared
        let zones = SafeZoneMonitor()
        let sos = SOSManager(location: location, notifications: notifications)
        let coordinator = SafetyCoordinator(location: location, recorder: recorder, zones: zones,
                                            notifications: notifications, settings: settings)
        let liveShare = LiveShareManager(location: location, recorder: recorder)

        liveShare.ownerNameProvider = { appState.currentUser?.name ?? "A TrailSafe user" }
        sos.onTriggered = { event in liveShare.handleSOS(event) }
        sos.onAcknowledged = { liveShare.clearSOS() }

        _appState = StateObject(wrappedValue: appState)
        _locationService = StateObject(wrappedValue: location)
        _recorder = StateObject(wrappedValue: recorder)
        _settings = StateObject(wrappedValue: settings)
        _notifications = StateObject(wrappedValue: notifications)
        _zones = StateObject(wrappedValue: zones)
        _sos = StateObject(wrappedValue: sos)
        _coordinator = StateObject(wrappedValue: coordinator)
        _liveShare = StateObject(wrappedValue: liveShare)
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
                .environmentObject(liveShare)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
