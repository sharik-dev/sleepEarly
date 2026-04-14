// sleepEarly/Models/AppSettings.swift
import Foundation
import Combine
import WidgetKit

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let store = UserDefaults(suiteName: "group.sleepappbusharik")!
    private let targetHourKey = "targetHour"
    private let targetMinuteKey = "targetMinute"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let frictionEnabledKey = "frictionEnabled"

    @Published var targetHour: Int {
        didSet {
            store.set(targetHour, forKey: targetHourKey)
            store.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published var targetMinute: Int {
        didSet {
            store.set(targetMinute, forKey: targetMinuteKey)
            store.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published var notificationsEnabled: Bool {
        didSet {
            store.set(notificationsEnabled, forKey: notificationsEnabledKey)
            store.synchronize()
        }
    }
    @Published var frictionEnabled: Bool {
        didSet {
            store.set(frictionEnabled, forKey: frictionEnabledKey)
            store.synchronize()
        }
    }

    private init() {
        self.targetHour = (store.object(forKey: "targetHour") as? Int) ?? 22
        self.targetMinute = (store.object(forKey: "targetMinute") as? Int) ?? 0
        self.notificationsEnabled = (store.object(forKey: "notificationsEnabled") as? Bool) ?? true
        self.frictionEnabled = (store.object(forKey: "frictionEnabled") as? Bool) ?? true
    }

    /// Heure cible sous forme de Date pour aujourd'hui
    var targetBedtimeToday: Date {
        Calendar.current.date(
            bySettingHour: targetHour,
            minute: targetMinute,
            second: 0,
            of: Date()
        )!
    }
}
