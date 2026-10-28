import Foundation
import ActivityKit
import Combine

@MainActor
final class LiveActivityManager: ObservableObject {
    private let recorder: TrailRecorder
    private var activity: Activity<TrailActivityAttributes>?
    private var lastDistance: Double = 0
    private var cancellables = Set<AnyCancellable>()

    init(recorder: TrailRecorder) {
        self.recorder = recorder
        endLeftoverActivities()

        recorder.$state
            .removeDuplicates()
            .sink { [weak self] state in self?.stateChanged(state) }
            .store(in: &cancellables)

        // Distance changes constantly; push at most every 10 seconds.
        recorder.$distanceMeters
            .throttle(for: .seconds(10), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] distance in
                guard let self else { return }
                self.push(paused: self.recorder.state == .paused, distance: distance)
            }
            .store(in: &cancellables)
    }

    // MARK: State

    private func stateChanged(_ state: TrailRecorder.State) {
        switch state {
        case .idle:
            endActivity()
        case .recording, .paused:
            let paused = state == .paused
            if activity == nil {
                startActivity(paused: paused)
            } else {
                push(paused: paused, distance: recorder.distanceMeters)
            }
        }
    }

    private func makeState(paused: Bool, distance: Double) -> TrailActivityAttributes.ContentState {
        let elapsed = recorder.elapsed
        return TrailActivityAttributes.ContentState(
            distanceMeters: distance,
            elapsedSeconds: elapsed,
            isPaused: paused,
            timerStart: Date().addingTimeInterval(-elapsed)
        )
    }

    // MARK: Activity

    private func startActivity(paused: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        lastDistance = recorder.distanceMeters

        let attributes = TrailActivityAttributes(startedAt: Date().addingTimeInterval(-recorder.elapsed))
        let content = ActivityContent(state: makeState(paused: paused, distance: lastDistance), staleDate: nil)
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            print("Live Activity failed to start: \(error)")
        }
    }

    private func push(paused: Bool, distance: Double) {
        guard let activity else { return }
        lastDistance = distance
        let content = ActivityContent(state: makeState(paused: paused, distance: distance),
                                      staleDate: Date().addingTimeInterval(3600))
        Task { await activity.update(content) }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        let final = ActivityContent(state: makeState(paused: true, distance: lastDistance), staleDate: nil)
        Task { await activity.end(final, dismissalPolicy: .immediate) }
    }

    /// Cleans up an activity left over from a previous run of the app.
    private func endLeftoverActivities() {
        for leftover in Activity<TrailActivityAttributes>.activities {
            Task { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
