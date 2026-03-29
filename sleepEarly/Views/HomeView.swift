// sleepEarly/Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: SleepStore
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var streak: Int {
        StreakEngine.currentStreak(
            records: store.records,
            targetHour: settings.targetHour,
            targetMinute: settings.targetMinute
        )
    }

    private var timeRemaining: String {
        let target = settings.targetBedtimeToday
        let diff = target.timeIntervalSince(now)
        guard diff > 0 else { return "C'est l'heure !" }
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        let s = Int(diff) % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%02d:%02d", m, s)
    }

    private var isWindDownPeriod: Bool {
        let target = settings.targetBedtimeToday
        let diff = target.timeIntervalSince(now)
        return diff >= 0 && diff <= 30 * 60
    }

    private var shouldShowSleepButton: Bool {
        let target = settings.targetBedtimeToday
        let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: target)!
        return now >= oneHourBefore
    }

    var body: some View {
        ZStack {
            Color(isWindDownPeriod ? .systemIndigo : .systemBackground)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2), value: isWindDownPeriod)

            VStack(spacing: 32) {
                // Streak
                VStack(spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(streak > 0 ? .yellow : .secondary)
                    Text("nuits consécutives")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Countdown
                VStack(spacing: 8) {
                    Text(timeRemaining)
                        .font(.system(size: 48, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isWindDownPeriod ? .white : .primary)
                    Text("avant \(settings.targetHour)h\(String(format: "%02d", settings.targetMinute))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Bouton Je dors
                if shouldShowSleepButton {
                    Button {
                        Task { try? await HealthKitService.shared.saveBedtime(Date()) }
                        store.save(bedtime: Date(), source: .manual)
                    } label: {
                        Label("Je dors 🌙", systemImage: "bed.double.fill")
                            .font(.title2.bold())
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(.indigo)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
        }
        .onReceive(timer) { now = $0 }
    }
}
