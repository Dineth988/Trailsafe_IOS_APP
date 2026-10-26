import SwiftUI
import MapKit

private struct RouteMarker: Identifiable {
    let id: String
    let title: String
    let icon: String
    let coordinate: CLLocationCoordinate2D
    let tint: Color
}

struct SessionSummaryView: View {
    let session: TrailSession
    let onDone: () -> Void

    private let segments: [[CLLocationCoordinate2D]]
    private let markers: [RouteMarker]
    private let position: MapCameraPosition

    init(session: TrailSession, onDone: @escaping () -> Void) {
        self.session = session
        self.onDone = onDone

        let built = RouteBuilder.segments(from: RouteBuilder.sortedPoints(of: session))
        segments = built.filter { $0.count > 1 }

        var items: [RouteMarker] = []
        if let start = built.first?.first {
            items.append(RouteMarker(id: "start", title: "Start", icon: "flag.fill",
                                     coordinate: start, tint: Theme.primary))
        }
        if let end = built.last?.last {
            items.append(RouteMarker(id: "end", title: "End", icon: "mappin",
                                     coordinate: end, tint: Theme.accent))
        }
        markers = items

        if let rect = RouteBuilder.boundingRect(for: built) {
            position = .rect(rect)
        } else {
            position = .automatic
        }
    }

    private var distance: Double { session.distanceMeters }
    private var duration: Double { session.durationSeconds }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    routeMap

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trail complete")
                            .font(Typography.largeTitle)
                            .foregroundStyle(Theme.textPrimary)
                        if let started = session.startedAt {
                            Text(started.formatted(date: .abbreviated, time: .shortened))
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    let d = Fmt.distanceParts(distance)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                        StatTile(title: "Distance", value: d.value, unit: d.unit)
                        StatTile(title: "Duration", value: Fmt.duration(duration))
                        StatTile(title: "Avg pace", value: Fmt.pace(distanceMeters: distance, seconds: duration), unit: "/km")
                        StatTile(title: "Avg speed", value: Fmt.speedKmh(distanceMeters: distance, seconds: duration), unit: "km/h")
                        StatTile(title: "GPS points", value: "\(session.points?.count ?? 0)")
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.background)
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var routeMap: some View {
        Map(initialPosition: position, interactionModes: [.pan, .zoom]) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, coordinates in
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            ForEach(markers) { marker in
                Marker(marker.title, systemImage: marker.icon, coordinate: marker.coordinate)
                    .tint(marker.tint)
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
    }
}
