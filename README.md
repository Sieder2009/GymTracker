# 🏋️ Ironpeak Fitness

**Trainingsplan, Kraft-Fortschritt und ein extrem tiefes Analytics-System — als
native App für Android, iOS und Windows.** Alle Daten bleiben **komplett
lokal auf deinem Gerät**: keine Cloud, kein eigener Server, kein Account,
kein Tracking.

[![Android Build](https://github.com/Sieder2009/GymTraker/actions/workflows/android.yml/badge.svg)](https://github.com/Sieder2009/GymTraker/actions/workflows/android.yml)
[![iOS Build](https://github.com/Sieder2009/GymTraker/actions/workflows/ios.yml/badge.svg)](https://github.com/Sieder2009/GymTraker/actions/workflows/ios.yml)
[![Windows Build](https://github.com/Sieder2009/GymTraker/actions/workflows/windows.yml/badge.svg)](https://github.com/Sieder2009/GymTraker/actions/workflows/windows.yml)
[![macOS Build](https://github.com/Sieder2009/GymTraker/actions/workflows/macos.yml/badge.svg)](https://github.com/Sieder2009/GymTraker/actions/workflows/macos.yml)
![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS-informational)
![Local-only](https://img.shields.io/badge/Data-100%25%20local-1fa76a)

---

## Inhalt

- [Was ist Ironpeak Fitness?](#was-ist-ironpeak-fitness)
- [Features](#features)
  - [Training](#training)
  - [Analytics — eigener Tab](#analytics--eigener-tab)
  - [Übungsdatenbank](#übungsdatenbank)
  - [Sonstiges](#sonstiges)
- [App herunterladen](#app-herunterladen)
- [Einrichtung für Entwickler](#einrichtung-für-entwickler)
- [Konfiguration (`.env`)](#konfiguration-env)
- [Tests & Codequalität](#tests--codequalität)
- [Projektstruktur](#projektstruktur)
- [Datenschutz](#datenschutz)
- [Credits](#credits)

---

## Was ist Ironpeak Fitness?

Ironpeak Fitness ist eine einzige, native **Flutter-App** — kein
Web-Zweitprojekt, kein separater Electron-Build, ein Codebase für **Android,
iOS und Windows** (macOS läuft ebenfalls über CI mit). Die App ist bewusst
so aufgebaut, dass sich alles über **vier klare Haupt-Tabs** erschließt statt
über verschachtelte Menüs:

| Tab | Zweck |
|---|---|
| **Training** | Heutiger Trainingstag, geführtes Workout, Plan wählen/anlegen/importieren |
| **Kraft** | Bench Press / Deadlift / Squat: PR, Verlauf, Trend |
| **Analyse** (deutsch für "Analytics") | Der eigene Auswertungs-Tab — siehe unten |
| **Übungen** | Durchsuchbare 535-Übungen-Datenbank mit Muskeldiagramm |

Kalender, Foto-Galerie, Einstellungen, Backup, Theme und Sprache hängen
bewusst **nicht** als fünfter/sechster Tab an der Navigationsleiste, sondern
liegen gebündelt in einem einzigen Overflow-Menü oben rechts auf dem
Training-Tab — eine Reihe aus 6+ Icon-Buttons wäre auf Handy-Breite reine
visuelle Unordnung. Ein Tap genügt, um alles zu finden.

## Features

<a id="training"></a>
### 🏋 Training

- Trainingspläne nach Wochentag oder Rotation, von Hand angelegt, per
  Log-Import (eigenes handgeschriebenes Format) oder aus einem von acht
  mitgelieferten Plan-Vorlagen (Onboarding-Auswahl beim ersten Start).
- Geführtes Workout mit Satz-für-Satz-Eingabe, live mitlaufender
  Session-Uhr und RPE-Erfassung pro Satz. Übungsreihenfolge während der
  Session per Drag-and-drop änderbar, ohne den gespeicherten Plan
  anzufassen.
- Pausen-Timer läuft wanduhrzeitbasiert (nicht als reiner Tick-Zähler),
  gleicht sich beim Zurückkehren aus dem Hintergrund sofort wieder ab und
  schickt bei Ablauf eine lokale Push-Benachrichtigung — bleibt korrekt,
  egal wie lange das Handy währenddessen gesperrt war.
- Ziehregler **und** Tastatur-Eingabe fürs Gewicht (Komma oder Punkt als
  Dezimaltrennzeichen).
- Trainingskalender mit Monatsübersicht und Workout-Historie, Foto-Galerie
  für den Trainingsfortschritt.
- Wisch-Navigation zwischen den vier Haupt-Tabs, zusätzlich zur Tab-Leiste
  unten.

<a id="analytics--eigener-tab"></a>
### 📊 Analytics — eigener Tab

Ein komplett eigener Tab, fünf Bereiche, jede Zahl und jeder Chart
nachvollziehbar aus echten geloggten Daten — **nie aus Platzhaltern**. Wo zu
wenig Datenpunkte für eine ehrliche Aussage vorliegen, zeigt die App einen
Hinweistext statt einer erfundenen Linie (`DataQuality` in
`analytics_engine.dart`).

- **Übersicht** — ein Fließtext-Status ("wird besser" / "bleibt stabil" /
  noch keine Daten), plus Kraft-, Volumen-, Konstanz- und
  Körpergewichtstrend auf einen Blick, und ein Wochenvolumen-Chart der
  letzten 8 Wochen.
- **Kraft** — Trend-Chart (30-Tage-Fenster) für Bench Press, Deadlift und
  Squat inklusive Plateau-Erkennung, Start→Jetzt-Vergleich für jede erkannte
  Variante dieser drei Lifts im aktuellen Plan (Tippen öffnet direkt den
  PR-Eintrag), sowie ein eigenständiger **1RM-Rechner** und der
  **DOTS-Score** (powerlifting-normalisierter Kraftvergleich über
  Körpergewicht und Total).
- **Volumen** — Gesamtvolumen diese Woche, Workouts diese Woche, und ein
  Balkendiagramm des wöchentlichen Trainingsvolumens.
- **Konstanz** — aktuelle & beste Trainings-Serie (Streak) in Tagen,
  Workouts diesen Monat, Balkendiagramm der Workouts pro Woche.
- **Erfolge** — vier gestaffelte Achievement-Pfade (Konstanz,
  Trainings-Anzahl, Gesamtvolumen, Anzahl PRs), jede Stufe live aus den
  echten Daten berechnet statt als gespeichertes "freigeschaltet"-Flag
  (`achievements_engine.dart`) — Fortschrittsbalken bis zur nächsten Stufe
  inklusive.

**Daten eintragen, nicht nur ansehen:** Körpergewicht wird als eigener
Verlauf geführt (`BodyWeightProvider`) und fließt direkt in den
DOTS-Score und den Körpergewichtstrend ein; ein PR lässt sich direkt aus
dem Kraft-Bereich heraus eintragen, ohne den Tab zu verlassen.

<a id="übungsdatenbank"></a>
### 💪 Übungsdatenbank

- 535 Übungen, kategorisiert (Brust/Rücken/Schultern/Beine/Arme/Rumpf/
  Cardio), durchsuchbar und filterbar im eigenen "Übungen"-Tab — jede mit
  einer exercise-science-basierten Muskel-Aktivierungs-Zuordnung
  (`lib/data/exercise_muscle_map.dart`).
- Wird **zur Laufzeit von GitHub** geladen (fällt bei fehlendem Internet auf
  einen zuletzt erfolgreichen Cache bzw. die mitgelieferte Kopie zurück) —
  Änderungen an `mobile/assets/exercises.json` in diesem Repo aktualisieren
  die App ohne neues Release.
- **Illustriertes Muskeldiagramm pro Übung** (Front-/Rückansicht,
  Männlich/Weiblich passend zur Athlet:innen-Einstellung): eine vollständig
  durchgezeichnete Körperfigur — Hände, Füße, einzelne Bauchmuskel-Segmente
  inklusive — bei der jede trainierte Muskelgruppe von Weiß (0 %) über
  Hellrot bis Dunkelrot (100 %) eingefärbt wird, exakt nach der
  hinterlegten Aktivierungsstärke. Zum genaueren Ansehen antippen öffnet
  eine Vollbild-Ansicht zum Reinzoomen/Verschieben (`InteractiveViewer`).
- Beim Anlegen einer **eigenen** Übung: derselbe Editor interaktiv — Muskeln
  direkt auf der Figur antippen (echtes Hit-Testing gegen die gezeichnete
  Kontur, keine grobe Trefferfläche) und die Belastungsintensität
  (0–100 %) per Schieberegler einstellen. Sobald konfiguriert, erscheint
  dasselbe Muskeldiagramm auch beim Ausführen dieser Übung im Workout.

<a id="sonstiges"></a>
### ⚙️ Sonstiges

- Health-Anbindung (Apple Health / Health Connect) für Schritte, Gewicht
  und das Zurückschreiben abgeschlossener Workouts.
- Tägliche Trainings-Erinnerung (lokale Benachrichtigung, Uhrzeit frei
  wählbar).
- Automatischer Update-Check gegen GitHub Releases inkl. Hintergrund-
  Download; Installation bleibt ein bewusster Tap.
- Backup/Restore als Textexport (Zwischenablage) **oder** als Datei über
  das native Teilen-Menü — landet z. B. direkt in iCloud Drive oder Google
  Drive, zum Mitnehmen auf ein anderes Gerät. Kein eigener Account, kein
  eigener Server: die Datei geht nur dorthin, wo man sie selbst hinlegt,
  kein automatischer Hintergrund-Sync.
- Individuelle Primär-/Sekundärfarbe (freier Farbwähler), automatischer
  System-Light/Dark-Mode mit manuellem Override.
- 10 Sprachen: Deutsch, Englisch, Spanisch, Französisch, Italienisch,
  Portugiesisch, Niederländisch, Türkisch, Polnisch, Russisch.
- Geführtes Onboarding beim ersten Start, inklusive Plan-Vorlagen-Auswahl.

## App herunterladen

Jeder `vX.Y.Z`-Tag baut über GitHub Actions automatisch (bewusst nicht bei
jedem Push, um nicht bei jedem Commit einen vollen Android-/iOS-Build
anzustoßen):

| Plattform | Format | Workflow |
|---|---|---|
| Android | `.apk` | [`android.yml`](.github/workflows/android.yml) |
| iOS | unsigniertes `.ipa` (siehe Kommentare dort zu eigenem Signing) | [`ios.yml`](.github/workflows/ios.yml) |
| Windows | gepacktes `.zip` | [`windows.yml`](.github/workflows/windows.yml) |
| macOS | unsigniertes, unnotarisiertes `.zip` | [`macos.yml`](.github/workflows/macos.yml) |

Fertige Builds gibt's auf der **[Releases-Seite](../../releases)** dieses
Repos, sobald ein Versions-Tag existiert. Ein manueller
`workflow_dispatch`-Lauf (ohne Tag) ist jederzeit möglich, um einen Fix auf
die Schnelle zu testen, ohne einen Release zu schneiden.

## Einrichtung für Entwickler

Voraussetzung: [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel).

```bash
cd mobile
flutter pub get
flutter gen-l10n        # Lokalisierungen aus lib/l10n/*.arb generieren
flutter run              # Debug-Build auf verbundenem Gerät/Emulator
```

Windows-Release-Build:

```bash
flutter build windows --release
# Ergebnis: mobile/build/windows/x64/runner/Release/ironpeak_mobile.exe
```

## Konfiguration (`.env`)

Alles, was konfigurierbar ist, steht in [`mobile/.env`](mobile/.env) statt
hartkodiert im Code — die Datei enthält keine Geheimnisse und ist bewusst
mit eingecheckt (siehe `lib/config/app_config.dart` für den typisierten
Zugriff darauf):

| Variable | Bedeutung |
|---|---|
| `GITHUB_OWNER` / `GITHUB_REPO` / `GITHUB_BRANCH` | Woher Übungsdatenbank & Update-Checks geladen werden |
| `EXERCISE_DATABASE_PATH` | Pfad zur `exercises.json` im Repo |
| `UPDATE_CHECK_ENABLED` / `UPDATE_CHECK_INTERVAL_HOURS` | Ob und wie oft automatisch auf neue Releases geprüft wird |
| `SUPPORT_EMAIL` / `SUPPORT_PHONE` | Kontakt auf dem Einstellungen-Bildschirm |

## Tests & Codequalität

```bash
cd mobile
flutter analyze
flutter test
```

Jeder Push läuft automatisch durch `flutter analyze` und `flutter test` in
allen vier Plattform-Workflows, bevor überhaupt gebaut wird. Die
Berechnungs-Engines hinter dem Analytics-Tab
(`lib/analytics/analytics_engine.dart`, `lib/analytics/achievements_engine.dart`,
`lib/data/dots_score.dart`) haben eigene, dedizierte Testdateien unter
`mobile/test/` — keine Kennzahl im Analytics-Tab ist ungetestet.

## Projektstruktur

```
mobile/
  lib/
    analytics/          Reine Berechnungs-Engine für Trends/Konsistenz/DOTS/
                         Achievements — nie eine Zahl ohne echte Datenbasis
    config/              Typisierter .env-Zugriff (app_config.dart)
    data/                Konstanten, DOTS-/1RM-Formeln, Muskel-Aktivierung
                         pro Übung, Körperfigur-Atlas fürs Muskeldiagramm,
                         Plan-Vorlagen
    l10n/                ARB-Übersetzungsdateien (10 Sprachen)
    models/              Datenmodelle (Exercise, Program, BigLift, …)
    overlays/             Vollbild-Screens (Plan-Editor, Workout, Settings, …)
    screens/             Die 4 Haupt-Tabs (Training/Kraft/Analytics/Übungen)
                         + Kalender/Galerie (erreichbar über das Overflow-Menü)
    services/            Externe Integrationen (Health, GitHub, Storage, Update)
    state/               Provider (App-weiter State via package:provider)
    theme/               Design-System (Farben, Radien, Typografie)
    widgets/              Wiederverwendbare UI-Bausteine (Charts, Editoren, …)
  test/                  Unit-/Widget-Tests
  tool/seed_demo_data.dart  Entwickler-Skript: Demo-Daten in die lokale DB füllen
```

## Datenschutz

Die App speichert ausschließlich lokal auf dem Gerät (SQLite via
`sqflite`). Es gibt keinen eigenen Server und kein Konto — die einzige
Netzwerk-Kommunikation ist das Laden der Übungsdatenbank (fällt offline auf
die mitgelieferte lokale Kopie zurück) und der Update-Check gegen die
öffentliche GitHub-API, letzterer per `.env` (`UPDATE_CHECK_ENABLED`)
abschaltbar. Der Datei-Export im Backup-Menü nutzt das native
Teilen-Menü des Betriebssystems (z. B. um die Datei in iCloud Drive oder
Google Drive zu speichern) — das ist eine bewusste Aktion des Nutzers, kein
automatischer Cloud-Sync, und die App selbst lädt dabei nichts irgendwohin
hoch.

## Credits

Die illustrierte Körperfigur im Muskeldiagramm (`mobile/lib/data/body_atlas*.dart`)
basiert auf dem SVG-Körpermodell aus
[react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter)
von Hicham ELABBASSI (MIT-Lizenz, © 2022). Die reinen Pfaddaten wurden 1:1
übernommen (TypeScript → Dart, Geometrie unverändert); die
Muskelgruppen-Zuordnung, die geometrische Aufteilung von Deltoideus in
vorderen/seitlichen Kopf sowie von "upper-back" in oberen Rücken/Latissimus,
die Aktivierungsfarbskala, das Hit-Testing und das Caching sind eigene
Arbeit dieses Projekts.
