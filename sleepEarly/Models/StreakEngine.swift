// sleepEarly/Models/StreakEngine.swift
import Foundation

enum StreakEngine {

    /// Streak courant : nombre de jours consécutifs (en remontant depuis hier)
    /// où l'heure de coucher est avant targetHour:targetMinute.
    static func currentStreak(records: [SleepRecord], targetHour: Int, targetMinute: Int) -> Int {
        let sorted = records.sorted { $0.date > $1.date }
        var streak = 0
        var expectedDate = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        )

        for record in sorted {
            let recordDay = Calendar.current.startOfDay(for: record.date)
            guard recordDay == expectedDate else { break }
            guard let bedtime = record.bedtime else { break }
            guard sleptBeforeTarget(bedtime: bedtime, targetHour: targetHour, targetMinute: targetMinute) else { break }
            streak += 1
            expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: expectedDate)!
        }
        return streak
    }

    /// Meilleur streak jamais atteint dans l'historique.
    static func bestStreak(records: [SleepRecord], targetHour: Int, targetMinute: Int) -> Int {
        let sorted = records.sorted { $0.date < $1.date }
        var best = 0
        var current = 0
        var previousDate: Date?

        for record in sorted {
            let recordDay = Calendar.current.startOfDay(for: record.date)
            guard let bedtime = record.bedtime,
                  sleptBeforeTarget(bedtime: bedtime, targetHour: targetHour, targetMinute: targetMinute) else {
                best = max(best, current)
                current = 0
                previousDate = nil
                continue
            }

            if let prev = previousDate,
               let expectedNext = Calendar.current.date(byAdding: .day, value: 1, to: prev),
               recordDay == Calendar.current.startOfDay(for: expectedNext) {
                current += 1
            } else {
                best = max(best, current)
                current = 1
            }
            previousDate = recordDay
        }
        return max(best, current)
    }

    private static func sleptBeforeTarget(bedtime: Date, targetHour: Int, targetMinute: Int) -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: bedtime)
        let minute = cal.component(.minute, from: bedtime)
        return hour < targetHour || (hour == targetHour && minute <= targetMinute)
    }
}
