import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var recorder: TrailRecorder

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch appState.phase {
            case .onboarding:
                OnboardingView { appState.completeOnboarding() }
            case .auth:
                AuthView { user in appState.didAuthenticate(user) }
            case .locked:
                LockView { appState.unlock() }
            case .main:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.phase)
        .overlay {
            // Hides content in the app switcher snapshot.
            if scenePhase != .active && appState.currentUser != nil {
                PrivacyShield()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                recorder.persistNow()      // flush buffered GPS points to disk
                appState.lockIfNeeded()
            }
        }
        .tint(Theme.primary)
    }
}

private struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Theme.background
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 64))
                .foregroundStyle(Theme.primary)
        }
        .ignoresSafeArea()
    }
}
