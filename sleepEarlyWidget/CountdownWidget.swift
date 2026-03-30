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
        let hour = UserDefaults(suiteName: "group.sleepearly")?.integer(forKey: "targetHour") ?? 22
        let minute = UserDefaults(suiteName: "group.sleepearly")?.integer(forKey: "targetMinute") ?? 0
        let target = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        let remaining = max(0, Int(target.timeIntervalSince(date) / 60))
        return CountdownEntry(date: date, targetBedtime: target, minutesRemaining: remaining)
    }
}

struct CountdownWidgetEntryView: View {
    var entry: CountdownEntry
    @Environment(\.widgetFamily) var family

    var color: Color {
        switch entry.urgencyLevel {
        case .normal: return .indigo
        case .warning: return .orange
        case .critical, .overdue: return .red
        }
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(color.gradient)
            VStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                if entry.minutesRemaining > 0 {
                    Text("\(entry.minutesRemaining) min")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("Dors !")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                Text("avant 22h")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

struct CountdownWidget: Widget {
    let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Countdown sommeil")
        .description("Temps restant avant l'heure de coucher.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
