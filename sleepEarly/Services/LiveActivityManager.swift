// sleepEarly/Services/LiveActivityManager.swift
import Foundation

#if canImport(ActivityKit)
import ActivityKit

enum LiveActivityManager {
    private static var currentActivity: Activity<SleepCountdownAttributes>?

    static func start(targetBedtime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let remaining = max(0, Int(targetBedtime.timeIntervalSinceNow / 60))
        let attributes = SleepCountdownAttributes(targetBedtime: targetBedtime)
        let state = SleepCountdownAttributes.ContentState(minutesRemaining: remaining, isOverdue: false)
        currentActivity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: targetBedtime)
        )
    }

    static func update(minutesRemaining: Int) {
        let state = SleepCountdownAttributes.ContentState(
            minutesRemaining: minutesRemaining,
            isOverdue: minutesRemaining <= 0
        )
        Task { await currentActivity?.update(.init(state: state, staleDate: nil)) }
    }

    static func stop() {
        Task { await currentActivity?.end(nil, dismissalPolicy: .immediate) }
        currentActivity = nil
    }
}
#endif
