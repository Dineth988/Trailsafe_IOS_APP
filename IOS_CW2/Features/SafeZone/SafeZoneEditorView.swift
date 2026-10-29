import SwiftUI
import MapKit

private struct OtherZone: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let radius: Double
}

private enum DragTarget { case move, resize }

struct SafeZoneEditorView: View {
    let zone: SafeZone?

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var monitor: SafeZoneMonitor
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Home"
    @State private var center: CLLocationCoordinate2D?
    @State private var radius: Double = 200
    @State private var isActive = true
    @State private var editing = true
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var others: [OtherZone] = []
    @State private var dragTarget: DragTarget?
    @State private var grabLat = 0.0
    @State private var grabLon = 0.0
    @State private var awaitingFix = false
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapView
                ScrollView { controls.padding(Theme.Spacing.md) }
            }
            .background(Theme.background)
            .navigationTitle(zone == nil ? "New Safe Zone" : "Edit Safe Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold).disabled(center == nil)
                }
            }
            .task { loadIfNeeded() }
            .onChange(of: location.lastLocation) { _, newValue in
                if awaitingFix, let newValue { place(newValue.coordinate) }
            }
            .confirmationDialog("Delete this safe zone?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: deleteZone)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: Map

    private var mapView: some View {
        let modes: MapInteractionModes = editing ? [] : .all
        let gestureMask: GestureMask = editing ? .all : .none

        return MapReader { proxy in
            Map(position: $position, interactionModes: modes) {
                UserAnnotation()

                ForEach(others) { other in
                    MapCircle(center: other.coordinate, radius: other.radius)
                        .foregroundStyle(Theme.textSecondary.opacity(0.12))
                        .stroke(Theme.textSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                }

                if let center {
                    MapCircle(center: center, radius: radius)
                        .foregroundStyle(Theme.primary.opacity(0.2))
                        .stroke(Theme.primary, lineWidth: 3)

                    Annotation("Centre", coordinate: center) {
                        handle("mappin", tint: Theme.primary)
                    }
                    .annotationTitles(.hidden)

                    Annotation("Resize", coordinate: GeoMath.edgeCoordinate(of: center, meters: radius)) {
                        handle("arrow.left.and.right", tint: Theme.accent)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .gesture(dragGesture(proxy), including: gestureMask)
        }
        .frame(height: 340)
        .overlay(alignment: .top) {
            Text(hint)
                .font(Typography.caption)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
        }
    }

    private var hint: String {
        if !editing { return "Pan and zoom the map" }
        return center == nil ? "Tap the map to place your zone" : "Drag to move · drag the orange handle to resize"
    }

    private func handle(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(tint))
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 2)
            .allowsHitTesting(false)
    }

    // MARK: Drag to move / resize

    private func dragGesture(_ proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard let touch = proxy.convert(value.location, from: .global) else { return }

                guard let center else {            // nothing placed yet: the first touch places it
                    self.center = touch
                    dragTarget = .move
                    return
                }
                if dragTarget == nil {
                    beginDrag(at: value.startLocation, proxy: proxy, center: center)
                }

                switch dragTarget {
                case .resize?:
                    let meters = CLLocation(latitude: center.latitude, longitude: center.longitude)
                        .distance(from: CLLocation(latitude: touch.latitude, longitude: touch.longitude))
                    radius = min(max((meters / 10).rounded() * 10, 50), 2000)
                case .move?:
                    self.center = CLLocationCoordinate2D(latitude: touch.latitude + grabLat,
                                                         longitude: touch.longitude + grabLon)
                case nil:
                    break
                }
            }
            .onEnded { _ in
                dragTarget = nil
                grabLat = 0
                grabLon = 0
            }
    }

    private func beginDrag(at start: CGPoint, proxy: MapProxy, center: CLLocationCoordinate2D) {
        grabLat = 0
        grabLon = 0

        if let edge = proxy.convert(GeoMath.edgeCoordinate(of: center, meters: radius), to: .global),
           hypot(start.x - edge.x, start.y - edge.y) < 44 {
            dragTarget = .resize
            return
        }

        dragTarget = .move
        // Grabbing near the centre pin keeps the zone from jumping under your finger.
        if let centerPoint = proxy.convert(center, to: .global),
           hypot(start.x - centerPoint.x, start.y - centerPoint.y) < 70,
           let startCoordinate = proxy.convert(start, from: .global) {
            grabLat = center.latitude - startCoordinate.latitude
            grabLon = center.longitude - startCoordinate.longitude
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: Theme.Spacing.md) {
            Picker("Mode", selection: $editing) {
                Text("Edit zone").tag(true)
                Text("Move map").tag(false)
            }
            .pickerStyle(.segmented)

            Button { useCurrentLocation() } label: {
                Label("Use my current location", systemImage: "location.fill")
            }
            .buttonStyle(.trail(.secondary))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Radius").font(Typography.headline)
                    Spacer()
                    Text(Fmt.distance(radius)).monospacedDigit()
                }
                .foregroundStyle(Theme.textPrimary)
                Slider(value: $radius, in: 50...2000, step: 10)
            }
            .cardStyle()

            TSField(title: "Zone name", icon: "tag", text: $name, capitalization: .words)

            Toggle("Zone is active", isOn: $isActive)
                .foregroundStyle(Theme.textPrimary)
                .cardStyle()

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if zone != nil {
                Button("Delete Safe Zone", role: .destructive) { confirmDelete = true }
                    .font(Typography.body)
            }
        }
    }

    // MARK: Actions

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        let ownerID = appState.currentUser?.id
        others = SafeZoneStore.zones(ownerID: ownerID, in: context)
            .filter { $0.id != zone?.id }
            .compactMap { other in
                other.id.map { OtherZone(id: $0, coordinate: other.coordinate, radius: other.radiusMeters) }
            }

        guard let zone else { return }
        name = zone.name ?? "Home"
        radius = zone.radiusMeters
        isActive = zone.isActive
        center = zone.coordinate
        position = region(around: zone.coordinate)
    }

    private func useCurrentLocation() {
        if !location.isAuthorized { location.requestPermissionIfNeeded() }
        awaitingFix = true
        if let last = location.lastLocation, abs(last.timestamp.timeIntervalSinceNow) < 120 {
            place(last.coordinate)
        }
        location.requestSingleLocation()
    }

    private func place(_ coordinate: CLLocationCoordinate2D) {
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
        let ownerID = appState.currentUser?.id
        if zone == nil, !SafeZoneStore.canAddZone(ownerID: ownerID, in: context) {
            errorMessage = "You can have up to \(SafeZoneStore.maxZones) safe zones."
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        SafeZoneStore.save(existing: zone, ownerID: ownerID,
                           name: trimmed.isEmpty ? "Safe zone" : trimmed,
                           center: center, radius: radius, isActive: isActive, in: context)
        monitor.reload(ownerID: ownerID, context: context)
        dismiss()
    }

    private func deleteZone() {
        if let zone { SafeZoneStore.delete(zone, in: context) }
        monitor.reload(ownerID: appState.currentUser?.id, context: context)
        dismiss()
    }
}
