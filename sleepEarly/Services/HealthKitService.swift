// sleepEarly/Services/HealthKitService.swift
import HealthKit
import Foundation

final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Demande l'autorisation lecture + écriture sommeil.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [sleepType], read: [sleepType])
            return true
        } catch {
            return false
        }
    }

    /// Enregistre l'heure d'endormissement maintenant.
    /// La durée est estimée à 8h (sera corrigée si l'utilisateur presse "réveil").
    func saveBedtime(_ bedtime: Date) async throws {
        let wakeEstimate = Calendar.current.date(byAdding: .hour, value: 8, to: bedtime)!
        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: bedtime,
            end: wakeEstimate
        )
        try await store.save(sample)
    }

    /// Lit l'heure d'endormissement pour une nuit donnée (minuit → 6h du matin).
    func fetchBedtime(forNight night: Date) async -> Date? {
        let start = Calendar.current.startOfDay(for: night)
        let end = Calendar.current.date(byAdding: .hour, value: 6, to: start)!

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store),
              let first = samples.first else { return nil }
        return first.startDate
    }
}
