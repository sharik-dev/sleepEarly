# sleepEarly — Design Spec
**Date:** 2026-03-29
**Platform:** iOS 17+ / iPadOS 17+ / macOS 14+
**Stack:** SwiftUI, HealthKit, CloudKit, WidgetKit, ActivityKit, UNUserNotificationCenter

---

## 1. Problème utilisateur

L'utilisateur veut être au lit à 22h mais échoue à cause de trois patterns :
- Scroll passif sur téléphone / Netflix (perd la notion du temps)
- Oubli pur de l'heure
- Absence de routine et rituel de coucher

---

## 2. Objectif de l'app

Créer une boucle de rappels progressifs + friction active + suivi de streak pour conditionner un coucher à 22h, disponible sur iPhone, iPad et Mac avec synchronisation iCloud.

---

## 3. Architecture générale

- App SwiftUI unique, multi-target : iOS/iPadOS + macOS via **Mac Catalyst** (codebase partagé, pas deux apps séparées)
- Synchronisation des données (heure cible, streak, historique) via **CloudKit (NSUbiquitousKeyValueStore + CKDatabase)**
- Notifications locales planifiées via `UNUserNotificationCenter` (aucun serveur requis)
- Extension Widget (WidgetKit) partagée iOS/iPadOS
- Extension Live Activity (ActivityKit) pour iPhone
- Menu Bar Extra pour macOS

---

## 4. Phases de wind-down

Heure cible par défaut : **22h00**. Les phases démarrent 30 min avant.

| Heure    | Action                                              |
|----------|-----------------------------------------------------|
| 21h30    | Notif douce : "Dans 30 min, c'est l'heure de dormir 🌙" |
| 21h35    | Notif : "25 minutes restantes"                      |
| 21h40    | Notif : "20 min — commence à poser le téléphone"    |
| 21h45    | Notif : "15 min restantes"                          |
| 21h50    | Notif : "10 min — dernière chance"                  |
| 21h55    | Notif : "5 min ⚠️"                                  |
| 22h00    | Écran de friction plein écran                       |

Les 7 notifications sont **locales**, replanifiées chaque jour au lancement de l'app ou lors d'un changement d'heure cible.

---

## 5. Éléments visuels permanents (countdown)

### iPhone / iPad
- **Widget home screen** (WidgetKit, taille small/medium) : affiche `HH:MM` restant avant 22h, visible toute la journée. Change de couleur (vert → orange → rouge) selon la proximité.
- **Live Activity** (ActivityKit) : activée à 21h30, s'affiche sur le lock screen et dans la Dynamic Island avec le countdown en temps réel.

### Mac
- **Menu Bar Extra** : icône lune + temps restant (`01:32`) affiché en permanence dans la barre de menus. Devient rouge sous les 10 minutes. Clic ouvre la fenêtre principale.

---

## 6. Écran de friction (22h00)

- Plein écran sombre avec animation lunaire
- Message : "Tu aurais dû dormir"
- Bouton "J'ignore" nécessite **3 taps** pour s'activer
- Message de culpabilité progressif à chaque tap :
  1. "Tu es sûr ?"
  2. "Vraiment sûr ?"
  3. "OK, mais tu le regretteras demain."
- Après le 3e tap : l'app passe en arrière-plan (iOS) / la fenêtre se ferme (macOS)
- Sur Mac : fenêtre plein écran bloquante (peut être fermée via Cmd+W après les 3 taps)

---

## 7. Suivi du sommeil

- Bouton **"Je dors 🌙"** visible sur la home dès 21h00
- Appui : enregistre `HKCategorySample` (type `.sleepAnalysis`, value `.asleepUnspecified`) dans HealthKit avec l'heure courante
- Backup automatique : au réveil, l'app lit HealthKit pour récupérer l'heure d'endormissement si le bouton n'a pas été pressé (données Apple Watch / iPhone auto-détection)
- L'heure retenue = la plus tôt entre bouton manuel et HealthKit

---

## 8. Streak & historique

- **Règle streak** : couché avant 22h = +1. Couché après ou pas de données = remise à zéro.
- Streak affiché sur la home (grande typographie) avec label "nuits consécutives"
- **Calendrier historique** : grille de points colorés style GitHub contributions (vert = avant 22h, orange = légèrement après, rouge = raté, gris = pas de données)
- Record personnel affiché sous la grille

---

## 9. Paramètres

- Heure cible configurable (défaut 22h)
- Activation/désactivation des notifications spam
- Activation/désactivation de l'écran de friction
- Permissions : notifications, HealthKit (lecture + écriture sommeil)

---

## 10. Ce qui est hors scope

- Blocage d'apps tiers (Screen Time API non publique sur iOS)
- Sons / musiques de relaxation
- Alarme réveil
- Partage social du streak
