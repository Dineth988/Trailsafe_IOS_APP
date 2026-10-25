import SwiftUI

struct AuthView: View {
    let onAuthenticated: (UserProfile) -> Void
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header

                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(AuthViewModel.Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 14) {
                    if viewModel.mode == .signUp {
                        TSField(title: "Full name", icon: "person", text: $viewModel.name,
                                contentType: .name, capitalization: .words)
                    }
                    TSField(title: "Email", icon: "envelope", text: $viewModel.email,
                            keyboard: .emailAddress, contentType: .emailAddress)
                    TSField(title: "Password", icon: "lock", text: $viewModel.password,
                            isSecure: true,
                            contentType: viewModel.mode == .signUp ? .newPassword : .password)
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(viewModel.mode == .signUp ? "Create Account" : "Log In") {
                    if let user = viewModel.submit() {
                        onAuthenticated(user)
                    }
                }
                .buttonStyle(.trail())
                .disabled(!viewModel.canSubmit)

                Text("Your account and trail data are stored securely on this device.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.lg)
            .animation(.easeInOut(duration: 0.2), value: viewModel.mode)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 52))
                .foregroundStyle(Theme.primary)
            Text("TrailSafe")
                .font(Typography.largeTitle)
                .foregroundStyle(Theme.textPrimary)
            Text(viewModel.mode == .signUp ? "Create your safety account" : "Welcome back")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, Theme.Spacing.xl)
    }
}

#Preview {
    AuthView { _ in }
        .background(Theme.background)
}
