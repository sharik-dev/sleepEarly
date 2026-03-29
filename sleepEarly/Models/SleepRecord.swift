// sleepEarly/Models/SleepRecord.swift
import Foundation

struct SleepRecord: Codable, Identifiable {
    let id: UUID
    let date: Date          // minuit du jour concerné (clé)
    let bedtime: Date?      // heure réelle d'endormissement (nil si pas de données)
    let source: RecordSource

    enum RecordSource: String, Codable {
        case manual      // bouton "Je dors"
        case healthKit   // lu depuis HealthKit
    }

    init(date: Date, bedtime: Date?, source: RecordSource) {
        self.id = UUID()
        self.date = date
        self.bedtime = bedtime
        self.source = source
    }
}
