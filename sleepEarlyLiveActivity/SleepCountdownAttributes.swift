// sleepEarlyLiveActivity/SleepCountdownAttributes.swift
import ActivityKit
import Foundation

struct SleepCountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var minutesRemaining: Int
        var isOverdue: Bool
    }
    var targetBedtime: Date
}
