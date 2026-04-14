// sleepEarly/Services/ScreenTimeManager.swift
import FamilyControls
import ManagedSettings
import DeviceActivity
import Foundation

@MainActor
final class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    static let appGroupID   = "group.sleepappbusharik"
    static let selectionKey = "blockedAppsSelection"
    static let activityName = DeviceActivityName("com.sleepEarlyBySharik.bedtime")

    private let defaults = UserDefaults(suiteName: appGroupID)!
    // Use default store — same store the extension reads/writes
    private let store = ManagedSettingsStore()

    @Published var authStatus: AuthorizationStatus = .notDetermined
    @Published var selection = FamilyActivitySelection()
    @Published var isEnabled: Bool = false {
        didSet {
            defaults.set(isEnabled, forKey: "screenTimeEnabled")
            defaults.synchronize()
        }
    }

    private init() {
        authStatus = AuthorizationCenter.shared.authorizationStatus
        isEnabled = defaults.bool(forKey: "screenTimeEnabled")
        if let data = defaults.data(forKey: Self.selectionKey),
           let saved = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("[ScreenTime] Auth error: \(error)")
        }
        authStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - App Selection

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        guard let data = try? PropertyListEncoder().encode(newSelection) else { return }
        defaults.set(data, forKey: Self.selectionKey)
        defaults.synchronize()
        // Re-apply shield if currently active
        if isEnabled && isPastBedtime() {
            applyShield()
        }
    }

    // MARK: - Enable / Disable

    func enable(bedtimeHour: Int, bedtimeMinute: Int) {
        isEnabled = true
        scheduleMonitoring(bedtimeHour: bedtimeHour, bedtimeMinute: bedtimeMinute)
        // If bedtime already passed today, apply shield immediately
        if isPastBedtime(hour: bedtimeHour, minute: bedtimeMinute) {
            applyShield()
        }
    }

    func disable() {
        isEnabled = false
        DeviceActivityCenter().stopMonitoring([Self.activityName])
        store.clearAllSettings()
    }

    func rescheduleIfNeeded(bedtimeHour: Int, bedtimeMinute: Int) {
        guard isEnabled else { return }
        scheduleMonitoring(bedtimeHour: bedtimeHour, bedtimeMinute: bedtimeMinute)
    }

    /// Called when app enters foreground — re-applies shield if needed
    func checkShieldOnForeground(bedtimeHour: Int, bedtimeMinute: Int) {
        guard isEnabled, hasSelection else { return }
        if isPastBedtime(hour: bedtimeHour, minute: bedtimeMinute) {
            applyShield()
        } else {
            store.clearAllSettings()
        }
    }

    // MARK: - Shield (applied from main app for immediate effect)

    func applyShield() {
        guard hasSelection else { return }
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
    }

    // MARK: - Scheduling (extension handles the timed trigger)

    private func scheduleMonitoring(bedtimeHour: Int, bedtimeMinute: Int) {
        let center = DeviceActivityCenter()
        center.stopMonitoring([Self.activityName])

        // Awake interval: 6:00 → bedtime
        // intervalDidEnd at bedtime  → extension applies shield
        // intervalDidStart at 6:00   → extension clears shield
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 6, minute: 0),
            intervalEnd: DateComponents(hour: bedtimeHour, minute: bedtimeMinute),
            repeats: true
        )
        do {
            try center.startMonitoring(Self.activityName, during: schedule)
        } catch {
            print("[ScreenTime] Schedule error: \(error)")
        }
    }

    // MARK: - Helpers

    private func isPastBedtime(hour: Int? = nil, minute: Int? = nil) -> Bool {
        let cal = Calendar.current
        let now = Date()
        let h = hour ?? cal.component(.hour, from: now)
        let m = minute ?? cal.component(.minute, from: now)
        guard let bedtime = cal.date(bySettingHour: h, minute: m, second: 0, of: now) else { return false }
        return now >= bedtime
    }

    var isAuthorized: Bool { authStatus == .approved }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        if apps == 0 && cats == 0 { return "Aucune app sélectionnée" }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps > 1 ? "s" : "")") }
        if cats > 0 { parts.append("\(cats) catégorie\(cats > 1 ? "s" : "")") }
        return parts.joined(separator: " · ")
    }
}
