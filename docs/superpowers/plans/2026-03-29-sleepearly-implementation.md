# sleepEarly Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire une app iOS/iPadOS/macOS qui aide l'utilisateur à se coucher à 22h via notifications spam progressives, friction active, un countdown visuel multi-surface, et un suivi streak + historique.

**Architecture:** App SwiftUI multi-target (iOS + Mac Catalyst). Logique métier dans des services partagés (StreakEngine, NotificationScheduler, HealthKitService). Données synchronisées via NSUbiquitousKeyValueStore (iCloud KV). Widget + Live Activity comme extensions séparées.

**Tech Stack:** SwiftUI, WidgetKit, ActivityKit, HealthKit, UNUserNotificationCenter, NSUbiquitousKeyValueStore, XCTest, Mac Catalyst

---

## Structure des fichiers

```
sleepEarly/                          ← target principal (iOS + Mac Catalyst)
├── sleepEarlyApp.swift              MODIFY  — entry point, MenuBarExtra macOS
├── ContentView.swift                MODIFY  — root navigation
├── Models/
│   ├── AppSettings.swift           CREATE  — heure cible, iCloud KV sync
│   ├── SleepRecord.swift           CREATE  — modèle d'une nuit de sommeil
│   └── StreakEngine.swift          CREATE  — calcul du streak (pur, testable)
├── Services/
│   ├── NotificationScheduler.swift CREATE  — planifie les 7 notifs locales
│   └── HealthKitService.swift      CREATE  — lecture/écriture HK sleep
├── Views/
│   ├── HomeView.swift              CREATE  — écran principal
│   ├── FrictionView.swift          CREATE  — overlay bloquant à 22h
│   ├── HistoryView.swift           CREATE  — calendrier style GitHub
│   └── SettingsView.swift          CREATE  — paramètres

sleepEarlyWidget/                    ← WidgetKit extension (à ajouter dans Xcode)
├── CountdownEntry.swift            CREATE  — TimelineEntry model
└── CountdownWidget.swift           CREATE  — Provider + vues du widget

sleepEarlyLiveActivity/              ← ActivityKit extension (à ajouter dans Xcode)
├── SleepCountdownAttributes.swift  CREATE  — ActivityAttributes
└── SleepCountdownLiveActivity.swift CREATE — vue Lock Screen + Dynamic Island

sleepEarlyTests/
├── StreakEngineTests.swift         CREATE
└── NotificationSchedulerTests.swift CREATE
```

---

## Task 1 : Targets Xcode — Widget + Live Activity + Mac Catalyst

**Aucun fichier à coder — actions Xcode manuelles.**

- [ ] **Step 1 : Activer Mac Catalyst**

Dans Xcode → cible `sleepEarly` → General → Deployment Info → cocher **Mac (Mac Catalyst)**.

- [ ] **Step 2 : Ajouter la WidgetKit extension**

File → New → Target → **Widget Extension**. Nom : `sleepEarlyWidget`. Décocher "Include Live Activity". Xcode crée `sleepEarlyWidget/` avec un fichier de base.

- [ ] **Step 3 : Ajouter la Live Activity extension**

File → New → Target → **Widget Extension**. Nom : `sleepEarlyLiveActivity`. Cocher "Include Live Activity". Xcode crée les fichiers de base.

- [ ] **Step 4 : Capabilities**

Pour la cible `sleepEarly` → Signing & Capabilities → ajouter :
- **HealthKit**
- **iCloud** → cocher "Key-value storage"
- **Push Notifications** (requis pour Live Activity)
- **Background Modes** → cocher "Background fetch"

- [ ] **Step 5 : Commit**

```bash
git add sleepEarly.xcodeproj
git commit -m "feat: add Widget, Live Activity targets and Mac Catalyst"
```

---

## Task 2 : Modèles de données

**Files:**
- Create: `sleepEarly/Models/SleepRecord.swift`
- Create: `sleepEarly/Models/AppSettings.swift`

- [ ] **Step 1 : Créer SleepRecord.swift**

