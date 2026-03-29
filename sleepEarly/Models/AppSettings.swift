// sleepEarly/Models/AppSettings.swift
import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let store = NSUbiquitousKeyValueStore.default
    private let targetHourKey = "targetHour"
    private let targetMinuteKey = "targetMinute"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let frictionEnabledKey = "frictionEnabled"

    @Published var targetHour: Int {
        didSet { store.set(targetHour, forKey: targetHourKey); store.synchronize() }
    }
    @Published var targetMinute: Int {
        didSet { store.set(targetMinute, forKey: targetMinuteKey); store.synchronize() }
    }
    @Published var notificationsEnabled: Bool {
        didSet { store.set(notificationsEnabled, forKey: notificationsEnabledKey); store.synchronize() }
    }
    @Published var frictionEnabled: Bool {
        didSet { store.set(frictionEnabled, forKey: frictionEnabledKey); store.synchronize() }
    }

    private init() {
        store.synchronize()
        self.targetHour = store.object(forKey: targetHourKey) != nil
            ? Int(store.longLong(forKey: targetHourKey)) : 22
        self.targetMinute = store.object(forKey: targetMinuteKey) != nil
            ? Int(store.longLong(forKey: targetMinuteKey)) : 0
        self.notificationsEnabled = store.object(forKey: notificationsEnabledKey) != nil
            ? store.bool(forKey: notificationsEnabledKey) : true
        self.frictionEnabled = store.object(forKey: frictionEnabledKey) != nil
            ? store.bool(forKey: frictionEnabledKey) : true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    @objc private func iCloudDidChange() {
        DispatchQueue.main.async {
            self.targetHour = Int(self.store.longLong(forKey: self.targetHourKey))
            self.targetMinute = Int(self.store.longLong(forKey: self.targetMinuteKey))
            self.notificationsEnabled = self.store.bool(forKey: self.notificationsEnabledKey)
            self.frictionEnabled = self.store.bool(forKey: self.frictionEnabledKey)
        }
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
