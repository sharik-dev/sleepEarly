// DeviceActivityMonitor/DeviceActivityMonitorExtension.swift
import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let defaults = UserDefaults(suiteName: "group.sleepappbusharik")
    // Default store — matches what the main app uses
    private let store = ManagedSettingsStore()

    /// Bedtime reached → shield selected apps
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        applyShield()
    }

    /// Morning (6:00) → remove all shields
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        store.clearAllSettings()
    }

    // MARK: - Private

    private func applyShield() {
        guard
            let data = defaults?.data(forKey: "blockedAppsSelection"),
            let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
    }
}