```swift
// sleepEarly/Models/SleepRecord.swift
import Foundation

struct SleepRecord: Codable, Identifiable {
    let id: UUID
    let date: Date          // minuit du jour concerné (clé)
    let bedtime: Date?      // heure réelle d'endormissement (nil si pas de données)
    let source: RecordSource

    enum RecordSource: String, Codable {
        case manual      // bouton "Je dors"
        case healthKit   // lu depuis HealthKit
    }

    init(date: Date, bedtime: Date?, source: RecordSource) {
        self.id = UUID()
        self.date = date
        self.bedtime = bedtime
        self.source = source
    }
}
```

- [ ] **Step 2 : Créer AppSettings.swift**

```swift
// sleepEarly/Models/AppSettings.swift
import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let store = NSUbiquitousKeyValueStore.default
    private let targetHourKey = "targetHour"
    private let targetMinuteKey = "targetMinute"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let frictionEnabledKey = "frictionEnabled"

    @Published var targetHour: Int {
        didSet { store.set(targetHour, forKey: targetHourKey); store.synchronize() }
    }
    @Published var targetMinute: Int {
        didSet { store.set(targetMinute, forKey: targetMinuteKey); store.synchronize() }
    }
    @Published var notificationsEnabled: Bool {
        didSet { store.set(notificationsEnabled, forKey: notificationsEnabledKey); store.synchronize() }
    }
    @Published var frictionEnabled: Bool {
        didSet { store.set(frictionEnabled, forKey: frictionEnabledKey); store.synchronize() }
    }

    private init() {
        store.synchronize()
        self.targetHour = store.object(forKey: targetHourKey) != nil
            ? Int(store.longLong(forKey: targetHourKey)) : 22
        self.targetMinute = store.object(forKey: targetMinuteKey) != nil
            ? Int(store.longLong(forKey: targetMinuteKey)) : 0
        self.notificationsEnabled = store.object(forKey: notificationsEnabledKey) != nil
            ? store.bool(forKey: notificationsEnabledKey) : true
        self.frictionEnabled = store.object(forKey: frictionEnabledKey) != nil
            ? store.bool(forKey: frictionEnabledKey) : true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    @objc private func iCloudDidChange() {
        DispatchQueue.main.async {
            self.targetHour = Int(self.store.longLong(forKey: self.targetHourKey))
            self.targetMinute = Int(self.store.longLong(forKey: self.targetMinuteKey))
            self.notificationsEnabled = self.store.bool(forKey: self.notificationsEnabledKey)
            self.frictionEnabled = self.store.bool(forKey: self.frictionEnabledKey)
        }
    }

    /// Heure cible sous forme de Date pour aujourd'hui
    var targetBedtimeToday: Date {
        Calendar.current.date(
            bySettingHour: targetHour,
            minute: targetMinute,
            second: 0,
            of: Date()
        )!
    }
}
```

- [ ] **Step 3 : Commit**

```bash
git add sleepEarly/Models/
git commit -m "feat: add SleepRecord and AppSettings models"
```

---

## Task 3 : StreakEngine (TDD)

**Files:**
- Create: `sleepEarly/Models/StreakEngine.swift`
- Create: `sleepEarlyTests/StreakEngineTests.swift`

- [ ] **Step 1 : Écrire les tests en premier**

