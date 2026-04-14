// sleepEarly/sleepEarlyApp.swift
import SwiftUI
import UserNotifications

@main
struct sleepEarlyApp: App {
    @StateObject private var settings    = AppSettings.shared
    @StateObject private var store       = SleepStore.shared
    @StateObject private var screenTime  = ScreenTimeManager.shared
    @State private var showFriction = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(screenTime)
                .fullScreenCover(isPresented: $showFriction) {
                    FrictionView(isPresented: $showFriction)
                }
                .onAppear {
                    requestPermissions()
                    rescheduleNotifications()
                    checkFriction()
                    Task {
                        if !screenTime.isAuthorized {
                            await screenTime.requestAuthorization()
                        }
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .init("SleepEarlyShowFriction"))
                ) { _ in
                    if settings.frictionEnabled { showFriction = true }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    checkFriction()
                    screenTime.checkShieldOnForeground(
                        bedtimeHour: settings.targetHour,
                        bedtimeMinute: settings.targetMinute
                    )
                }
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(settings)
        } label: {
            Label("sleepEarly", systemImage: "moon.fill")
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    /// Show friction if bedtime has passed within the last 8 hours
    private func checkFriction() {
        guard settings.frictionEnabled else { return }
        let secondsPast = Date().timeIntervalSince(settings.targetBedtimeToday)
        if secondsPast >= 0 && secondsPast < 8 * 3600 {
            showFriction = true
        }
    }

    private func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        Task { await HealthKitService.shared.requestAuthorization() }
    }

    private func rescheduleNotifications() {
        guard settings.notificationsEnabled else {
            NotificationScheduler.cancelAll()
            return
        }
        NotificationScheduler.scheduleAll(
            targetHour: settings.targetHour,
            targetMinute: settings.targetMinute
        )
    }
}
