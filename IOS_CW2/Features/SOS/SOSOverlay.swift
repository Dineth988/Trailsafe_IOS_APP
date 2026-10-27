import SwiftUI

struct SOSOverlay: View {
    @EnvironmentObject private var sos: SOSManager
    @EnvironmentObject private var liveShare: LiveShareManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.managedObjectContext) private var context

    @State private var showComposer = false

    private var isTriggered: Bool { sos.phase == .triggered }
    private var foreground: Color { isTriggered ? .white : Color(hex: 0x1B2A21) }

    var body: some View {
        ZStack {
            (isTriggered ? Color(hex: 0xB3261E) : Theme.accent)
                .ignoresSafeArea()

            switch sos.phase {
            case .countdown(let seconds):
                countdownView(seconds)
            case .triggered:
                triggeredView
            case .idle:
                EmptyView()
            }
        }
        .foregroundStyle(foreground)
        .animation(.easeInOut(duration: 0.2), value: sos.phase)
        .interactiveDismissDisabled()
    }

    private func countdownView(_ seconds: Int) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Text("Sending SOS in")
                .font(Typography.title)
            Text("\(seconds)")
                .font(.system(size: 140, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("Tap Cancel if this was a mistake.")
                .font(Typography.body)
            Spacer()
            actionButton("Cancel", filled: true) { sos.cancel() }
            actionButton("Send Now", filled: false) { sos.triggerNow() }
        }
        .padding(Theme.Spacing.lg)
    }

    private var triggeredView: some View {
        let phones = ContactStore.phoneNumbers(ownerID: appState.currentUser?.id, in: context)

        return VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
            Text("SOS triggered")
                .font(Typography.largeTitle)
            if let event = sos.lastEvent {
                VStack(spacing: 4) {
                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    if let c = event.coordinate {
                        Text(String(format: "%.5f, %.5f", c.latitude, c.longitude)).monospacedDigit()
                    } else {
                        Text("Location not available yet")
                    }
                }
                .font(Typography.body)
            }

            if let url = liveShare.shareURL {
                Text("Your live location is now available at your Live Share link.")
                    .font(Typography.caption)
                    .multilineTextAlignment(.center)
                if MessageComposer.canSend, !phones.isEmpty {
                    actionButton("Message My Contacts", filled: false) { showComposer = true }
                }
                ShareLink(item: url, message: Text(liveShare.sosMessage)) {
                    Text("Share Link…")
                        .font(Typography.button)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                .stroke(foreground, lineWidth: 2)
                        )
                }
            } else {
                Text(liveShare.errorMessage ?? "Starting Live Share…")
                    .font(Typography.caption)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            actionButton("I'm Safe", filled: true) { sos.acknowledge() }
        }
        .padding(Theme.Spacing.lg)
        .sheet(isPresented: $showComposer) {
            MessageComposer(recipients: phones, body: liveShare.sosMessage) { showComposer = false }
                .ignoresSafeArea()
        }
    }

    private func actionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.button)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(filled ? (isTriggered ? Color(hex: 0xB3261E) : Theme.accent) : foreground)
                .background(filled ? (isTriggered ? Color.white : Color(hex: 0x1B2A21)) : Color.clear,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .stroke(foreground, lineWidth: filled ? 0 : 2)
                )
        }
    }
}
