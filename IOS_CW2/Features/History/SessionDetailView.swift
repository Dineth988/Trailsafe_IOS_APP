import SwiftUI
import MapKit

struct SessionDetailView: View {
    let session: TrailSession

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    private let segments: [[CLLocationCoordinate2D]]
    private let start: CLLocationCoordinate2D?
    private let end: CLLocationCoordinate2D?
    private let position: MapCameraPosition

    init(session: TrailSession) {
        self.session = session
        let built = RouteBuilder.segments(from: RouteBuilder.sortedPoints(of: session))
        segments = built.filter { $0.count > 1 }
        start = built.first?.first
        end = built.last?.last
        if let rect = RouteBuilder.boundingRect(for: built) {
            position = .rect(rect)
        } else {
            position = .automatic
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Map(initialPosition: position, interactionModes: [.pan, .zoom]) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, coordinates in
                        MapPolyline(coordinates: coordinates)
                            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    if let start { Marker("Start", systemImage: "flag.fill", coordinate: start).tint(Theme.primary) }
                    if let end { Marker("End", systemImage: "mappin", coordinate: end).tint(Theme.accent) }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))

                if let started = session.startedAt {
                    Text(started.formatted(date: .complete, time: .shortened))
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }

                let d = Fmt.distanceParts(session.distanceMeters)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    StatTile(title: "Distance", value: d.value, unit: d.unit)
                    StatTile(title: "Duration", value: Fmt.duration(session.durationSeconds))
                    StatTile(title: "Avg pace",
                             value: Fmt.pace(distanceMeters: session.distanceMeters, seconds: session.durationSeconds),
                             unit: "/km")
                    StatTile(title: "Avg speed",
                             value: Fmt.speedKmh(distanceMeters: session.distanceMeters, seconds: session.durationSeconds),
                             unit: "km/h")
                }

                Button("Delete Trail", role: .destructive) { confirmDelete = true }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background)
        .navigationTitle("Trail")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this trail?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(session)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The recorded route will be removed from this device.")
        }
    }
}
