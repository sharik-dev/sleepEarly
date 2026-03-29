# Configuration manuelle Xcode — sleepEarly

Ces étapes **doivent être faites dans Xcode** avant de lancer l'app.
Le code a déjà été généré — tu n'as qu'à configurer le projet.

---

## Étape 1 — Activer Mac Catalyst

1. Ouvre `sleepEarly.xcodeproj` dans Xcode
2. Dans le panneau gauche, clique sur la cible **sleepEarly** (l'icône bleue en haut)
3. Onglet **General** → section **Deployment Info**
4. Coche **Mac (Mac Catalyst)**

---

## Étape 2 — Ajouter la Widget Extension

1. **File → New → Target**
2. Sélectionne **Widget Extension** → Next
3. Nom du produit : `sleepEarlyWidget`
4. **Décocher** "Include Live Activity"
5. Finish → Activer le scheme si demandé

---

## Étape 3 — Ajouter la Live Activity Extension

1. **File → New → Target**
2. Sélectionne **Widget Extension** → Next
3. Nom du produit : `sleepEarlyLiveActivity`
4. **Cocher** "Include Live Activity"
5. Finish → Activer le scheme si demandé

---

## Étape 4 — Capabilities sur la cible principale `sleepEarly`

1. Clique sur la cible **sleepEarly** → onglet **Signing & Capabilities**
2. Clique **+ Capability** et ajoute chacun de ces éléments :

| Capability | Paramètre |
|---|---|
| **HealthKit** | (rien à configurer) |
| **iCloud** | Cocher **Key-value storage** |
| **Push Notifications** | (rien à configurer) |
| **Background Modes** | Cocher **Background fetch** |

---

## Étape 5 — App Groups (partage widget ↔ app)

1. Cible **sleepEarly** → Signing & Capabilities → **+ Capability → App Groups**
2. Clique **+** → entre `group.sleepearly` → OK
3. Répète la même opération sur la cible **sleepEarlyWidget**

---

## Étape 6 — Ajouter les fichiers générés aux targets Xcode

Les fichiers ont été créés dans les dossiers suivants. Xcode ne les détecte pas automatiquement — tu dois les ajouter manuellement :

### Fichiers widget (`sleepEarlyWidget/`)
1. Dans Xcode, clic droit sur le groupe **sleepEarlyWidget** dans le panneau gauche
2. **Add Files to "sleepEarly"…**
3. Sélectionne `sleepEarlyWidget/CountdownEntry.swift` et `CountdownWidget.swift`
4. Dans la popup, coche **sleepEarlyWidget** comme target (pas sleepEarly)

### Fichiers Live Activity (`sleepEarlyLiveActivity/`)
1. Clic droit sur **sleepEarlyLiveActivity** dans le panneau gauche
2. **Add Files to "sleepEarly"…**
3. Sélectionne `sleepEarlyLiveActivity/SleepCountdownAttributes.swift` et `SleepCountdownLiveActivity.swift`
4. Coche **sleepEarlyLiveActivity** comme target

### Fichiers de l'app principale (`sleepEarly/`)
Les fichiers dans `sleepEarly/Models/`, `sleepEarly/Services/`, `sleepEarly/Views/` doivent être ajoutés à la target **sleepEarly** :
1. Clic droit sur le groupe **sleepEarly** → Add Files…
2. Sélectionne tous les fichiers `.swift` des sous-dossiers `Models/`, `Services/`, `Views/`
3. Coche la target **sleepEarly**

---

## Étape 7 — Lancer l'app

1. Sélectionne le scheme **sleepEarly** et un simulateur iPhone
2. **Cmd+R** pour lancer
3. **Cmd+U** pour lancer les tests unitaires (11 tests attendus)

---

## Résumé des fichiers générés

```
sleepEarly/Models/
  ├── AppSettings.swift
  ├── SleepRecord.swift
  └── StreakEngine.swift

sleepEarly/Services/
  ├── NotificationScheduler.swift
  ├── HealthKitService.swift
  ├── SleepStore.swift
  └── LiveActivityManager.swift

sleepEarly/Views/
  ├── HomeView.swift
  ├── FrictionView.swift
  ├── HistoryView.swift
  └── SettingsView.swift

sleepEarlyWidget/
  ├── CountdownEntry.swift
  └── CountdownWidget.swift

sleepEarlyLiveActivity/
  ├── SleepCountdownAttributes.swift
  └── SleepCountdownLiveActivity.swift

sleepEarlyTests/
  ├── StreakEngineTests.swift
  └── NotificationSchedulerTests.swift
```
