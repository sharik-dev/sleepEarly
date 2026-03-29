// sleepEarlyWidget/CountdownEntry.swift
import WidgetKit
import Foundation

struct CountdownEntry: TimelineEntry {
    let date: Date
    let targetBedtime: Date
    let minutesRemaining: Int

    var urgencyLevel: UrgencyLevel {
        if minutesRemaining <= 0 { return .overdue }
        if minutesRemaining <= 10 { return .critical }
        if minutesRemaining <= 30 { return .warning }
        return .normal
    }

    enum UrgencyLevel { case normal, warning, critical, overdue }
}
