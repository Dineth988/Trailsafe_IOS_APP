import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "map.fill") }

            HistoryView(ownerID: appState.currentUser?.id)
                .tabItem { Label("History", systemImage: "chart.bar.fill") }

            ContactsView(ownerID: appState.currentUser?.id)
                .tabItem { Label("Contacts", systemImage: "person.2.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
