import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    enum Kind { case primary, accent, secondary }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.button)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .stroke(Theme.primary, lineWidth: 1.5)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .accent: return Color(hex: 0x1B2A21) // dark text for contrast on orange
        case .secondary: return Theme.primary
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return Theme.primary
        case .accent: return Theme.accent
        case .secondary: return .clear
        }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static func trail(_ kind: PrimaryButtonStyle.Kind = .primary) -> PrimaryButtonStyle {
        PrimaryButtonStyle(kind: kind)
    }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}

// MARK: - SOS button

struct SOSButton: View {
    var size: CGFloat = 72
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("SOS")
                .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.accent))
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 3))
                .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
        }
        .accessibilityLabel("SOS emergency")
        .accessibilityHint("Starts an emergency alert countdown")
    }
}

// MARK: - Text field

struct TSField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var capitalization: TextInputAutocapitalization = .never

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 22)
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                        .keyboardType(keyboard)
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
            .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(minHeight: 52)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }
}

#Preview("Design system") {
    @Previewable @State var text = ""
    return VStack(spacing: 16) {
        TSField(title: "Email", icon: "envelope", text: $text)
        Button("Primary") {}.buttonStyle(.trail())
        Button("Accent") {}.buttonStyle(.trail(.accent))
        Button("Secondary") {}.buttonStyle(.trail(.secondary))
        Text("Card").cardStyle()
        SOSButton {}
    }
    .padding()
    .background(Theme.background)
}
