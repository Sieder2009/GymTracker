# Ironpeak Fitness

Trainingsplan, Kraft-Fortschritt (Bench/Deadlift/Squat) und detaillierte
Trainings-Analytics — als **native Mobile-/Desktop-App (Flutter)** und als
**Web-/Windows-Electron-App (Svelte)**. Alle Daten bleiben **komplett lokal
auf deinem Gerät** — keine Cloud, kein eigener Server, kein Account nötig.

Dieses Repository enthält zwei unabhängige Apps mit demselben Grundkonzept:

| | [`mobile/`](mobile) — Flutter | Root (`src/`) — Svelte/Vite |
|---|---|---|
| Plattformen | Android, iOS, Windows | Web (installierbar als PWA), Windows (Electron) |
| Speicherung | SQLite (`sqflite`) | `localStorage` |
| Status | Aktiv weiterentwickelt, voller Funktionsumfang | Stabile Basisversion |

Für neue Features und die volle Feature-Tiefe (Analytics, Health-Sync,
Übungsdatenbank, Erinnerungen, Auto-Update, …) ist **`mobile/`** die
empfohlene App. Die Web-App bleibt als leichtgewichtige Alternative ohne
Installation erhalten.

---

## 📱 Mobile-App (`mobile/`, Flutter)

Vollständig lokale Trainings-App mit tiefem Analytics-System, einer
GitHub-gepflegten Übungsdatenbank, Health-Anbindung und automatischen
Updates. Läuft nativ auf **Android**, **iOS** und **Windows** aus derselben
Codebasis.

### Features

**Training**
- Trainingspläne nach Wochentag oder Rotation, von Hand angelegt, per
  Log-Import (eigenes handgeschriebenes Format) oder aus einem
  Beispielplan.
- Geführtes Workout mit Satz-für-Satz-Eingabe, live mitlaufender
  Session-Uhr und RPE-Erfassung pro Satz. Übungsreihenfolge während der
  Session per Drag-and-drop änderbar, ohne den gespeicherten Plan
  anzufassen.
- Pausen-Timer läuft wanduhrzeitbasiert (nicht als reiner Tick-Zähler) und
  gleicht sich beim Zurückkehren aus dem Hintergrund sofort wieder ab —
  bleibt also korrekt, egal wie lange das Handy währenddessen gesperrt war.
- Ziehregler **und** Tastatur-Eingabe fürs Gewicht (Komma oder Punkt als
  Dezimaltrennzeichen).
- Trainingskalender mit Monatsübersicht und Workout-Historie.
- Wisch-Navigation zwischen den vier Haupt-Tabs (Training/Kraft/
  Fortschritt/Übungen), zusätzlich zur Tab-Leiste unten.

**Analytics** — eigener Tab mit vier Bereichen (Übersicht/Kraft/Volumen/
Konstanz), jede Zahl und jeder Chart nachvollziehbar aus echten geloggten
Daten, nie aus Platzhaltern:
- Trend-Charts (30-Tage-Fenster) für **jede einzelne Übung**, nicht nur die
  drei Hauptlifts — inkl. geschätztem 1RM (Epley-Formel) und
  Plateau-Erkennung.
- Wöchentliches Trainingsvolumen, Workouts/Woche, aktuelle & beste
  Trainings-Serie (Streak).
- DOTS-Score & Total (powerlifting-normalisierter Kraftvergleich),
  eigenständiger 1RM-Rechner.
- Ehrliche Leerzustände: ein Chart mit zu wenig Datenpunkten zeigt einen
  Hinweistext statt einer erfundenen Linie.

**Übungsdatenbank**
- 535 Übungen, kategorisiert (Brust/Rücken/Schultern/Beine/Arme/Rumpf/
  Cardio), durchsuchbar und filterbar im eigenen "Übungen"-Tab — jede mit
  einer exercise-science-basierten Muskel-Aktivierungs-Zuordnung
  (`lib/data/exercise_muscle_map.dart`).
