// sleepEarly/Views/MenuBarView.swift
#if os(macOS)
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var timeRemaining: String {
        let target = settings.targetBedtimeToday
        let diff = target.timeIntervalSince(now)
        guard diff > 0 else { return "Dors ! 🌛" }
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        if h > 0 { return "→ \(h)h\(String(format: "%02d", m))" }
        return "→ \(m) min"
    }

    private var isUrgent: Bool {
        settings.targetBedtimeToday.timeIntervalSince(now) <= 10 * 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.fill")
                Text("sleepEarly")
                    .fontWeight(.semibold)
                Spacer()
                Text(timeRemaining)
                    .foregroundStyle(isUrgent ? .red : .primary)
                    .fontWeight(.semibold)
            }
            Divider()
            Text("Cible : \(settings.targetHour)h\(String(format: "%02d", settings.targetMinute))")
                .foregroundStyle(.secondary)
                .font(.caption)
            Button("Quitter") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 220)
        .onReceive(timer) { now = $0 }
    }
}
#endif