```swift
// sleepEarlyTests/StreakEngineTests.swift
import XCTest
@testable import sleepEarly

final class StreakEngineTests: XCTestCase {

    private func makeDate(daysAgo: Int, hour: Int, minute: Int = 0) -> Date {
        let base = Calendar.current.startOfDay(for: Date())
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: base)!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func record(daysAgo: Int, bedtimeHour: Int, bedtimeMinute: Int = 0) -> SleepRecord {
        let date = Calendar.current.startOfDay(for: makeDate(daysAgo: daysAgo, hour: 0))
        let bedtime = makeDate(daysAgo: daysAgo, hour: bedtimeHour, minute: bedtimeMinute)
        return SleepRecord(date: date, bedtime: bedtime, source: .manual)
    }

    // streak de 0 si aucun enregistrement
    func test_emptyRecords_streakIsZero() {
        let streak = StreakEngine.currentStreak(records: [], targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 0)
    }

    // couché avant 22h hier = streak 1
    func test_sleptBeforeTarget_streakOne() {
        let records = [record(daysAgo: 1, bedtimeHour: 21, bedtimeMinute: 30)]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 1)
    }

    // couché après 22h = streak 0
    func test_sleptAfterTarget_streakZero() {
        let records = [record(daysAgo: 1, bedtimeHour: 23)]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 0)
    }

    // 3 jours consécutifs avant 22h = streak 3
    func test_threeConsecutiveNights_streakThree() {
        let records = [
            record(daysAgo: 1, bedtimeHour: 21, bedtimeMinute: 50),
            record(daysAgo: 2, bedtimeHour: 21, bedtimeMinute: 45),
            record(daysAgo: 3, bedtimeHour: 21, bedtimeMinute: 30)
        ]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 3)
    }

    // trou dans la chaîne : streak s'arrête
    func test_gap_streakBreaks() {
        let records = [
            record(daysAgo: 1, bedtimeHour: 21),
            // daysAgo: 2 manquant
            record(daysAgo: 3, bedtimeHour: 21)
        ]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 1)
    }

    // record sans bedtime (données manquantes) = ne compte pas
    func test_nilBedtime_doesNotCount() {
        let date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let records = [SleepRecord(date: date, bedtime: nil, source: .healthKit)]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 0)
    }

    func test_bestStreak_acrossHistory() {
        let records = [
            record(daysAgo: 1, bedtimeHour: 21),
            record(daysAgo: 2, bedtimeHour: 21),
            record(daysAgo: 4, bedtimeHour: 21),
            record(daysAgo: 5, bedtimeHour: 21),
            record(daysAgo: 6, bedtimeHour: 21)
        ]
        let best = StreakEngine.bestStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(best, 3)
    }
}
```

- [ ] **Step 2 : Lancer les tests pour confirmer l'échec**

Dans Xcode : Cmd+U. Attendu : erreur de compilation "StreakEngine not found".

- [ ] **Step 3 : Implémenter StreakEngine**

```swift
// sleepEarly/Models/StreakEngine.swift
import Foundation

enum StreakEngine {

    /// Streak courant : nombre de jours consécutifs (en remontant depuis hier)
    /// où l'heure de coucher est avant targetHour:targetMinute.
    static func currentStreak(records: [SleepRecord], targetHour: Int, targetMinute: Int) -> Int {
        let sorted = records.sorted { $0.date > $1.date }
        var streak = 0
        var expectedDate = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        )

        for record in sorted {
            let recordDay = Calendar.current.startOfDay(for: record.date)
            guard recordDay == expectedDate else { break }
            guard let bedtime = record.bedtime else { break }
            guard sleptBeforeTarget(bedtime: bedtime, targetHour: targetHour, targetMinute: targetMinute) else { break }
            streak += 1
            expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: expectedDate)!
        }
        return streak
    }

    /// Meilleur streak jamais atteint dans l'historique.
    static func bestStreak(records: [SleepRecord], targetHour: Int, targetMinute: Int) -> Int {
        let sorted = records.sorted { $0.date < $1.date }
        var best = 0
        var current = 0
        var previousDate: Date?

        for record in sorted {
            let recordDay = Calendar.current.startOfDay(for: record.date)
            guard let bedtime = record.bedtime,
                  sleptBeforeTarget(bedtime: bedtime, targetHour: targetHour, targetMinute: targetMinute) else {
                best = max(best, current)
                current = 0
                previousDate = nil
                continue
            }

            if let prev = previousDate,
               let expectedNext = Calendar.current.date(byAdding: .day, value: 1, to: prev),
               recordDay == Calendar.current.startOfDay(for: expectedNext) {
                current += 1
            } else {
                best = max(best, current)
                current = 1
            }
            previousDate = recordDay
        }
        return max(best, current)
    }

    private static func sleptBeforeTarget(bedtime: Date, targetHour: Int, targetMinute: Int) -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: bedtime)
        let minute = cal.component(.minute, from: bedtime)
        return hour < targetHour || (hour == targetHour && minute <= targetMinute)
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Cmd+U. Attendu : tous les tests passent (7 tests verts).

- [ ] **Step 5 : Commit**

```bash
git add sleepEarly/Models/StreakEngine.swift sleepEarlyTests/StreakEngineTests.swift
git commit -m "feat: add StreakEngine with TDD (currentStreak, bestStreak)"
```

---

## Task 4 : NotificationScheduler (TDD)

**Files:**
- Create: `sleepEarly/Services/NotificationScheduler.swift`
- Create: `sleepEarlyTests/NotificationSchedulerTests.swift`

- [ ] **Step 1 : Écrire les tests**

```swift
// sleepEarlyTests/NotificationSchedulerTests.swift
import XCTest
@testable import sleepEarly

