import SwiftUI

struct PlaceholderScreen: View {
    let title: String
    let icon: String
    let detail: String
    var showsSOS = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.primary)
                    Text(title)
                        .font(Typography.title)
                        .foregroundStyle(Theme.textPrimary)
                    Text(detail)
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                if showsSOS {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            SOSButton {}
                        }
                        .padding(Theme.Spacing.lg)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "map.fill") }

            PlaceholderScreen(title: "History", icon: "chart.bar.fill",
                              detail: "Past sessions and charts arrive on Day 4.")
                .tabItem { Label("History", systemImage: "chart.bar.fill") }

            PlaceholderScreen(title: "Contacts", icon: "person.2.fill",
                              detail: "Trusted contacts and Live Share arrive on Day 4.")
                .tabItem { Label("Contacts", systemImage: "person.2.fill") }

            PlaceholderScreen(title: "Settings", icon: "gearshape.fill",
                              detail: "Full settings arrive on Day 3.")
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview { MainTabView() }