- Wird **zur Laufzeit von GitHub** geladen (fällt bei fehlendem Internet auf
  einen zuletzt erfolgreichen Cache bzw. die mitgelieferte Kopie zurück) —
  Änderungen an `mobile/assets/exercises.json` im Repo aktualisieren die
  App ohne neues Release.
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
  (0–100 %) per Schieberegler einstellen. Das Ergebnis ist keine
  Fleißarbeit für die Schublade: sobald konfiguriert, erscheint dasselbe
  Muskeldiagramm auch beim Ausführen dieser Übung im Workout.

**Sonstiges**
- Health-Anbindung (Apple Health / Health Connect) für Schritte, Gewicht
  und das Zurückschreiben abgeschlossener Workouts.
- Foto-Galerie für Trainingsfortschritt (aus der Galerie wählen oder mit
  der Kamera aufnehmen).
- Tägliche Trainings-Erinnerung (lokale Benachrichtigung, Uhrzeit frei
  wählbar).
- Automatischer Update-Check gegen GitHub Releases inkl. Hintergrund-
  Download; Installation bleibt ein bewusster Tap.
- Backup/Restore als Textexport (Zwischenablage) **oder** als Datei über
  das native Teilen-Menü — landet z. B. direkt in iCloud Drive oder Google
  Drive, zum Mitnehmen auf ein anderes Gerät. Kein eigener Account, kein
  eigener Server: die Datei geht nur dorthin, wo man sie selbst hinlegt,
  kein automatischer Hintergrund-Sync.
- Individuelle Primär-/Sekundärfarbe, automatischer System-Light/Dark-Mode
  mit manuellem Override.
- 10 Sprachen: Deutsch, Englisch, Spanisch, Französisch, Italienisch,
  Portugiesisch, Niederländisch, Türkisch, Polnisch, Russisch.

### Einrichtung

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

Tests & Analyse:

```bash
flutter analyze
flutter test
```

### Konfiguration (`.env`)

Alles, was konfigurierbar ist, steht in [`mobile/.env`](mobile/.env) statt
hartkodiert im Code — die Datei enthält keine Geheimnisse und ist bewusst
mit eingecheckt:

| Variable | Bedeutung |
|---|---|
| `GITHUB_OWNER` / `GITHUB_REPO` / `GITHUB_BRANCH` | Woher Übungsdatenbank & Update-Checks geladen werden |
| `EXERCISE_DATABASE_PATH` | Pfad zur `exercises.json` im Repo |
| `UPDATE_CHECK_ENABLED` / `UPDATE_CHECK_INTERVAL_HOURS` | Ob und wie oft automatisch auf neue Releases geprüft wird |
| `SUPPORT_EMAIL` / `SUPPORT_PHONE` | Kontakt auf dem Einstellungen-Bildschirm |

### App herunterladen

Jeder `vX.Y.Z`-Tag baut über GitHub Actions automatisch (bewusst nicht bei
jedem Push auf `master`, um nicht bei jedem Commit einen vollen
Android-/iOS-Build anzustoßen):

- **Android** — `.apk` (`.github/workflows/android.yml`)
- **iOS** — unsigniertes `.ipa` (`.github/workflows/ios.yml`, siehe
  Kommentare dort zu eigenem Signing)
- **Windows** — gepacktes `.zip` (`.github/workflows/windows.yml`)

Fertige Builds gibt's auf der **[Releases-Seite](../../releases)** dieses
Repos, sobald ein Versions-Tag existiert.

### Projektstruktur

```
mobile/
  lib/
    analytics/          Reine Berechnungs-Engine für Trends/Konsistenz/
                         DOTS — nie eine Zahl ohne echte Datenbasis
    config/              Typisierter .env-Zugriff (app_config.dart)
    data/                Konstanten, DOTS-/1RM-Formeln, Muskel-Aktivierung
                         pro Übung, Körperfigur-Atlas fürs Muskeldiagramm
    l10n/                ARB-Übersetzungsdateien (10 Sprachen)
    models/              Datenmodelle (Exercise, Program, BigLift, …)
    overlays/             Vollbild-Screens (Plan-Editor, Workout, Settings, …)
    screens/             Die 4 Tabs (Training/Kraft/Fortschritt/Übungen)
    services/            Externe Integrationen (Health, GitHub, Storage, Update)
    state/               Provider (App-weiter State via package:provider)
    theme/               Design-System (Farben, Radien, Typografie)
    widgets/              Wiederverwendbare UI-Bausteine (Charts, Editoren, …)
  test/                  Unit-/Widget-Tests
  tool/seed_demo_data.dart  Entwickler-Skript: Demo-Daten in die lokale DB füllen
```