final class NotificationSchedulerTests: XCTestCase {

    func test_buildNotifications_returnsSevenRequests() {
        let requests = NotificationScheduler.buildRequests(targetHour: 22, targetMinute: 0)
        XCTAssertEqual(requests.count, 7)
    }

    func test_buildNotifications_identifiersAreUnique() {
        let requests = NotificationScheduler.buildRequests(targetHour: 22, targetMinute: 0)
        let ids = Set(requests.map { $0.identifier })
        XCTAssertEqual(ids.count, 7)
    }

    func test_buildNotifications_lastNotifIsAtTarget() {
        let requests = NotificationScheduler.buildRequests(targetHour: 22, targetMinute: 0)
        let last = requests.last!
        let trigger = last.trigger as! UNCalendarNotificationTrigger
        let components = trigger.dateComponents
        XCTAssertEqual(components.hour, 22)
        XCTAssertEqual(components.minute, 0)
    }

    func test_buildNotifications_firstNotifIsThirtyMinBefore() {
        let requests = NotificationScheduler.buildRequests(targetHour: 22, targetMinute: 0)
        let first = requests.first!
        let trigger = first.trigger as! UNCalendarNotificationTrigger
        let components = trigger.dateComponents
        XCTAssertEqual(components.hour, 21)
        XCTAssertEqual(components.minute, 30)
    }

    func test_buildNotifications_customTarget() {
        let requests = NotificationScheduler.buildRequests(targetHour: 23, targetMinute: 30)
        let first = requests.first!
        let trigger = first.trigger as! UNCalendarNotificationTrigger
        let components = trigger.dateComponents
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 0)
    }
}
```

- [ ] **Step 2 : Lancer pour confirmer l'échec**

Cmd+U. Attendu : erreur de compilation "NotificationScheduler not found".

- [ ] **Step 3 : Implémenter NotificationScheduler**

```swift
// sleepEarly/Services/NotificationScheduler.swift
import UserNotifications
import Foundation

enum NotificationScheduler {

    private struct WindDownStep {
        let minutesBefore: Int
        let body: String
    }

    private static let steps: [WindDownStep] = [
        WindDownStep(minutesBefore: 30, body: "Dans 30 min, c'est l'heure de dormir 🌙"),
        WindDownStep(minutesBefore: 25, body: "25 minutes restantes — commence à déposer le téléphone"),
        WindDownStep(minutesBefore: 20, body: "20 min — pose Netflix, prépare-toi 🧘"),
        WindDownStep(minutesBefore: 15, body: "15 minutes restantes"),
        WindDownStep(minutesBefore: 10, body: "10 min — dernière chance de finir ce que tu fais"),
        WindDownStep(minutesBefore: 5,  body: "5 min ⚠️ C'est presque l'heure !"),
        WindDownStep(minutesBefore: 0,  body: "C'est 22h. Pose tout et dors. 🌛"),
    ]

    /// Construit les UNNotificationRequest sans les enregistrer (testable).
    static func buildRequests(targetHour: Int, targetMinute: Int) -> [UNNotificationRequest] {
        steps.enumerated().map { index, step in
            let content = UNMutableNotificationContent()
            content.title = "sleepEarly"
            content.body = step.body
            content.sound = index < 5 ? .default : .defaultCritical

            let (hour, minute) = minutesBefore(step.minutesBefore, fromHour: targetHour, fromMinute: targetMinute)
            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return UNNotificationRequest(
                identifier: "sleepearly-winddown-\(index)",
                content: content,
                trigger: trigger
            )
        }
    }

