import SwiftUI

struct SettingsPlaceholderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Name", value: appState.currentUser?.name ?? "-")
                    LabeledContent("Email", value: appState.currentUser?.email ?? "-")
                }
                Section("Security") {
                    Toggle("Require \(BiometricService.shared.kind.displayName)",
                           isOn: $appState.biometricLockEnabled)
                }
                Section {
                    Button("Log Out", role: .destructive) { appState.logOut() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
