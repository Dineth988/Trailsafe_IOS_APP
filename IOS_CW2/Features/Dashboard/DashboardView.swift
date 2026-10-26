import SwiftUI
import MapKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var recorder: TrailRecorder
    @EnvironmentObject private var location: LocationService
    @Environment(\.managedObjectContext) private var context
    @Environment(\.openURL) private var openURL

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showStartSheet = false
    @State private var showStopSheet = false
    @State private var weekly = WeeklyStats()

    var body: some View {
        ZStack(alignment: .top) {
            map
            topOverlay
        }
        .safeAreaInset(edge: .bottom) { controlPanel }
        .sheet(isPresented: $showStartSheet) {
            StartTrailSheet(
                onStart: {
                    showStartSheet = false
                    recorder.start(ownerID: appState.currentUser?.id)
                },
                onCancel: { showStartSheet = false }
            )
        }
        .sheet(isPresented: $showStopSheet) {
            StopTrailSheet(
                distanceText: Fmt.distance(recorder.distanceMeters),
                durationText: Fmt.duration(recorder.elapsed),
                onFinish: { showStopSheet = false; recorder.finish() },
                onDiscard: { showStopSheet = false; recorder.discard() },
                onContinue: { showStopSheet = false }
            )
        }
        .fullScreenCover(isPresented: summaryBinding) {
            if let session = recorder.completedSession {
                SessionSummaryView(session: session) { recorder.dismissSummary() }
            }
        }
        .task {
            location.requestPermissionIfNeeded()
            recorder.recoverIfNeeded(ownerID: appState.currentUser?.id)
            refreshWeekly()
        }
        .onChange(of: recorder.state) { _, newState in
            if newState == .recording {
                position = .userLocation(followsHeading: false, fallback: .automatic)
            }
            if newState == .idle { refreshWeekly() }
        }
    }

    // MARK: Map

    private var drawableSegments: [[CLLocationCoordinate2D]] {
        recorder.segments.filter { $0.count > 1 }
    }

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(Array(drawableSegments.enumerated()), id: \.offset) { _, coordinates in
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea(edges: .top)
    }

    private var topOverlay: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                SOSButton(size: 56) {
                    // SOS flow arrives on Day 3.
                }
                Spacer()
            }
            if location.isDenied { permissionBanner }
        }
        .padding(Theme.Spacing.md)
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(Theme.accent)
            Text("Location access is off, so TrailSafe can't record trails.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(Typography.caption.weight(.semibold))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    // MARK: Control panel

    private var controlPanel: some View {
        VStack(spacing: Theme.Spacing.md) {
            if recorder.state != .idle { statusRow }
            HStack(spacing: Theme.Spacing.sm) { stats }
            buttons
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(recorder.state == .recording ? Color.red : Theme.accent)
                .frame(width: 8, height: 8)
            Text(recorder.state == .recording ? "Recording" : "Paused")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }

    @ViewBuilder
    private var stats: some View {
        if recorder.state == .idle {
            let d = Fmt.distanceParts(weekly.distanceMeters)
            StatTile(title: "Last 7 days", value: d.value, unit: d.unit)
            StatTile(title: "Trails", value: "\(weekly.sessions)")
            StatTile(title: "Time", value: Fmt.duration(weekly.durationSeconds))
        } else {
            let d = Fmt.distanceParts(recorder.distanceMeters)
            StatTile(title: "Distance", value: d.value, unit: d.unit)
            StatTile(title: "Time", value: Fmt.duration(recorder.elapsed))
            StatTile(title: "Pace", value: recorder.paceText, unit: "/km")
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch recorder.state {
        case .idle:
            Button("Start Trail", action: startTapped)
                .buttonStyle(.trail(.accent))
        case .recording:
            HStack(spacing: Theme.Spacing.sm) {
                Button("Pause") { recorder.pause() }.buttonStyle(.trail(.secondary))
                Button("Finish") { showStopSheet = true }.buttonStyle(.trail())
            }
        case .paused:
            HStack(spacing: Theme.Spacing.sm) {
                Button("Resume") { recorder.resume() }.buttonStyle(.trail())
                Button("Finish") { showStopSheet = true }.buttonStyle(.trail(.secondary))
            }
        }
    }

    // MARK: Actions

    private func startTapped() {
        switch location.authorizationStatus {
        case .notDetermined:
            location.requestPermissionIfNeeded()
        case .denied, .restricted:
            break   // the banner explains and links to Settings
        default:
            showStartSheet = true
        }
    }

    private func refreshWeekly() {
        weekly = TrailStore.weeklyStats(ownerID: appState.currentUser?.id, in: context)
    }

    private var summaryBinding: Binding<Bool> {
        Binding(
            get: { recorder.completedSession != nil },
            set: { if !$0 { recorder.dismissSummary() } }
        )
    }
}
