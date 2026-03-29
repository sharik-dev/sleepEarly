// sleepEarlyLiveActivity/SleepCountdownLiveActivity.swift
import ActivityKit
import SwiftUI
import WidgetKit

struct SleepCountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SleepCountdownAttributes.self) { context in
            // Lock screen / banner
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.yellow)
                Text(context.state.isOverdue ? "Tu devrais dormir !" :
                     "\(context.state.minutesRemaining) min avant de dormir")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(.black)
            .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "moon.fill").foregroundStyle(.yellow)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.minutesRemaining) min")
                        .fontWeight(.bold)
                }
            } compactLeading: {
                Image(systemName: "moon.fill").foregroundStyle(.yellow)
            } compactTrailing: {
                Text("\(context.state.minutesRemaining)m")
                    .fontWeight(.semibold)
            } minimal: {
                Image(systemName: "moon.fill")
            }
        }
    }
}
