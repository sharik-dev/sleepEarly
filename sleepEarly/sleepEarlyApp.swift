// sleepEarly/sleepEarlyApp.swift
import SwiftUI
import UserNotifications

@main
struct sleepEarlyApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var store = SleepStore.shared
    @State private var showFriction = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .fullScreenCover(isPresented: $showFriction) {
                    FrictionView(isPresented: $showFriction)
                }
                .onAppear {
                    requestPermissions()
                    rescheduleNotifications()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .init("SleepEarlyShowFriction")
                    )
                ) { _ in
                    if settings.frictionEnabled { showFriction = true }
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
