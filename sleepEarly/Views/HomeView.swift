// sleepEarly/Views/HomeView.swift
import SwiftUI
import UserNotifications
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: SleepStore
    @EnvironmentObject var screenTime: ScreenTimeManager
    @State private var now = Date()
    @State private var showStarfield = false
    @State private var notifPermission: UNAuthorizationStatus = .notDetermined
    @State private var showFriction = false
    @State private var showAppPicker = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var streak: Int {
        StreakEngine.currentStreak(
            records: store.records,
            targetHour: settings.targetHour,
            targetMinute: settings.targetMinute
        )
    }

    private var timeRemaining: String {
        let target = settings.targetBedtimeToday
        let diff = target.timeIntervalSince(now)
        guard diff > 0 else { return "C'est l'heure !" }
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        let s = Int(diff) % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%02d:%02d", m, s)
    }

    private var isWindDownPeriod: Bool {
        let diff = settings.targetBedtimeToday.timeIntervalSince(now)
        return diff >= 0 && diff <= 30 * 60
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if showStarfield {
                StarfieldView()
                    .ignoresSafeArea()
                    .opacity(isWindDownPeriod ? 0.55 : 0.22)
                    .animation(.easeInOut(duration: 3), value: isWindDownPeriod)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Spacer().frame(height: 8)

                    // Hero — moon + countdown
                    heroSection

                    // Feature card 1 — Sleep notifications
                    notificationsCard

                    // Feature card 2 — App blocking
                    appBlockingCard

                    // Streak badge (demoted)
                    if streak > 0 { streakBadge }

                    Spacer().frame(height: Theme.tabBarHeight)
                }
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $showFriction) {
            FrictionView(isPresented: $showFriction)
        }
        .onReceive(timer) { date in
            now = date
            #if os(iOS)
            let remaining = Int(settings.targetBedtimeToday.timeIntervalSince(date) / 60)
            if remaining == 30 {
                LiveActivityManager.start(targetBedtime: settings.targetBedtimeToday)
            } else if remaining >= 0 {
                LiveActivityManager.update(minutesRemaining: remaining)
            } else {
                LiveActivityManager.stop()
            }
            if remaining <= 0 && settings.frictionEnabled {
                showFriction = true
            }
            #endif
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.5)) { showStarfield = true }
            checkNotifPermission()
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            if isWindDownPeriod {
                RadialGradient(
                    colors: [Color(hex: "2D1B69").opacity(0.6), Color(hex: "1A1060").opacity(0.3), Color.clear],
                    center: .top, startRadius: 0, endRadius: 520
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
            RadialGradient(
                colors: [Theme.accentPrimary.opacity(0.07), Color.clear],
                center: .top, startRadius: 60, endRadius: 420
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 2.5), value: isWindDownPeriod)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Moon orb
            ZStack {
                // Outer glow halos
                Circle()
                    .fill(Theme.accentPrimary.opacity(0.06))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(Theme.accentPrimary.opacity(0.10))
                    .frame(width: 130, height: 130)

                // Inner circle with border
                Circle()
                    .fill(Theme.backgroundCard)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle().strokeBorder(Theme.borderGlass, lineWidth: 1.5)
                    )
                    .shadow(color: Theme.accentPrimary.opacity(0.35), radius: 20, x: 0, y: 0)

                Image(systemName: isWindDownPeriod ? "moon.stars.fill" : "moon.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(
                        isWindDownPeriod
                            ? LinearGradient(colors: [Theme.accentGold, Theme.accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Theme.accentPrimary, Theme.accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .glowText(color: isWindDownPeriod ? Theme.accentGold : Theme.accentPrimary, radius: 16)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            }

            // Countdown
            VStack(spacing: 6) {
                Text(timeRemaining)
                    .font(.system(size: 54, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .glowText(
                        color: isWindDownPeriod ? Theme.accentSecondary : Theme.accentPrimary,
                        radius: isWindDownPeriod ? 22 : 10
                    )
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: timeRemaining)

                Text("avant \(settings.targetHour)h\(String(format: "%02d", settings.targetMinute))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(1.2)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Notifications Card

    private var notificationsCard: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accentPrimary.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: settings.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(settings.notificationsEnabled ? Theme.accentPrimary : Theme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Notifications de sommeil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(settings.notificationsEnabled
                         ? "7 rappels programmés · de \(windDownStartTime)"
                         : "Désactivées")
                        .font(.system(size: 12))
                        .foregroundStyle(settings.notificationsEnabled ? Theme.accentPrimary : Theme.textTertiary)
                }

                Spacer()

                Toggle("", isOn: $settings.notificationsEnabled)
                    .labelsHidden()
                    .tint(Theme.accentPrimary)
                    .onChange(of: settings.notificationsEnabled) { enabled in
                        if enabled {
                            requestNotifPermission()
                        } else {
                            NotificationScheduler.cancelAll()
                        }
                    }
            }

            if settings.notificationsEnabled {
                Rectangle()
                    .fill(Theme.separator)
                    .frame(height: 1)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                // Timeline of reminders
                notifTimeline
            }
        }
        .glassCard(padding: 18)
        .animation(.easeInOut(duration: 0.25), value: settings.notificationsEnabled)
    }

    private var notifTimeline: some View {
        let steps: [(String, String, String)] = [
            (windDownTime(minutesBefore: 30), "30 min — commence à déposer le téléphone", "moon.fill"),
            (windDownTime(minutesBefore: 15), "15 min — prépare-toi", "leaf.fill"),
            (windDownTime(minutesBefore: 5),  "5 min — presque l'heure", "exclamationmark.triangle.fill"),
            (windDownTime(minutesBefore: 0),  "Pose tout et dors", "moon.zzz.fill"),
        ]

        return VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    // Timeline dot + line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(isNextStep(minutesBefore: [30,15,5,0][index])
                                  ? Theme.accentPrimary
                                  : Theme.textTertiary.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .shadow(color: isNextStep(minutesBefore: [30,15,5,0][index])
                                    ? Theme.accentPrimary.opacity(0.8) : .clear, radius: 4)
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(Theme.separator)
                                .frame(width: 1, height: 22)
                        }
                    }
                    .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.0)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 5) {
                            Image(systemName: step.2)
                                .font(.system(size: 10))
                                .foregroundStyle(isNextStep(minutesBefore: [30,15,5,0][index])
                                                 ? Theme.accentPrimary : Theme.textTertiary)
                            Text(step.1)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                }
                if index < steps.count - 1 {
                    Spacer().frame(height: 6)
                }
            }
        }
    }

    // MARK: - App Blocking Card

    private var appBlockingCard: some View {
        VStack(spacing: 16) {
            // Header row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accentSecondary.opacity(0.13))
                        .frame(width: 42, height: 42)
                    Image(systemName: screenTime.isEnabled ? "shield.fill" : "shield")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(screenTime.isEnabled ? Theme.accentSecondary : Theme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Bloquer les apps")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(screenTime.isEnabled
                         ? "Actif à \(settings.targetHour)h\(String(format: "%02d", settings.targetMinute))"
                         : "Inactif")
                        .font(.system(size: 12))
                        .foregroundStyle(screenTime.isEnabled ? Theme.accentSecondary : Theme.textTertiary)
                }

                Spacer()

                if screenTime.isAuthorized {
                    Toggle("", isOn: Binding(
                        get: { screenTime.isEnabled },
                        set: { enabled in
                            if enabled {
                                screenTime.enable(
                                    bedtimeHour: settings.targetHour,
                                    bedtimeMinute: settings.targetMinute
                                )
                            } else {
                                screenTime.disable()
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(Theme.accentSecondary)
                }
            }

            // Authorization banner
            if !screenTime.isAuthorized {
                Button {
                    Task { await screenTime.requestAuthorization() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Autoriser le contrôle parental")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusButton)
                            .fill(LinearGradient(
                                colors: [Theme.accentSecondary, Theme.accentPrimary],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .shadow(color: Theme.accentSecondary.opacity(0.4), radius: 12, x: 0, y: 4)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                // App picker row
                Button {
                    showAppPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "squares.leading.rectangle")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.accentSecondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apps à bloquer")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Text(screenTime.selectionSummary)
                                .font(.system(size: 12))
                                .foregroundStyle(screenTime.hasSelection ? Theme.accentSecondary : Theme.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(Theme.backgroundCard.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .strokeBorder(Theme.borderGlass, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Les apps sélectionnées seront bloquées automatiquement à l'heure du coucher par Screen Time.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassCard(padding: 18)
        .sheet(isPresented: $showAppPicker) {
            FamilyActivityPicker(selection: Binding(
                get: { screenTime.selection },
                set: { screenTime.saveSelection($0) }
            ))
        }
        .animation(.easeInOut(duration: 0.25), value: screenTime.isAuthorized)
        .animation(.easeInOut(duration: 0.25), value: screenTime.isEnabled)
    }

    // MARK: - Streak Badge (demoted)

    private var streakBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.accentGold)
            Text("\(streak) nuit\(streak > 1 ? "s" : "") consécutive\(streak > 1 ? "s" : "")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("série en cours")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .fill(Theme.accentGold.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall).strokeBorder(Theme.accentGold.opacity(0.18), lineWidth: 1))
        )
    }

    // MARK: - Helpers

    private var windDownStartTime: String {
        let total = settings.targetHour * 60 + settings.targetMinute - 30
        let h = (total < 0 ? total + 1440 : total) / 60
        let m = (total < 0 ? total + 1440 : total) % 60
        return String(format: "%dh%02d", h, m)
    }

    private func windDownTime(minutesBefore: Int) -> String {
        var total = settings.targetHour * 60 + settings.targetMinute - minutesBefore
        if total < 0 { total += 1440 }
        return String(format: "%dh%02d", total / 60, total % 60)
    }

    private func isNextStep(minutesBefore: Int) -> Bool {
        let diff = settings.targetBedtimeToday.timeIntervalSince(now)
        let diffMin = Int(diff / 60)
        return diffMin <= minutesBefore + 2 && diffMin >= minutesBefore - 2
    }

    private func checkNotifPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notifPermission = s.authorizationStatus }
        }
    }

    private func requestNotifPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    NotificationScheduler.scheduleAll(
                        targetHour: settings.targetHour,
                        targetMinute: settings.targetMinute
                    )
                } else {
                    settings.notificationsEnabled = false
                }
            }
        }
    }
}

// MARK: - Starfield

struct StarfieldView: View {
    private struct Star: Identifiable {
        let id = UUID()
        let x, y, size: CGFloat
        let opacity, delay: Double
    }

    private let stars: [Star] = (0..<55).map { _ in
        Star(
            x: .random(in: 0...1), y: .random(in: 0...0.72),
            size: .random(in: 1...2.8),
            opacity: .random(in: 0.2...0.65), delay: .random(in: 0...4)
        )
    }

    @State private var twinkle = false

    var body: some View {
        GeometryReader { geo in
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
                    .opacity(twinkle ? star.opacity : star.opacity * 0.45)
                    .animation(
                        .easeInOut(duration: .random(in: 2...4)).repeatForever(autoreverses: true).delay(star.delay),
                        value: twinkle
                    )
            }
        }
        .onAppear { twinkle = true }
    }
}
