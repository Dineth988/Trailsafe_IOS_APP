import SwiftUI

struct StartTrailSheet: View {
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 40))
                .foregroundStyle(Theme.primary)
            Text("Start a trail?")
                .font(Typography.title)
                .foregroundStyle(Theme.textPrimary)
            VStack(alignment: .leading, spacing: 10) {
                Label("Your route is saved on this phone, even offline.", systemImage: "internaldrive")
                Label("Tracking continues with the screen off. You'll see a blue location indicator.", systemImage: "location.fill")
            }
            .font(Typography.body)
            .foregroundStyle(Theme.textSecondary)

            Spacer(minLength: 0)

            Button("Start Trail", action: onStart).buttonStyle(.trail(.accent))
            Button("Cancel", action: onCancel).buttonStyle(.trail(.secondary))
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.background)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }
}

struct StopTrailSheet: View {
    let distanceText: String
    let durationText: String
    let onFinish: () -> Void
    let onDiscard: () -> Void
    let onContinue: () -> Void

    @State private var confirmDiscard = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Finish this trail?")
                .font(Typography.title)
                .foregroundStyle(Theme.textPrimary)
            Text("\(distanceText) in \(durationText)")
                .font(Typography.headline)
                .foregroundStyle(Theme.textSecondary)

            Spacer(minLength: 0)

            Button("Finish & Save", action: onFinish).buttonStyle(.trail())
            Button("Keep Recording", action: onContinue).buttonStyle(.trail(.secondary))
            Button("Discard Trail", role: .destructive) { confirmDiscard = true }
                .font(Typography.body)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.background)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Discard this trail?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: onDiscard)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The recorded route will be deleted.")
        }
    }
}
