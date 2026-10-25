import SwiftUI

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let tint: Color
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        .init(icon: "figure.hiking",
              title: "Record every trail, even offline",
              message: "TrailSafe tracks your route with GPS and stores it on your phone, so it keeps working when the signal drops.",
              tint: Theme.primary),
        .init(icon: "bell.badge.fill",
              title: "Safety that watches with you",
              message: "Set a safe zone and get alerts if you leave it, stop moving for too long, or miss a check-in.",
              tint: Theme.accent),
        .init(icon: "antenna.radiowaves.left.and.right",
              title: "Share live with people you trust",
              message: "Start a temporary Live Share so a trusted contact can see where you are. Stop it any time.",
              tint: Theme.info)
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLastPage {
                    Button("Skip", action: onFinish)
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(height: 44)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    pageView(item).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Theme.primary : Theme.stroke)
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
            .padding(.bottom, Theme.Spacing.lg)

            Button(isLastPage ? "Get Started" : "Next") {
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(.trail())
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private func pageView(_ item: OnboardingPage) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(item.tint.opacity(0.15)).frame(width: 180, height: 180)
                Image(systemName: item.icon)
                    .font(.system(size: 72))
                    .foregroundStyle(item.tint)
            }
            Text(item.title)
                .font(Typography.largeTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(item.message)
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

#Preview {
    OnboardingView {}
        .background(Theme.background)
}
