import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SafetySettings
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var recorder: TrailRecorder
    @EnvironmentObject private var zones: SafeZoneMonitor
    @Environment(\.managedObjectContext) private var context
    @Environment(\.openURL) private var openURL

    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                securitySection
                safetySection
                notificationsSection
                dataSection
                Section {
                    Button("Log Out", role: .destructive) { appState.logOut() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task { await notifications.refreshStatus() }
            .onChange(of: settings.dailyCheckInEnabled) { _, _ in applyCheckIn() }
            .onChange(of: settings.checkInMinutes) { _, _ in applyCheckIn() }
            .confirmationDialog("Erase all trails, contacts and safe zones?",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase Everything", role: .destructive, action: resetData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone. Your account stays.")
            }
        }
    }

    // MARK: Sections

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Name", value: appState.currentUser?.name ?? "-")
            LabeledContent("Email", value: appState.currentUser?.email ?? "-")
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Toggle("Require \(BiometricService.shared.kind.displayName)",
                   isOn: $appState.biometricLockEnabled)
        }
    }

    private var safetySection: some View {
        Section {
            NavigationLink {
                SafeZoneView()
            } label: {
                HStack {
                    Label("Safe zone", systemImage: "shield.lefthalf.filled")
                    Spacer()
                    Text(zones.zoneName ?? "Not set")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Toggle("Alert when I leave or re-enter it", isOn: $settings.zoneAlertsEnabled)
            Toggle("Alert if I stop moving", isOn: $settings.stationaryAlertsEnabled)
            if settings.stationaryAlertsEnabled {
                Picker("After", selection: $settings.stationaryMinutes) {
                    ForEach([1, 5, 10, 15, 30], id: \.self) { minutes in
                        Text(minutes == 1 ? "1 min (testing)" : "\(minutes) min").tag(minutes)
                    }
                }
            }
        } header: {
            Text("Safety")
        } footer: {
            Text("Zone and stationary alerts run while a trail is recording.")
        }
    }

    private var notificationsSection: some View {
        Section {
            HStack {
                Text("Notifications")
                Spacer()
                Text(statusText).foregroundStyle(Theme.textSecondary)
            }
            switch notifications.authorizationStatus {
            case .notDetermined:
                Button("Enable Notifications") {
                    Task { await notifications.requestAuthorizationIfNeeded() }
                }
            case .denied:
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            default:
                EmptyView()
            }
            Toggle("Trail complete alert", isOn: $settings.sessionCompleteAlertsEnabled)
            Toggle("Daily check-in reminder", isOn: $settings.dailyCheckInEnabled)
            if settings.dailyCheckInEnabled {
                DatePicker("Time", selection: $settings.checkInTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Alerts appear while TrailSafe is open. The daily check-in also arrives when the app is closed.")
        }
    }

    private var dataSection: some View {
        Section {
            Button("Erase Trails, Contacts & Zones", role: .destructive) { confirmReset = true }
                .disabled(recorder.state != .idle)
        } header: {
            Text("Data")
        } footer: {
            if recorder.state != .idle { Text("Finish your current trail first.") }
        }
    }

    // MARK: Helpers

    private var statusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .ephemeral: return "On"
        case .provisional: return "Quiet"
        case .denied: return "Off"
        case .notDetermined: return "Not asked"
        @unknown default: return "Unknown"
        }
    }

    private func applyCheckIn() {
        if settings.dailyCheckInEnabled {
            Task {
                let allowed = await notifications.requestAuthorizationIfNeeded()
                if allowed {
                    notifications.scheduleDailyCheckIn(hour: settings.checkInMinutes / 60,
                                                       minute: settings.checkInMinutes % 60)
                } else {
                    settings.dailyCheckInEnabled = false     // can't remind without permission
                }
            }
        } else {
            notifications.cancelDailyCheckIn()
        }
    }

    private func resetData() {
        DataReset.eraseUserData(ownerID: appState.currentUser?.id, in: context)
        zones.reload(ownerID: appState.currentUser?.id, context: context)
    }
}