    /// Planifie toutes les notifications (annule les précédentes).
    static func scheduleAll(targetHour: Int, targetMinute: Int) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<steps.count).map { "sleepearly-winddown-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let requests = buildRequests(targetHour: targetHour, targetMinute: targetMinute)
        for request in requests {
            center.add(request)
        }
    }

    /// Annule toutes les notifications sleepEarly.
    static func cancelAll() {
        let ids = (0..<steps.count).map { "sleepearly-winddown-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Calcule l'heure/minute N minutes avant un target.
    private static func minutesBefore(_ n: Int, fromHour: Int, fromMinute: Int) -> (Int, Int) {
        var total = fromHour * 60 + fromMinute - n
        if total < 0 { total += 24 * 60 }
        return (total / 60, total % 60)
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Cmd+U. Attendu : 5 tests verts.

- [ ] **Step 5 : Commit**

```bash
git add sleepEarly/Services/NotificationScheduler.swift sleepEarlyTests/NotificationSchedulerTests.swift
git commit -m "feat: add NotificationScheduler with TDD (7 local notifications)"
```

---

## Task 5 : HealthKitService

**Files:**
- Create: `sleepEarly/Services/HealthKitService.swift`

> Note : HealthKit ne peut pas être testé en unitaire sans un device réel. Le service sera testé manuellement sur device.

- [ ] **Step 1 : Créer HealthKitService.swift**

```swift
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
```

- [ ] **Step 2 : Ajouter la clé dans Info.plist**

Dans `sleepEarly/Info.plist`, ajouter :
```xml
<key>NSHealthShareUsageDescription</key>
<string>sleepEarly lit vos données de sommeil pour calculer votre streak.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>sleepEarly enregistre votre heure de coucher.</string>
```

- [ ] **Step 3 : Commit**

```bash
git add sleepEarly/Services/HealthKitService.swift sleepEarly/Info.plist
git commit -m "feat: add HealthKitService for sleep read/write"
```

---

## Task 6 : Persistance locale des SleepRecords

**Files:**
- Create: `sleepEarly/Services/SleepStore.swift`

- [ ] **Step 1 : Créer SleepStore.swift**

```swift
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
```

- [ ] **Step 2 : Commit**

```bash
git add sleepEarly/Services/SleepStore.swift
git commit -m "feat: add SleepStore for local persistence of sleep records"
```

---

## Task 7 : App Entry Point + HomeView

**Files:**
- Modify: `sleepEarly/sleepEarlyApp.swift`
- Modify: `sleepEarly/ContentView.swift`
- Create: `sleepEarly/Views/HomeView.swift`

- [ ] **Step 1 : Créer un stub FrictionView (sera complété en Task 8)**

```swift
// sleepEarly/Views/FrictionView.swift
import SwiftUI

struct FrictionView: View {
    @Binding var isPresented: Bool
    var body: some View {
        Button("Fermer") { isPresented = false }
    }
}
```

- [ ] **Step 2 : Modifier sleepEarlyApp.swift**

```swift
// sleepEarly/sleepEarlyApp.swift
import SwiftUI

@main
struct sleepEarlyApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var store = SleepStore.shared
    @State private var showFriction = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .fullScreenCover(isPresented: $showFriction) {
                    FrictionView(isPresented: $showFriction)
                }
                .onAppear {
                    requestPermissions()
                    rescheduleNotifications()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .init("SleepEarlyShowFriction")
                    )
                ) { _ in
                    if settings.frictionEnabled { showFriction = true }
                }
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(settings)
        } label: {
            Label("sleepEarly", systemImage: "moon.fill")
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    private func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        Task { await HealthKitService.shared.requestAuthorization() }
    }

    private func rescheduleNotifications() {
        guard settings.notificationsEnabled else {
            NotificationScheduler.cancelAll()
            return
        }
        NotificationScheduler.scheduleAll(
            targetHour: settings.targetHour,
            targetMinute: settings.targetMinute
        )
    }
}
```

- [ ] **Step 3 : Modifier ContentView.swift**

```swift
// sleepEarly/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Accueil", systemImage: "moon.fill") }
            HistoryView()
                .tabItem { Label("Historique", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
    }
}
```

- [ ] **Step 4 : Créer HomeView.swift**

```swift
// sleepEarly/Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: SleepStore
    @State private var now = Date()

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
        let target = settings.targetBedtimeToday
        let diff = target.timeIntervalSince(now)
        return diff >= 0 && diff <= 30 * 60
    }

    private var shouldShowSleepButton: Bool {
        let target = settings.targetBedtimeToday
        let oneHourBefore = Calendar.current.date(byAdding: .hour, value: -1, to: target)!
        return now >= oneHourBefore
    }

    var body: some View {
        ZStack {
            Color(isWindDownPeriod ? .systemIndigo : .systemBackground)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2), value: isWindDownPeriod)

            VStack(spacing: 32) {
                // Streak
                VStack(spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(streak > 0 ? .yellow : .secondary)
                    Text("nuits consécutives")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Countdown
                VStack(spacing: 8) {
                    Text(timeRemaining)
                        .font(.system(size: 48, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isWindDownPeriod ? .white : .primary)
                    Text("avant \(settings.targetHour)h\(String(format: "%02d", settings.targetMinute))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Bouton Je dors
                if shouldShowSleepButton {
                    Button {
                        Task { try? await HealthKitService.shared.saveBedtime(Date()) }
                        store.save(bedtime: Date(), source: .manual)
                    } label: {
                        Label("Je dors 🌙", systemImage: "bed.double.fill")
                            .font(.title2.bold())
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(.indigo)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
        }
        .onReceive(timer) { now = $0 }
    }
}
```

- [ ] **Step 5 : Build et tester sur simulateur**

Cmd+R sur simulateur iPhone. Vérifier que :
- L'écran affiche le streak (0 au départ)
- Le countdown s'égrène en temps réel
- Pas de crash

- [ ] **Step 6 : Commit**

```bash
git add sleepEarly/sleepEarlyApp.swift sleepEarly/ContentView.swift sleepEarly/Views/HomeView.swift sleepEarly/Views/FrictionView.swift
git commit -m "feat: add HomeView with streak, countdown, sleep button, and FrictionView stub"
```

---

## Task 8 : FrictionView

**Files:**
- Modify: `sleepEarly/Views/FrictionView.swift` (remplace le stub créé en Task 7)

- [ ] **Step 1 : Remplacer FrictionView.swift par l'implémentation complète**

```swift
// sleepEarly/Views/FrictionView.swift
import SwiftUI

struct FrictionView: View {
    @Binding var isPresented: Bool
    @State private var tapCount = 0

    private let messages = [
        "Tu es sûr ?",
        "Vraiment sûr ?",
        "OK, mais tu le regretteras demain. 😴"
    ]

    private var buttonLabel: String {
        tapCount == 0 ? "J'ignore" : messages[min(tapCount - 1, messages.count - 1)]
    }

    private var canDismiss: Bool { tapCount >= 3 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                // Animation lune
                Image(systemName: "moon.stars.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .foregroundStyle(.yellow)
                    .symbolEffect(.pulse)

                VStack(spacing: 12) {
                    Text("Tu aurais dû dormir")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Il est \(currentTimeString())")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }

                // Indicateur de taps
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i < tapCount ? Color.white : Color.gray.opacity(0.4))
                            .frame(width: 10, height: 10)
                    }
                }

                Button {
                    if canDismiss {
                        isPresented = false
                    } else {
                        tapCount += 1
                    }
                } label: {
                    Text(buttonLabel)
                        .font(.body.bold())
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(canDismiss ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .animation(.easeInOut, value: tapCount)
            }
            .padding(32)
        }
    }

    private func currentTimeString() -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: Date())
    }
}
```

- [ ] **Step 2 : Tester manuellement**

Dans HomeView, ajouter temporairement un bouton "Tester friction" :
```swift
Button("Test friction") {
    NotificationCenter.default.post(name: .init("SleepEarlyShowFriction"), object: nil)
}
```
Vérifier les 3 taps, les messages progressifs, la fermeture au 3e tap. Supprimer ce bouton test ensuite.

- [ ] **Step 3 : Commit**

```bash
git add sleepEarly/Views/FrictionView.swift
git commit -m "feat: add FrictionView with 3-tap progressive dismiss"
```

---

## Task 9 : macOS MenuBarView

**Files:**
- Create: `sleepEarly/Views/MenuBarView.swift`

- [ ] **Step 1 : Créer MenuBarView.swift**

```swift
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
```

- [ ] **Step 2 : Tester sur Mac**

Build scheme → My Mac. Vérifier que l'icône lune apparaît dans la barre de menus, le countdown s'affiche, rouge sous 10 min.

- [ ] **Step 3 : Commit**

```bash
git add sleepEarly/Views/MenuBarView.swift
git commit -m "feat: add macOS menu bar with live countdown"
```

---

## Task 10 : Widget WidgetKit

**Files:**
- Create: `sleepEarlyWidget/CountdownEntry.swift`
- Create: `sleepEarlyWidget/CountdownWidget.swift`

> Ces fichiers sont dans la target `sleepEarlyWidget`, pas dans `sleepEarly`.

- [ ] **Step 1 : Créer CountdownEntry.swift**

```swift
// sleepEarlyWidget/CountdownEntry.swift
import WidgetKit
import Foundation

struct CountdownEntry: TimelineEntry {
    let date: Date
    let targetBedtime: Date
    let minutesRemaining: Int

    var urgencyLevel: UrgencyLevel {
        if minutesRemaining <= 0 { return .overdue }
        if minutesRemaining <= 10 { return .critical }
        if minutesRemaining <= 30 { return .warning }
        return .normal
    }

    enum UrgencyLevel { case normal, warning, critical, overdue }
}
```

- [ ] **Step 2 : Créer CountdownWidget.swift**

```swift
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
        // Génère une entrée par minute pour les 60 prochaines minutes
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

@main
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
```

> **Note :** Pour partager `targetHour`/`targetMinute` entre l'app et le widget, il faut utiliser un **App Group**. Dans Xcode → Signing & Capabilities des deux targets `sleepEarly` et `sleepEarlyWidget` → ajouter "App Groups" → créer `group.sleepearly`. Puis dans `AppSettings.swift`, remplacer `UserDefaults.standard` par `UserDefaults(suiteName: "group.sleepearly")` pour les clés `targetHour` et `targetMinute`.

- [ ] **Step 3 : Ajouter App Group**

Dans Xcode : cible `sleepEarly` → Signing & Capabilities → + Capability → App Groups → `group.sleepearly`. Répéter pour `sleepEarlyWidget`.

- [ ] **Step 4 : Build et tester**

Cmd+R sur simulateur. Ajouter le widget depuis l'écran d'accueil. Vérifier le countdown.

- [ ] **Step 5 : Commit**

```bash
git add sleepEarlyWidget/
git commit -m "feat: add countdown WidgetKit extension"
```

---

## Task 11 : Live Activity (iPhone uniquement)

**Files:**
- Create: `sleepEarlyLiveActivity/SleepCountdownAttributes.swift`
- Create: `sleepEarlyLiveActivity/SleepCountdownLiveActivity.swift`
- Modify: `sleepEarly/Services/NotificationScheduler.swift` — ajouter start/stop Live Activity

- [ ] **Step 1 : Créer SleepCountdownAttributes.swift**

```swift
// sleepEarlyLiveActivity/SleepCountdownAttributes.swift
import ActivityKit
import Foundation

struct SleepCountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var minutesRemaining: Int
        var isOverdue: Bool
    }
    var targetBedtime: Date
}
```

- [ ] **Step 2 : Créer SleepCountdownLiveActivity.swift**

```swift
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
```

- [ ] **Step 3 : Ajouter LiveActivityManager dans l'app principale**

Créer `sleepEarly/Services/LiveActivityManager.swift` :

```swift
// sleepEarly/Services/LiveActivityManager.swift
import ActivityKit
import Foundation

#if canImport(ActivityKit)
enum LiveActivityManager {
    private static var currentActivity: Activity<SleepCountdownAttributes>?

    static func start(targetBedtime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let remaining = max(0, Int(targetBedtime.timeIntervalSinceNow / 60))
        let attributes = SleepCountdownAttributes(targetBedtime: targetBedtime)
        let state = SleepCountdownAttributes.ContentState(minutesRemaining: remaining, isOverdue: false)
        currentActivity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: targetBedtime)
        )
    }

    static func update(minutesRemaining: Int) {
        let state = SleepCountdownAttributes.ContentState(
            minutesRemaining: minutesRemaining,
            isOverdue: minutesRemaining <= 0
        )
        Task { await currentActivity?.update(.init(state: state, staleDate: nil)) }
    }

    static func stop() {
        Task { await currentActivity?.end(nil, dismissalPolicy: .immediate) }
        currentActivity = nil
    }
}
#endif
```

- [ ] **Step 4 : Appeler LiveActivityManager depuis HomeView**

Dans `HomeView.swift`, dans `.onReceive(timer)` :
```swift
.onReceive(timer) { date in
    now = date
    let remaining = Int(settings.targetBedtimeToday.timeIntervalSince(date) / 60)
    if remaining == 30 {
        LiveActivityManager.start(targetBedtime: settings.targetBedtimeToday)
    } else if remaining >= 0 {
        LiveActivityManager.update(minutesRemaining: remaining)
    } else {
        LiveActivityManager.stop()
    }
}
```

- [ ] **Step 5 : Commit**

```bash
git add sleepEarlyLiveActivity/ sleepEarly/Services/LiveActivityManager.swift sleepEarly/Views/HomeView.swift
git commit -m "feat: add Live Activity for Dynamic Island and lock screen countdown"
```

---

## Task 12 : HistoryView (calendrier streak)

**Files:**
- Create: `sleepEarly/Views/HistoryView.swift`

- [ ] **Step 1 : Créer HistoryView.swift**

```swift
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

    // Génère les 90 derniers jours (du plus récent au plus ancien)
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
                // Stats
                HStack(spacing: 32) {
                    StatBox(title: "Streak actuel", value: "\(currentStreak)", unit: "nuits")
                    StatBox(title: "Record", value: "\(bestStreak)", unit: "nuits")
                }
                .padding(.horizontal)

                // Calendrier
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

                // Légende
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
```

- [ ] **Step 2 : Build et vérifier**

Cmd+R. Aller dans l'onglet Historique. Vérifier la grille de 90 jours (tous gris au départ).

- [ ] **Step 3 : Commit**

```bash
git add sleepEarly/Views/HistoryView.swift
git commit -m "feat: add HistoryView with 90-day GitHub-style calendar"
```

---

## Task 13 : SettingsView

**Files:**
- Create: `sleepEarly/Views/SettingsView.swift`

- [ ] **Step 1 : Créer SettingsView.swift**

```swift
// sleepEarly/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedHour: Int = 22
    @State private var selectedMinute: Int = 0

    var body: some View {
        Form {
            Section("Heure de coucher") {
                HStack {
                    Text("Cible")
                    Spacer()
                    Picker("Heure", selection: $selectedHour) {
                        ForEach(18..<25) { Text("\($0)h").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    Picker("Minute", selection: $selectedMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: ":%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 70)
                }
                .onChange(of: selectedHour) { settings.targetHour = $0 }
                .onChange(of: selectedMinute) { settings.targetMinute = $0 }
            }

            Section("Comportement") {
                Toggle("Notifications", isOn: $settings.notificationsEnabled)
                Toggle("Écran de friction à l'heure cible", isOn: $settings.frictionEnabled)
            }

            Section("Permissions") {
                Button("Réautoriser HealthKit") {
                    Task { await HealthKitService.shared.requestAuthorization() }
                }
                Button("Réautoriser les notifications") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
            }
        }
        .navigationTitle("Réglages")
        .onAppear {
            selectedHour = settings.targetHour
            selectedMinute = settings.targetMinute
        }
    }
}
```

- [ ] **Step 2 : Replanifier les notifications après changement d'heure**

Dans `SettingsView`, ajouter dans `.onChange(of: selectedHour)` et `.onChange(of: selectedMinute)` :
```swift
NotificationScheduler.scheduleAll(
    targetHour: settings.targetHour,
    targetMinute: settings.targetMinute
)
```

- [ ] **Step 3 : Commit**

```bash
git add sleepEarly/Views/SettingsView.swift
git commit -m "feat: add SettingsView with target time picker and toggle controls"
```

---

## Task 14 : Test de bout en bout

- [ ] **Step 1 : Build tous les targets**

Dans Xcode : Product → Build For → Testing. Vérifier zéro erreur sur iOS et Mac.

- [ ] **Step 2 : Run tous les tests unitaires**

Cmd+U. Attendu : StreakEngineTests (6 tests) + NotificationSchedulerTests (5 tests) = 11 tests verts.

- [ ] **Step 3 : Test manuel sur simulateur iPhone**

1. Lancer l'app → vérifier le countdown sur HomeView
2. Aller dans Réglages → changer l'heure cible → vérifier que le countdown se met à jour
3. Appuyer "Je dors" → vérifier que le record apparaît dans Historique
4. Déclencher la friction manuellement (bouton temporaire)
5. Vérifier les 3 taps + fermeture

- [ ] **Step 4 : Test manuel sur Mac**

Lancer le scheme Mac Catalyst. Vérifier la menu bar.

- [ ] **Step 5 : Commit final**

```bash
git add .
git commit -m "feat: sleepEarly MVP complet — countdown, notifications, friction, streak, widget, Live Activity, Mac"
```
