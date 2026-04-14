// sleepEarlyWidget/CountdownWidget.swift
import WidgetKit
import SwiftUI

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let now = Date()
        var entries: [CountdownEntry] = []
        for i in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: i, to: now)!
            entries.append(makeEntry(for: entryDate))
        }
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func makeEntry(for date: Date) -> CountdownEntry {
        let defaults = UserDefaults(suiteName: "group.sleepappbusharik")
        let hour = (defaults?.object(forKey: "targetHour") as? Int) ?? 22
        let minute = (defaults?.object(forKey: "targetMinute") as? Int) ?? 0
        var target = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        // If bedtime already passed today, aim for tomorrow
        if target <= date {
            target = Calendar.current.date(byAdding: .day, value: 1, to: target)!
        }
        let remaining = max(0, Int(target.timeIntervalSince(date) / 60))
        return CountdownEntry(date: date, targetBedtime: target, minutesRemaining: remaining)
    }
}

// App colors (duplicated since widget target is isolated)
private extension Color {
    static let appBlue   = Color(red: 0x4F/255, green: 0x6E/255, blue: 0xF7/255)
    static let appCyan   = Color(red: 0x5E/255, green: 0xCF/255, blue: 0xCD/255)
    static let appBgDark = Color(red: 0x0A/255, green: 0x0F/255, blue: 0x1E/255)
    static let appBgCard = Color(red: 0x1A/255, green: 0x25/255, blue: 0x40/255)
}

struct CountdownWidgetEntryView: View {
    var entry: CountdownEntry
    @Environment(\.widgetFamily) var family

    private var hours: Int { entry.minutesRemaining / 60 }
    private var mins: Int  { entry.minutesRemaining % 60 }

    private var countdownText: String {
        guard entry.minutesRemaining > 0 else { return "Dors !" }
        if hours > 0 { return mins > 0 ? "\(hours)h \(mins)min" : "\(hours)h" }
        return "\(mins) min"
    }

    private var bedtimeLabel: String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: entry.targetBedtime)
        let m = cal.component(.minute, from: entry.targetBedtime)
        return m == 0 ? "avant \(h)h" : "avant \(h)h\(String(format: "%02d", m))"
    }

    private var accentColor: Color {
        switch entry.urgencyLevel {
        case .normal:            return .appBlue
        case .warning:           return Color(red: 1.0, green: 0.67, blue: 0.30)
        case .critical, .overdue: return Color(red: 1.0, green: 0.42, blue: 0.42)
        }
    }

    var body: some View {
        VStack(spacing: family == .systemSmall ? 6 : 10) {
            // Moon icon badge
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: "moon.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            if entry.minutesRemaining > 0 {
                Text(countdownText)
                    .font(.system(family == .systemSmall ? .title2 : .title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(bedtimeLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                Text("Dors !")
                    .font(.system(family == .systemSmall ? .title2 : .title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("Bonne nuit 🌙")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CountdownWidget: Widget {
    let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [.appBgDark, .appBgCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Countdown sommeil")
        .description("Temps restant avant l'heure de coucher.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
