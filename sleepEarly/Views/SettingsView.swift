// sleepEarly/Views/SettingsView.swift
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedHour: Int = 22
    @State private var selectedMinute: Int = 0

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Réglages")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Personnalisez votre routine")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 20)

                    // Section 1 — Bedtime target
                    sectionCard(title: "Heure de coucher", icon: "moon.fill", iconColor: Theme.accentPrimary) {
                        VStack(spacing: 0) {
                            // Live time preview
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(selectedHour)h")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(String(format: "%02d", selectedMinute))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.accentPrimary)
                                    .glowText(color: Theme.accentPrimary, radius: 10)
                                Spacer()
                            }
                            .animation(.easeInOut(duration: 0.15), value: selectedHour)
                            .animation(.easeInOut(duration: 0.15), value: selectedMinute)

                            Rectangle()
                                .fill(Theme.separator)
                                .frame(height: 1)
                                .padding(.vertical, 12)

                            HStack(spacing: 0) {
                                Picker("Heure", selection: $selectedHour) {
                                    ForEach([18, 19, 20, 21, 22, 23, 0], id: \.self) { h in
                                        Text(h == 0 ? "0h" : "\(h)h")
                                            .foregroundStyle(Theme.textPrimary)
                                            .tag(h)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .colorScheme(.dark)

                                Picker("Minute", selection: $selectedMinute) {
                                    ForEach([0, 15, 30, 45], id: \.self) {
                                        Text(String(format: ":%02d", $0))
                                            .foregroundStyle(Theme.textPrimary)
                                            .tag($0)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .colorScheme(.dark)
                            }
                            .frame(height: 120)
                        }
                        .onChange(of: selectedHour) { newValue in
                            settings.targetHour = newValue
                            reschedule()
                        }
                        .onChange(of: selectedMinute) { newValue in
                            settings.targetMinute = newValue
                            reschedule()
                        }
                    }

                    // Section 2 — Behaviour
                    sectionCard(title: "Comportement", icon: "switch.2", iconColor: Theme.accentSecondary) {
                        VStack(spacing: 0) {
                            PremiumToggleRow(
                                label: "Notifications",
                                sublabel: "Rappels avant l'heure cible",
                                icon: "bell.fill",
                                isOn: $settings.notificationsEnabled
                            )
                            .onChange(of: settings.notificationsEnabled) { enabled in
                                if enabled { reschedule() } else { NotificationScheduler.cancelAll() }
                            }

                            Rectangle()
                                .fill(Theme.separator)
                                .frame(height: 1)
                                .padding(.vertical, 2)

                            PremiumToggleRow(
                                label: "Écran de friction",
                                sublabel: "Résistance pour rester éveillé",
                                icon: "hand.raised.fill",
                                isOn: $settings.frictionEnabled
                            )
                        }
                    }

                    // Section 3 — Permissions
                    sectionCard(title: "Permissions", icon: "lock.shield.fill", iconColor: Theme.accentGold) {
                        VStack(spacing: 0) {
                            PremiumActionRow(
                                label: "Réautoriser HealthKit",
                                icon: "heart.fill",
                                iconColor: Color(hex: "FF6B8A")
                            ) {
                                Task { await HealthKitService.shared.requestAuthorization() }
                            }

                            Rectangle()
                                .fill(Theme.separator)
                                .frame(height: 1)
                                .padding(.vertical, 4)

                            PremiumActionRow(
                                label: "Réautoriser les notifications",
                                icon: "bell.fill",
                                iconColor: Theme.accentPrimary
                            ) {
                                UNUserNotificationCenter.current()
                                    .requestAuthorization(options: [.alert, .sound]) { _, _ in }
                            }
                        }
                    }

                    Spacer().frame(height: Theme.tabBarHeight)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            selectedHour = settings.targetHour
            selectedMinute = settings.targetMinute
        }
    }

    // MARK: - Section Card Builder

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(0.6)
                    .textCase(.uppercase)
            }
            content()
        }
        .glassCard(padding: 18)
    }

    private func reschedule() {
        guard settings.notificationsEnabled else { return }
        NotificationScheduler.scheduleAll(
            targetHour: settings.targetHour,
            targetMinute: settings.targetMinute
        )
    }
}

// MARK: - PremiumToggleRow

private struct PremiumToggleRow: View {
    let label: String
    let sublabel: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isOn ? Theme.accentPrimary : Theme.textTertiary)
                .frame(width: 28)
                .animation(.easeInOut(duration: 0.2), value: isOn)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(sublabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.accentPrimary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - PremiumActionRow

private struct PremiumActionRow: View {
    let label: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
