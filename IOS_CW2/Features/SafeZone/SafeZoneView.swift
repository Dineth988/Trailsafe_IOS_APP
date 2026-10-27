import SwiftUI
import MapKit

struct SafeZoneView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var zones: SafeZoneMonitor
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var existing: SafeZone?
    @State private var name = "Home"
    @State private var center: CLLocationCoordinate2D?
    @State private var radius: Double = 200
    @State private var isActive = true
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var awaitingFix = false
    @State private var confirmDelete = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                mapView

                Button {
                    useCurrentLocation()
                } label: {
                    Label("Use my current location", systemImage: "location.fill")
                }
                .buttonStyle(.trail(.secondary))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Radius").font(Typography.headline)
                        Spacer()
                        Text(Fmt.distance(radius)).font(Typography.body).monospacedDigit()
                    }
                    .foregroundStyle(Theme.textPrimary)
                    Slider(value: $radius, in: 50...2000, step: 50)
                }
                .cardStyle()

                TSField(title: "Zone name", icon: "tag", text: $name, capitalization: .words)

                Toggle("Zone is active", isOn: $isActive)
                    .foregroundStyle(Theme.textPrimary)
                    .cardStyle()

                Button("Save Safe Zone", action: save)
                    .buttonStyle(.trail())
                    .disabled(center == nil)

                if existing != nil {
                    Button("Delete Safe Zone", role: .destructive) { confirmDelete = true }
                        .font(Typography.body)
                }

                Text("You'll get an alert when you leave or re-enter this zone while a trail is recording.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background)
        .navigationTitle("Safe Zone")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadExisting() }
        .onChange(of: location.lastLocation) { _, newValue in
            if awaitingFix, let newValue { apply(newValue.coordinate) }
        }
        .confirmationDialog("Delete this safe zone?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteZone)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Map

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $position) {
                UserAnnotation()
                if let center {
                    MapCircle(center: center, radius: radius)
                        .foregroundStyle(Theme.primary.opacity(0.2))
                        .stroke(Theme.primary, lineWidth: 2)
                    Marker(name.isEmpty ? "Safe zone" : name, systemImage: "shield.fill", coordinate: center)
                        .tint(Theme.primary)
                }
            }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) { center = coordinate }
            }
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .overlay(alignment: .bottom) {
            Text("Tap the map to move the zone")
                .font(Typography.caption)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
        }
    }

    // MARK: Actions

    private func loadExisting() {
        guard !loaded else { return }
        loaded = true
        guard let zone = SafeZoneStore.zone(ownerID: appState.currentUser?.id, in: context) else { return }
        existing = zone
        name = zone.name ?? "Home"
        radius = zone.radiusMeters
        isActive = zone.isActive
        let coordinate = CLLocationCoordinate2D(latitude: zone.centerLatitude, longitude: zone.centerLongitude)
        center = coordinate
        position = region(around: coordinate)
    }

    private func useCurrentLocation() {
        if !location.isAuthorized { location.requestPermissionIfNeeded() }
        awaitingFix = true
        if let last = location.lastLocation, abs(last.timestamp.timeIntervalSinceNow) < 120 {
            apply(last.coordinate)
        }
        location.requestSingleLocation()
    }

    private func apply(_ coordinate: CLLocationCoordinate2D) {
        center = coordinate
        position = region(around: coordinate)
        awaitingFix = false
    }

    private func region(around coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        let span = max(radius * 4, 800)
        return .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: span, longitudinalMeters: span))
    }

    private func save() {
        guard let center else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        SafeZoneStore.save(
            existing: existing,
            ownerID: appState.currentUser?.id,
            name: trimmed.isEmpty ? "Safe zone" : trimmed,
            center: center,
            radius: radius,
            isActive: isActive,
            in: context
        )
        zones.reload(ownerID: appState.currentUser?.id, context: context)
        dismiss()
    }

    private func deleteZone() {
        if let existing { SafeZoneStore.delete(existing, in: context) }
        zones.reload(ownerID: appState.currentUser?.id, context: context)
        dismiss()
    }
}