---

## 🖥️ Web-/Desktop-App (Svelte/Electron)

Trainingsplan, Kraft-Fortschritt und Muskelgruppen-Balance als Web-App
(installierbar aufs Handy) **und** als Windows-Desktop-App (Electron) —
Daten liegen im `localStorage` des Browsers/der App.

### Auf dem Handy installieren

Die App läuft als [GitHub Pages](https://sieder2009.github.io/GymTraker/) —
kostenlos gehostet, nur der App-Code liegt dort, deine Trainingsdaten
bleiben im `localStorage` deines Handy-Browsers.

> Der Link leitet automatisch weiter zu
> **https://monster.sieder.plattnericus.dev/GymTraker/** (eigene Domain) —
> das ist beabsichtigt, beide Adressen zeigen auf dieselbe, kostenlos über
> GitHub Pages gehostete App.

1. Im Handy-Browser öffnen: **https://sieder2009.github.io/GymTraker/**
2. **iOS (Safari):** Teilen-Symbol → "Zum Home-Bildschirm".
   **Android (Chrome):** Menü (⋮) → "App installieren".
3. Die App startet danach vollflächig ohne Browser-Leiste und funktioniert
   auch offline (nur das erste Laden braucht Internet).

Jeder Push auf `master` veröffentlicht automatisch die neueste Version
(`.github/workflows/pages.yml`); dafür muss einmalig unter **Settings →
Pages → Source** "GitHub Actions" ausgewählt sein.

### Sieder Hub (Spiele, Links, Zugang zur App)

Unter **https://sieder2009.github.io/GymTraker/home/** liegt der "Sieder
Hub" — ein kleines Portal (statisches HTML/CSS/JS in `public/home/`, wird bei
jedem Build automatisch mit veröffentlicht) mit durchgängiger Navigation
zwischen allen Unterseiten: Spiele (3 Gewinnt, 4 Gewinnt, Blackjack),
persönliche Infos, Social-Media-Links und ein **Trainingsplan-Archiv**
(`public/home/archiv/`, 6 alte, handgeschriebene Trainingspläne v2.0–v7.0 im
originalen grünen Terminal-Look) — sowie einer prominenten Karte, die direkt
zur GymTraker-App führt. Komplett eigenständig von der Svelte-App, teilt sich
nur das Repo und den Deploy.

### Windows-Desktop-App herunterladen

Auf der **[Releases-Seite](../../releases)** die neueste
`Ironpeak-Fitness-*-portable.exe` herunterladen und doppelklicken — keine
Installation nötig. Windows SmartScreen warnt ggf. vor der unsignierten
`.exe` ("Weitere Informationen" → "Trotzdem ausführen").

Wird automatisch von GitHub Actions gebaut, sobald ein Versions-Tag
(`vX.Y.Z`) gepusht wird (`.github/workflows/release.yml`).

### Entwicklung

Node.js (Version 18+) wird benötigt.

```bash
npm install
npm run dev             # Browser-Entwicklungsserver (Vite)
npm run electron:dev    # App im Electron-Fenster, mit Hot-Reload
npm run electron:build  # Windows-.exe bauen (landet in release/)
```

### Trainingsplan anlegen & nutzen

Drei Optionen, um einen Plan zu bekommen:

- **+ Neuer Plan** — eigenen Plan Tag für Tag von Hand zusammenstellen.
- **Log importieren** — eigenes handgeschriebenes Trainingslog als `.txt`
  hochladen oder Text einfügen.
- **Beispielplan laden** — lädt ein mitgeliefertes, echtes Trainingslog
  (`src/lib/exampleLog.js`).

