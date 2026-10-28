import SwiftUI

struct WeatherSheet: View {
    @EnvironmentObject private var weather: WeatherService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if let snapshot = weather.snapshot {
                        content(snapshot)
                    } else if weather.isLoading {
                        ProgressView("Loading weather…").padding(.top, 40)
                    } else {
                        emptyState
                    }

                    if let message = weather.errorMessage, weather.snapshot != nil {
                        Label(message, systemImage: "wifi.slash")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Text("Weather data by Open-Meteo.com")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.background)
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { weather.refreshNow() } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(weather.isLoading)
                        .accessibilityLabel("Refresh weather")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ snapshot: WeatherSnapshot) -> some View {
        let assessment = WeatherHazard.assess(snapshot)

        VStack(spacing: Theme.Spacing.md) {
            if assessment.level > .safe { banner(assessment) }

            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: snapshot.condition.symbol)
                    .font(.system(size: 46))
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(snapshot.temperatureC.rounded()))°C")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(assessment.level >= .warning ? Theme.accent : Theme.textPrimary)
                    Text(snapshot.condition.text)
                        .font(Typography.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Feels like \(Int(snapshot.feelsLikeC.rounded()))°C")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                StatTile(title: "Wind", value: "\(Int(snapshot.windKmh.rounded()))", unit: "km/h")
                StatTile(title: "Gusts", value: "\(Int(snapshot.gustKmh.rounded()))", unit: "km/h")
                StatTile(title: "Rain chance (3 h)", value: "\(snapshot.precipChance)", unit: "%")
                StatTile(title: "UV index", value: String(format: "%.0f", snapshot.uvIndex), unit: snapshot.uvLabel)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Safety tip", systemImage: "lightbulb.fill")
                    .font(Typography.headline)
                    .foregroundStyle(Theme.primary)
                Text(assessment.tip)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()

            HStack(spacing: 6) {
                Text("Updated \(snapshot.fetchedAt.formatted(.relative(presentation: .named)))")
                if weather.isOfflineCopy { Text("· saved copy") }
            }
            .font(Typography.caption)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private func banner(_ assessment: WeatherAssessment) -> some View {
        let tint: Color = assessment.level == .severe ? Color(hex: 0xB3261E) : Theme.accent
        return VStack(alignment: .leading, spacing: 6) {
            Label(assessment.title, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.headline)
                .foregroundStyle(tint)
            ForEach(assessment.reasons, id: \.self) { reason in
                Text("• \(reason)")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .stroke(tint, lineWidth: 1.5)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.sun")
                .font(.system(size: 44))
                .foregroundStyle(Theme.primary)
            Text(weather.errorMessage ?? "No forecast yet")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}
