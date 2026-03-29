// sleepEarly/Services/SleepStore.swift
import Foundation

final class SleepStore: ObservableObject {
    static let shared = SleepStore()
    private let key = "sleep_records_v1"

    @Published private(set) var records: [SleepRecord] = []

    private init() {
        load()
    }

    func save(bedtime: Date, source: SleepRecord.RecordSource) {
        let night = Calendar.current.startOfDay(for: bedtime)
        // Remplace un éventuel enregistrement existant pour cette nuit
        records.removeAll { Calendar.current.isDate($0.date, inSameDayAs: night) }
        let record = SleepRecord(date: night, bedtime: bedtime, source: source)
        records.append(record)
        records.sort { $0.date > $1.date }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SleepRecord].self, from: data) else { return }
        records = decoded
    }
}