Auf eine Übung tippen öffnet die Detailansicht: Gewicht (vorausgefüllt mit
dem letzten Wert) im Zahlenfeld anpassen, Wiederholungen pro Satz eintragen,
"Speichern" sichert den Eintrag und springt zur nächsten Übung. Zwischen
Übungen lässt sich auch per Wisch-Geste oder Pfeiltasten wechseln. Übungen
lassen sich umbenennen (Verlauf bleibt erhalten) oder nachträglich per
Text-Einfügen mit Verlauf befüllen.

**Wie die App ein Log liest** (`src/lib/logParser.js`):
- `"1PR(27.04.2026)"` gefolgt von `"Deadlift 150kg"`-Zeilen wird als PR-Block
  mit Datum erkannt.
- `"1. Wochentag"`, `"2. Wochentag"` usw. beginnt einen neuen Tag (1–6 →
  Montag–Samstag, Sonntag automatisch Ruhetag).
- Zeilen ohne führende Zahl sind ein neuer Übungsname; ein `NxM`- oder
  `NxM-M`-Muster darin wird als Satz-/Wiederholungsschema übernommen,
  Klammer-Zusätze werden als Notiz angezeigt.
- Zeilen mit führender Zahl sind Satz-Zeilen der zuletzt genannten Übung;
  das zuletzt geloggte Gewicht wird als aktuelles Gewicht übernommen, die
  volle Historie bleibt erhalten.
- Vor dem Speichern zeigt die App eine Vorschau samt Warnhinweisen — erst
  nach Bestätigung wird gespeichert.

Existieren mehrere gespeicherte Pläne, fragt die App bei jedem Start,
welcher heute genutzt werden soll.

### Projektstruktur

```
electron/
  main.cjs             Electron-Hauptprozess
  preload.cjs
public/
  manifest.json        Web-App-Manifest (Handy-Installation)
  icon.svg, icon-*.png Icons fürs Manifest / Home-Bildschirm
  home/                Sieder Hub: Spiele, Infos, Medien, Link zur App
scripts/
  gen-icons.mjs        Erzeugt icon-*.png aus icon.svg
src/
  main.js              Einstiegspunkt
  App.svelte           Bildschirm-Umschaltung + Tabbar
  app.css              Design-System
  lib/
    stores.js          App-Daten (Svelte Stores)
    persisted.js       localStorage-Anbindung
    data.js            Trainingsplan-Hilfsfunktionen
    exampleLog.js       Mitgeliefertes Beispiel-Trainingslog
    logParser.js        Parser für importierte Log-Texte
    Training.svelte, PlanEditor.svelte, ImportLog.svelte,
    ExerciseDetail.svelte, Strength.svelte,
    Progress.svelte, RadarChart.svelte, TabBar.svelte, Icon.svelte, Toast.svelte
```

---

## 🙏 Credits

Die illustrierte Körperfigur im Muskeldiagramm (`mobile/lib/data/body_atlas*.dart`)
basiert auf dem SVG-Körpermodell aus
[react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter)
von Hicham ELABBASSI (MIT-Lizenz, © 2022). Die reinen Pfaddaten wurden 1:1
übernommen (TypeScript → Dart, Geometrie unverändert); die
Muskelgruppen-Zuordnung, die geometrische Aufteilung von Deltoideus in
vorderen/seitlichen Kopf sowie von "upper-back" in oberen Rücken/Latissimus,
die Aktivierungsfarbskala, das Hit-Testing und das Caching sind eigene
Arbeit dieses Projekts.

---

## Datenschutz

Beide Apps speichern ausschließlich lokal auf dem jeweiligen Gerät (SQLite
bzw. `localStorage`). Es gibt keinen eigenen Server und kein Konto — die
einzige Netzwerk-Kommunikation der Mobile-App ist das Laden der
Übungsdatenbank und der Update-Check gegen die öffentliche GitHub-API. Der
Datei-Export im Backup-Menü nutzt das native Teilen-Menü des Betriebssystems
(z. B. um die Datei in iCloud Drive oder Google Drive zu speichern) — das
ist eine bewusste Aktion des Nutzers, kein automatischer Cloud-Sync, und die
App selbst lädt dabei nichts irgendwohin hoch.
