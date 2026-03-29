// sleepEarly/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: SleepStore
    @EnvironmentObject var settings: AppSettings

    private var bestStreak: Int {
        StreakEngine.bestStreak(
            records: store.records,
            targetHour: settings.targetHour,
            targetMinute: settings.targetMinute
        )
    }

    private var currentStreak: Int {
        StreakEngine.currentStreak(
            records: store.records,
            targetHour: settings.targetHour,
            targetMinute: settings.targetMinute
        )
    }

    private var days: [Date] {
        (0..<90).map { i in
            Calendar.current.date(byAdding: .day, value: -i, to: Date())!
        }.reversed()
    }

    private func color(for date: Date) -> Color {
        guard let record = store.records.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else { return .gray.opacity(0.2) }

        guard let bedtime = record.bedtime else { return .gray.opacity(0.2) }

        let h = Calendar.current.component(.hour, from: bedtime)
        let m = Calendar.current.component(.minute, from: bedtime)
        let target = settings.targetHour * 60 + settings.targetMinute
        let actual = h * 60 + m

        if actual <= target { return .green }
        if actual <= target + 30 { return .orange }
        return .red
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 32) {
                    StatBox(title: "Streak actuel", value: "\(currentStreak)", unit: "nuits")
                    StatBox(title: "Record", value: "\(bestStreak)", unit: "nuits")
                }
                .padding(.horizontal)

                Text("90 derniers jours")
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 4), count: 13), spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: day))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 16) {
                    LegendItem(color: .green, label: "Avant \(settings.targetHour)h")
                    LegendItem(color: .orange, label: "< 30 min de retard")
                    LegendItem(color: .red, label: "Trop tard")
                    LegendItem(color: .gray.opacity(0.3), label: "Pas de données")
                }
                .font(.caption)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Historique")
    }
}

private struct StatBox: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 40, weight: .bold, design: .rounded))
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }
}
