// sleepEarly/Services/NotificationScheduler.swift
import UserNotifications
import Foundation

enum NotificationScheduler {

    private struct WindDownStep {
        let minutesBefore: Int
        let body: String
    }

    private static let steps: [WindDownStep] = [
        WindDownStep(minutesBefore: 30, body: "Dans 30 min, c'est l'heure de dormir 🌙"),
        WindDownStep(minutesBefore: 25, body: "25 minutes restantes — commence à déposer le téléphone"),
        WindDownStep(minutesBefore: 20, body: "20 min — pose Netflix, prépare-toi 🧘"),
        WindDownStep(minutesBefore: 15, body: "15 minutes restantes"),
        WindDownStep(minutesBefore: 10, body: "10 min — dernière chance de finir ce que tu fais"),
        WindDownStep(minutesBefore: 5,  body: "5 min ⚠️ C'est presque l'heure !"),
        WindDownStep(minutesBefore: 0,  body: "C'est l'heure. Pose tout et dors. 🌛"),
    ]

    /// Construit les UNNotificationRequest sans les enregistrer (testable).
    static func buildRequests(targetHour: Int, targetMinute: Int) -> [UNNotificationRequest] {
        steps.enumerated().map { index, step in
            let content = UNMutableNotificationContent()
            content.title = "sleepEarly"
            content.body = step.body
            content.sound = index < 5 ? .default : .defaultCritical

            let (hour, minute) = minutesBefore(step.minutesBefore, fromHour: targetHour, fromMinute: targetMinute)
            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return UNNotificationRequest(
                identifier: "sleepearly-winddown-\(index)",
                content: content,
                trigger: trigger
            )
        }
    }

    /// Planifie toutes les notifications (annule les précédentes).
    static func scheduleAll(targetHour: Int, targetMinute: Int) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<steps.count).map { "sleepearly-winddown-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let requests = buildRequests(targetHour: targetHour, targetMinute: targetMinute)
        for request in requests {
            center.add(request)
        }
    }

    /// Annule toutes les notifications sleepEarly.
    static func cancelAll() {
        let ids = (0..<steps.count).map { "sleepearly-winddown-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Calcule l'heure/minute N minutes avant un target.
    private static func minutesBefore(_ n: Int, fromHour: Int, fromMinute: Int) -> (Int, Int) {
        var total = fromHour * 60 + fromMinute - n
        if total < 0 { total += 24 * 60 }
        return (total / 60, total % 60)
    }
}
