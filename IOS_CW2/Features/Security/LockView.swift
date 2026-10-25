import SwiftUI

struct LockView: View {
    let onUnlocked: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var didAutoPrompt = false
    @State private var isAuthenticating = false

    private let biometrics = BiometricService.shared

    var body: some View {
        let kind = biometrics.kind

        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.primary)
            Text("TrailSafe is locked")
                .font(Typography.title)
                .foregroundStyle(Theme.textPrimary)
            Text("Use \(kind.displayName) to view your trails, contacts and live location.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Task { await unlock() }
            } label: {
                Label("Unlock with \(kind.displayName)", systemImage: kind.symbolName)
            }
            .buttonStyle(.trail())
            .disabled(isAuthenticating)
        }
        .padding(Theme.Spacing.lg)
        .task {
            if scenePhase == .active { await unlock() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                didAutoPrompt = false
            case .active:
                if !didAutoPrompt { Task { await unlock() } }
            default:
                break
            }
        }
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        didAutoPrompt = true
        isAuthenticating = true
        let success = await biometrics.authenticate(reason: "Unlock TrailSafe")
        isAuthenticating = false
        if success { onUnlocked() }
    }
}

#Preview {
    LockView {}
        .background(Theme.background)
}
