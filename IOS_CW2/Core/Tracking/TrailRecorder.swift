import CoreLocation
import CoreData
import Combine

@MainActor
final class TrailRecorder: ObservableObject {
    enum State: Equatable { case idle, recording, paused }

    @Published private(set) var state: State = .idle
    @Published private(set) var segments: [[CLLocationCoordinate2D]] = []
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var elapsed: TimeInterval = 0
    /// Set when a trail is finished; the dashboard shows the summary for it.
    @Published var completedSession: TrailSession?

    var paceText: String { Fmt.pace(distanceMeters: distanceMeters, seconds: elapsed) }

    private let location: LocationService
    private let context: NSManagedObjectContext

    private var session: TrailSession?
    private var pending: [CLLocation] = []
    private var lastAccepted: CLLocation?
    private var accumulated: TimeInterval = 0
    private var resumedAt: Date?
    private var ticker: Timer?
    private var lastFlush = Date()

    private let flushBatchSize = 10
    private let flushInterval: TimeInterval = 20
    private let maxAccuracy: CLLocationAccuracy = 50   // ignore fixes worse than 50 m

    init(
        location: LocationService,
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) {
        self.location = location
        self.context = context
        location.onLocations = { [weak self] locations in
            self?.handle(locations)
        }
    }

    // MARK: Controls

    func start(ownerID: UUID?) {
        guard state == .idle else { return }

        let newSession = TrailSession.make(in: context)
        newSession.id = UUID()
        newSession.ownerID = ownerID
        newSession.startedAt = Date()
        newSession.status = .active
        save()

        session = newSession
        resetMetrics()
        segments = [[]]
        state = .recording
        resumeClock()
        location.startTracking()
        location.requestAlwaysUpgradeIfNeeded()
    }

    func pause() {
        guard state == .recording else { return }
        flush()
        freezeClock()
        location.stopTracking()      // saves battery while paused
        lastAccepted = nil           // don't count the gap as distance
        session?.status = .paused
        save()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        segments.append([])
        session?.status = .active
        state = .recording
        resumeClock()
        location.startTracking()
    }

    func finish() {
        guard state != .idle, let session else { return }
        flush()
        freezeClock()
        location.stopTracking()

        session.endedAt = Date()
        session.durationSeconds = accumulated
        session.distanceMeters = distanceMeters
        session.status = .completed
        save()

        completedSession = session
        self.session = nil
        resetMetrics()
        segments = []
        state = .idle
    }

    func discard() {
        guard state != .idle else { return }
        stopTicker()
        location.stopTracking()
        if let session { context.delete(session) }   // points are cascade-deleted
        save()
        session = nil
        resetMetrics()
        segments = []
        state = .idle
    }

    func dismissSummary() {
        completedSession = nil
    }

    /// Call when the app goes to the background.
    func persistNow() {
        if state != .idle { flush() }
    }

    // MARK: Recovery

    /// If the app was killed mid-trail, restore the newest unfinished session as "paused".
    func recoverIfNeeded(ownerID: UUID?) {
        guard state == .idle, completedSession == nil, let ownerID else { return }

        let request = TrailSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "ownerID == %@ AND (statusRaw == %@ OR statusRaw == %@)",
            ownerID as CVarArg, TrailSession.Status.active.rawValue, TrailSession.Status.paused.rawValue
        )
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        guard let unfinished = try? context.fetch(request), let newest = unfinished.first else { return }

        // Older leftovers are closed out so they don't pile up.
        for old in unfinished.dropFirst() {
            old.status = .completed
            old.endedAt = old.endedAt ?? RouteBuilder.sortedPoints(of: old).last?.timestamp ?? old.startedAt
        }

        session = newest
        segments = RouteBuilder.segments(from: RouteBuilder.sortedPoints(of: newest))
        if segments.isEmpty { segments = [[]] }
        distanceMeters = newest.distanceMeters
        accumulated = newest.durationSeconds
        elapsed = accumulated
        lastAccepted = nil
        resumedAt = nil
        newest.status = .paused
        save()
        state = .paused
    }

    // MARK: Location handling

    private func handle(_ locations: [CLLocation]) {
        guard state == .recording else { return }

        for fix in locations {
            guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= maxAccuracy else { continue }
            // Ignore cached fixes older than the moment we (re)started.
            if let resumedAt, fix.timestamp < resumedAt.addingTimeInterval(-5) { continue }

            if let last = lastAccepted {
                let delta = fix.distance(from: last)
                guard delta >= 3 else { continue }
                distanceMeters += delta
            }
            lastAccepted = fix
            segments[segments.count - 1].append(fix.coordinate)
            pending.append(fix)
        }

        if pending.count >= flushBatchSize || Date().timeIntervalSince(lastFlush) > flushInterval {
            flush()
        }
    }

    // MARK: Persistence

    private func flush() {
        guard let session else { return }
        for fix in pending {
            let point = LocationPoint.make(in: context)
            point.id = UUID()
            point.latitude = fix.coordinate.latitude
            point.longitude = fix.coordinate.longitude
            point.altitude = fix.altitude
            point.accuracy = fix.horizontalAccuracy
            point.timestamp = fix.timestamp
            point.session = session
        }
        pending.removeAll()
        session.distanceMeters = distanceMeters
        session.durationSeconds = currentElapsed
        lastFlush = Date()
        save()
    }

    private func save() {
        guard context.hasChanges else { return }
        do { try context.save() } catch { print("Core Data save error: \(error)") }
    }

    // MARK: Clock

    private var currentElapsed: TimeInterval {
        accumulated + (resumedAt.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func resumeClock() {
        resumedAt = Date()
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func freezeClock() {
        accumulated = currentElapsed
        resumedAt = nil
        elapsed = accumulated
        stopTicker()
    }

    private func tick() {
        guard resumedAt != nil else { return }
        elapsed = currentElapsed
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func resetMetrics() {
        pending.removeAll()
        lastAccepted = nil
        distanceMeters = 0
        elapsed = 0
        accumulated = 0
        resumedAt = nil
    }
}
