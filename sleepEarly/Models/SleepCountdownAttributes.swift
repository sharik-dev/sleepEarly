// sleepEarly/Models/SleepCountdownAttributes.swift
// Dupliqué ici pour que LiveActivityManager (main app) puisse y accéder.
// La même définition existe dans sleepEarlyLiveActivity/ pour l'extension.
import ActivityKit
import Foundation

/// Shared attributes type used by the app and Live Activity extension.
struct SleepCountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var minutesRemaining: Int
        var isOverdue: Bool
    }
    var targetBedtime: Date
}
