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

    private func heatColor(for date: Date) -> Color {
        guard let record = store.records.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }), let bedtime = record.bedtime else {
            return Theme.textTertiary.opacity(0.25)
        }

        let h = Calendar.current.component(.hour, from: bedtime)
        let m = Calendar.current.component(.minute, from: bedtime)
        let target = settings.targetHour * 60 + settings.targetMinute
        let actual = h * 60 + m

        if actual <= target      { return Theme.accentSuccess }
        if actual <= target + 30 { return Theme.accentWarning }
        return Theme.accentDanger
    }

    private func monthRangeLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let start = days.first.map { formatter.string(from: $0) } ?? ""
        let end = days.last.map { formatter.string(from: $0) } ?? ""
        return "\(start) – \(end)"
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Historique")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Vos 90 derniers jours")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 20)

                    // Stat cards
                    HStack(spacing: 14) {
                        PremiumStatBox(
                            title: "Série actuelle",
                            value: "\(currentStreak)",
                            unit: "nuits",
                            accentColor: Theme.accentGold,
                            icon: "flame.fill"
                        )
                        PremiumStatBox(
                            title: "Meilleur record",
                            value: "\(bestStreak)",
                            unit: "nuits",
                            accentColor: Theme.accentPrimary,
                            icon: "trophy.fill"
                        )
                    }

                    // Heatmap card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("90 derniers jours")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(monthRangeLabel())
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        LazyVGrid(
                            columns: Array(repeating: .init(.flexible(), spacing: 5), count: 13),
                            spacing: 5
                        ) {
                            ForEach(days, id: \.self) { day in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(heatColor(for: day))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }

                        HStack(spacing: 14) {
                            HeatLegendItem(color: Theme.accentSuccess, label: "À l'heure")
                            HeatLegendItem(color: Theme.accentWarning, label: "< 30 min")
                            HeatLegendItem(color: Theme.accentDanger,  label: "Trop tard")
                            HeatLegendItem(color: Theme.textTertiary.opacity(0.4), label: "Aucun")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    }
                    .glassCard(padding: 18)

                    Spacer().frame(height: Theme.tabBarHeight)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - PremiumStatBox

private struct PremiumStatBox: View {
    let title: String
    let value: String
    let unit: String
    let accentColor: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(0.4)
                    .textCase(.uppercase)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .glowText(color: accentColor, radius: 8)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 18)
    }
}

// MARK: - HeatLegendItem

private struct HeatLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}
