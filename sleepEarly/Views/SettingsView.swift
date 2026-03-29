// sleepEarly/Views/SettingsView.swift
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedHour: Int = 22
    @State private var selectedMinute: Int = 0

    var body: some View {
        Form {
            Section("Heure de coucher") {
                HStack {
                    Text("Cible")
                    Spacer()
                    Picker("Heure", selection: $selectedHour) {
                        ForEach(18..<25, id: \.self) { Text("\($0)h").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    Picker("Minute", selection: $selectedMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: ":%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 70)
                }
                .onChange(of: selectedHour) { newValue in
                    settings.targetHour = newValue
                    reschedule()
                }
                .onChange(of: selectedMinute) { newValue in
                    settings.targetMinute = newValue
                    reschedule()
                }
            }

            Section("Comportement") {
                Toggle("Notifications", isOn: $settings.notificationsEnabled)
                    .onChange(of: settings.notificationsEnabled) { enabled in
                        if enabled { reschedule() } else { NotificationScheduler.cancelAll() }
                    }
                Toggle("Écran de friction à l'heure cible", isOn: $settings.frictionEnabled)
            }

            Section("Permissions") {
                Button("Réautoriser HealthKit") {
                    Task { await HealthKitService.shared.requestAuthorization() }
                }
                Button("Réautoriser les notifications") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
            }
        }
        .navigationTitle("Réglages")
        .onAppear {
            selectedHour = settings.targetHour
            selectedMinute = settings.targetMinute
        }
    }

    private func reschedule() {
        guard settings.notificationsEnabled else { return }
        NotificationScheduler.scheduleAll(
            targetHour: settings.targetHour,
            targetMinute: settings.targetMinute
        )
    }
}
