<div align="center">

<img src="mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="72" height="72" alt="Kilo app icon"/>

# Kilo

**A workout planner, strength tracker, and analytics tool — built as a
native app for Android, iOS, Windows, and macOS.** All your data stays
**100% on your device**: no cloud, no server, no account, no tracking.

[![Android Build](https://github.com/Sieder2009/GymTracker/actions/workflows/android.yml/badge.svg)](https://github.com/Sieder2009/GymTracker/actions/workflows/android.yml)
[![iOS Build](https://github.com/Sieder2009/GymTracker/actions/workflows/ios.yml/badge.svg)](https://github.com/Sieder2009/GymTracker/actions/workflows/ios.yml)
[![Windows Build](https://github.com/Sieder2009/GymTracker/actions/workflows/windows.yml/badge.svg)](https://github.com/Sieder2009/GymTracker/actions/workflows/windows.yml)
[![macOS Build](https://github.com/Sieder2009/GymTracker/actions/workflows/macos.yml/badge.svg)](https://github.com/Sieder2009/GymTracker/actions/workflows/macos.yml)

![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS-informational)
![Local-only](https://img.shields.io/badge/Data-100%25%20local-2f6feb)
![Latest Release](https://img.shields.io/github/v/release/Sieder2009/GymTracker?color=2f6feb&label=latest%20release)

[![Website](https://img.shields.io/badge/Website-Kilo-2f6feb?style=for-the-badge&labelColor=0b1220)](https://sieder2009.github.io/GymTracker/)

</div>

---

## <img src="https://api.iconify.design/lucide:list.svg?color=%232f6feb" width="20" height="20" alt=""/> Contents

- [What is Kilo?](#what-is-kilo)
- [Screenshots](#screenshots)
- [Features](#features)
  - [Training & home screen](#training)
  - [Strength & ranks](#strength)
  - [Analytics — its own tab](#analytics--its-own-tab)
  - [Exercise database](#exercise-database)
  - [Settings & more](#more-features)
- [Download the app](#download-the-app)
- [Setup for developers](#setup-for-developers)
- [Configuration (`.env`)](#configuration-env)
- [Tests & code quality](#tests--code-quality)
- [Project structure](#project-structure)
- [Privacy](#privacy)
- [Credits](#credits)

---

## <img src="https://api.iconify.design/lucide:info.svg?color=%232f6feb" width="20" height="20" alt=""/> What is Kilo?

Kilo (formerly Ironpeak Fitness) is one single, native **Flutter app**. It
is not a web app with a separate build, and not an Electron app. One
codebase runs on **Android, iOS, Windows, and macOS**. The app is built
around **four main tabs**, so you don't need to search through many menus:

| Tab | What it's for |
|---|---|
| **Training** | Your home screen: training calendar, creatine tracker, today's plan; choose/create/import a plan |
| **Strength** | Bench Press / Deadlift / Squat: ranks, PRs, history, trend, DOTS, plus 1RM, plate and calorie calculators |
| **Analytics** | Progress, body measurements, strength trends and consistency — see below |
| **Exercises** | A searchable database of 546 exercises with muscle diagrams and demo animations |

The calendar, photo gallery, settings, backup, theme, and language are
**not** extra tabs at the bottom. They live together in one ⋮ menu at the
top right of the Training tab. The app version sits as a small pill at the
top left; when an update is available it turns into a "↑ vX.Y.Z" button.

## <img src="https://api.iconify.design/lucide:image.svg?color=%232f6feb" width="20" height="20" alt=""/> Screenshots

<table>
<tr>
<td width="25%"><img src="screenshots/screenshot-training.png" alt="Training tab: today's workout with set tracking and rest timer"/></td>
<td width="25%"><img src="screenshots/screenshot-strength.png" alt="Strength tab: bodyweight log, DOTS score, and a Bench Press card"/></td>
<td width="25%"><img src="screenshots/screenshot-analytics.png" alt="Analytics tab: overview stats and weekly volume"/></td>
<td width="25%"><img src="screenshots/screenshot-exercises.png" alt="Exercise database with muscle activation diagram"/></td>
</tr>
<tr>
<td align="center"><sub><b>Training</b></sub></td>
<td align="center"><sub><b>Strength</b></sub></td>
<td align="center"><sub><b>Analytics</b></sub></td>
<td align="center"><sub><b>Exercises</b></sub></td>
</tr>
</table>

> Real captures from the iOS Simulator (iPhone 17, iOS 26), taken in
> August 2026 — before the Kilo redesign, so the home screen, the ranks
> and the radar charts described below aren't in them yet.

## Features

<a id="training"></a>
### <img src="https://api.iconify.design/lucide:dumbbell.svg?color=%232f6feb" width="20" height="20" alt=""/> Training & home screen

- **The home screen** starts with today's date and a **GitHub-style
  training calendar** of the last few months (tap it, or any day, for the
  full calendar). Below it sits a compact **creatine tracker**: one tap
  ticks off today, the last seven days are small dots you can fix
  afterwards, and a 🔥 shows how many days in a row you've taken it.
- Then **today's plan**: day pills to look at any weekday, "Move to
  another day" to reschedule a session, today's exercises plus the ones
  you do on every training day — drag to reorder, link two exercises into
  a **superset**, move an exercise to another day.
- Two parts are **optional** and off by default — turn them on under
  Settings → Home screen: a "Next workout" card (number of exercises and
  estimated duration) and the **"Start workout"** button for the guided
  session.
- Workout plans by weekday or rotation. Create them by hand, import a plan
  from your own log format, or pick one of eight built-in templates
  (shown during onboarding on first launch).
- **Guided workouts** with set-by-set input, a live session timer, and
  RPE *or* RIR for each set (your choice in Settings). Exercises can be
  logged by reps, **timed** (planks, holds) or as **cardio** (minutes and
  speed), and **unilateral** exercises per side. You can reorder exercises
  during a session without changing your saved plan.
- The rest timer uses real clock time, not a simple countdown. It syncs
  right away when you return from the background and sends a local push
  notification when it ends — it stays accurate no matter how long your
  phone was locked.
- Enter weight with a **slider or the keyboard** (comma or dot as the
  decimal separator), as a total or per side of the bar (bar weight is
  set in Settings).
- **Progressive overload suggestions.** Every exercise with logged history
  gets a plain-language nudge for what to try next session — double
  progression within its configured rep range: a full clear on reps bumps
  the weight (+2.5kg, +5kg for leg exercises), landing short of the top
  holds the weight and chases one more rep, and two missed sessions in a
  row suggest a deload instead of grinding at a stuck weight
  (`analytics/progression_engine.dart`). Built only from real numeric reps
  you logged — never a guess when a set only carries a '✓'/'x'/'m' marker.
- **Animated exercise demos.** 354 of the 546 exercises in the database
  show a short animation of how the movement is done: in the Exercises
  tab, in the exercise editor, during a guided workout, and as an
  "up next" preview while you rest. The animations are third-party media
  that the app loads on demand and never bundles. See
  [Exercise animations](#exercise-animations) for where they come from.
- The **full training calendar**: every day of the last 12 months is a
  small square, shaded by that day's training volume or time, with
  GitHub's five levels and "Less … More" legend, a year selector and your
  current and best streak. Rest days from your plan don't break a streak.
  Tapping a day shows its sessions. Open it from the home screen, the
  Analytics tab (Consistency), or the ⋮ menu. There's also a photo
  gallery for your progress.
- Swipe between the four main tabs, or use the tab bar at the bottom.

<a id="strength"></a>
### <img src="https://api.iconify.design/lucide:trophy.svg?color=%232f6feb" width="20" height="20" alt=""/> Strength & ranks

The Strength tab has an **Overview** and one tab each for **Bench
Press, Deadlift and Squat**. The three calculators sit as icons in its
header.

- **Ranks.** Every lift gets a game-style rank from your PR relative to
  your bodyweight: **Mortal, Warrior, Spartan, Hero, Demigod, Titan and
  Olympian**, each split into divisions III–I (Olympian has none). Each
  rank is an animated crystal badge with a symbol from Greek myth — skull,
  crossed axes, Corinthian helmet, Greek hero, winged helmet, Atlas and
  Zeus (`widgets/rank_emblem.dart`). The Overview shows your **overall
  rank** (the average of the three) with a progress bar to the next
  division and an "All ranks" list; each lift's tab also tells you how
  many kilograms are still missing. Built on bodyweight-relative strength
  standards (`data/lift_rank.dart`, `data/strength_standards.dart`).
  Ranks need a logged bodyweight.
- Log your bodyweight and your PRs. The three PRs also appear as a
  **radar chart** on one shared kg scale, with one place to enter all
  three at once.
- Total (Bench+Deadlift+Squat) and **DOTS score** for anyone who wants the
  bodyweight-normalized comparison number competitive powerlifters use
  (`data/dots_score.dart`).
- A **lift balance** check: is your bench press around 0.65–0.85× and
  your deadlift around 1.1–1.35× your squat? (`data/lift_balance.dart`)
- Each lift's own tab: its rank badge and progress, a date-based trend
  chart with a 4W/3M/6M/1Y/All range selector, plateau detection
  (`plateau_notice.dart`), PR entry, and the logged history as a list.
- Three built-in calculators, all pure scratchpad tools that don't read or
  write your logged data: a **1RM calculator** (Epley formula), a **plate
  calculator** — given a target weight and bar weight, it works out which
  plates go on each side from a standard kg or lb set
  (`data/plate_calculator.dart`) — and a **calorie & macro calculator**
  (Mifflin-St Jeor with an activity level and a goal of losing,
  maintaining or gaining; `data/calorie_calculator.dart`).

<a id="analytics--its-own-tab"></a>
### <img src="https://api.iconify.design/lucide:bar-chart-3.svg?color=%232f6feb" width="20" height="20" alt=""/> Analytics — its own tab

A full tab with three sections. Every number and every chart comes from
your real logged data — **never from placeholder values**. If there isn't
enough data yet for an honest chart, the app shows a short message
instead of a made-up line (`DataQuality` in `analytics_engine.dart`).

- **Overview** — workouts, volume, current streak and PRs at a glance; a
  plain-text status ("getting better" / "staying stable" / not enough
  data yet) for strength and volume; **body measurements** (chest, waist,
  hips, arm, thigh, calf) with a trend chart per field and a radar chart
  of first vs. latest value; and a weekly volume chart for the last 8
  weeks.
- **Strength** — a trend chart for Bench Press, Deadlift, and Squat, with
  start-vs-now numbers for every detected variant of these lifts in your
  current plan (tap one to enter its PR). This is the Analytics tab's
  own strength *trend* view, a different screen from the bottom
  "Strength" tab despite the shared name.
- **Consistency** — your current and best training streak, the
  GitHub-style activity graph of your training days (tap a day to open
  the full calendar), and a bar chart of workouts per week.

<a id="exercise-database"></a>
### <img src="https://api.iconify.design/lucide:database.svg?color=%232f6feb" width="20" height="20" alt=""/> Exercise database

- 546 exercises, sorted by category (chest/back/shoulders/legs/arms/
  core/cardio), searchable and filterable by muscle in the "Exercises"
  tab. Each one has a muscle activation mapping based on exercise science
  (`lib/data/exercise_muscle_map.dart`).
- An exercise's page shows the **muscles worked** first, then the demo
  animation, then the how-to text under a "?" header with a video link
  below it.
- The database **loads live from GitHub** (it falls back to the last
  cached copy, or the built-in copy, if you're offline). Changes to
  `mobile/assets/exercises.json` in this repo update the app without a
  new release.
- **Animated demos for 354 exercises.** Which animation belongs to which
  exercise is set in `lib/data/exercise_gifs.dart`, keyed by exercise id.
  Every entry there was matched by movement *and* equipment and checked
  against the animation's still frame. An exercise with no correct match
  (e.g. chain/band variants, Olympic lifts, neck work, most outdoor
  cardio) gets no animation rather than a wrong one. The GIFs load on
  first view and then stay cached on the device. In Settings you can
  download all of them for offline use (about 30 MB) or turn them off
  completely.
- **An illustrated muscle diagram for every exercise** (front/back view,
  male/female to match your athlete setting): a fully drawn body figure
  — hands, feet, and separate ab segments included — where every trained
  muscle group is colored from white (0%) through light red to dark red
  (100%), based on its exact activation level. Tap it for a full-screen
  view you can zoom and drag (`InteractiveViewer`).
- When you create your **own** exercise, you get the same editor: tap
  muscles directly on the figure (real hit-testing against the drawn
  outline, not a rough tap area) and set the activation level (0–100%)
  with a slider. Once it's set up, the same muscle diagram shows up when
  you do that exercise in a workout.

<a id="more-features"></a>
### <img src="https://api.iconify.design/lucide:settings-2.svg?color=%232f6feb" width="20" height="20" alt=""/> Settings & more

- **Home screen:** show or hide the "Next workout" card and the "Start
  workout" button.
- **Appearance:** custom primary and secondary colors (full color picker),
  automatic system light/dark mode with a manual override, and a custom
  theme for background, card and text colors.
- **App icon:** a barbell icon that follows the app's look — a tile in
  your primary color in light mode, a dark tile in dark mode. On Android
  the home-screen icon switches between 16 variants once you leave the
  app (custom colors snap to the nearest one), or you pick one yourself;
  iOS 18 adds its own dark and tinted versions. The launch screen follows
  the app's theme too.
- Athlete profile (male/female for the formulas), RPE or RIR, and the
  bar weight.
- Health integration (Apple Health / Health Connect) for steps, weight,
  and writing back finished workouts.
- A daily training reminder (local notification, pick your own time).
- Automatic update checks against GitHub Releases, with a background
  download — one tap on the version pill installs it, or let the app
  install it by itself the next time it opens.
- Backup and restore as a text export (clipboard) **or** as a file through
  the native share menu — for example straight into iCloud Drive or
  Google Drive, so you can move to another device. No account, no
  server: the file only goes where you send it, there's no automatic
  background sync.
- 10 languages: German, English, Spanish, French, Italian, Portuguese,
  Dutch, Turkish, Polish, Russian.
- A guided onboarding flow on first launch, including the plan template
  picker.

## <img src="https://api.iconify.design/lucide:download.svg?color=%232f6feb" width="20" height="20" alt=""/> Download the app

Every `vX.Y.Z` tag triggers an automatic build through GitHub Actions.
This does **not** happen on every push, so a full Android/iOS build
doesn't run on every single commit:

| Platform | Format | Workflow |
|---|---|---|
| Android | `.apk` | [`android.yml`](.github/workflows/android.yml) |
| iOS | unsigned `.ipa` (see the comments there about signing it yourself) | [`ios.yml`](.github/workflows/ios.yml) |
| Windows | a real installer (`ironpeak-fitness-windows-setup.exe`, built with Inno Setup — Start Menu shortcut, proper uninstall, replaces a running install in place), plus a portable `.zip` for anyone who'd rather not install anything | [`windows.yml`](.github/workflows/windows.yml) |
| macOS | unsigned, unnotarized `.zip` | [`macos.yml`](.github/workflows/macos.yml) |

You'll find finished builds on this repo's **[Releases page](../../releases)**.
The app's version number comes from the tag, not from `pubspec.yaml`. You
can also trigger a manual `workflow_dispatch` run (without a tag) any
time, to quickly test a fix without cutting a full release.

> <img src="https://api.iconify.design/lucide:badge-check.svg?color=%232f6feb" width="16" height="16" alt=""/> **Build status:** each workflow runs `flutter analyze` and
> `flutter test` before building anything, so a broken commit fails
> loudly instead of silently shipping. A tagged release (`vX.Y.Z`)
> produces `app-release.apk`, `ironpeak-fitness-ios-unsigned.ipa`,
> `ironpeak-fitness-windows-setup.exe` + `ironpeak-fitness-windows.zip`,
> and `ironpeak-fitness-macos.zip` — check the
> [Releases page](../../releases) for the actual files on the latest tag.

## <img src="https://api.iconify.design/lucide:terminal.svg?color=%232f6feb" width="20" height="20" alt=""/> Setup for developers

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel).

```bash
cd mobile
flutter pub get
flutter gen-l10n        # generate translations from lib/l10n/*.arb
flutter run              # debug build on a connected device/emulator
```

Windows release build:

```bash
flutter build windows --release
# Output: mobile/build/windows/x64/runner/Release/ironpeak_mobile.exe
```

To also build the installer locally (Windows only, needs
[Inno Setup](https://jrsoftware.org/isinfo.php) installed):

```bash
iscc /DMyAppVersion=0.0.0 windows/installer/installer.iss
# Output: mobile/build/windows/x64/runner/ironpeak-fitness-windows-setup.exe
```

## <img src="https://api.iconify.design/lucide:sliders-horizontal.svg?color=%232f6feb" width="20" height="20" alt=""/> Configuration (`.env`)

Everything you can configure lives in [`mobile/.env`](mobile/.env), not
hardcoded in the app. This file has no secrets in it, so it's checked
into the repo on purpose (see `lib/config/app_config.dart` for the typed
way the app reads it):

| Variable | What it does |
|---|---|
| `GITHUB_OWNER` / `GITHUB_REPO` / `GITHUB_BRANCH` | Where the exercise database and update checks load from |
| `EXERCISE_DATABASE_PATH` | Path to `exercises.json` in the repo |
| `UPDATE_CHECK_ENABLED` / `UPDATE_CHECK_INTERVAL_HOURS` | Whether and how often the app checks for new releases |
| `SUPPORT_EMAIL` / `SUPPORT_PHONE` | Contact info shown on the Settings screen |
| `EXERCISE_MEDIA_BASE_URL` | Where the exercise animations load from, by default the [exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) pinned to one commit via jsDelivr (see [Exercise animations](#exercise-animations)) |

## <img src="https://api.iconify.design/lucide:flask-conical.svg?color=%232f6feb" width="20" height="20" alt=""/> Tests & code quality

```bash
cd mobile
flutter analyze
flutter test
```

Every release runs through `flutter analyze` and `flutter test` in all
four platform workflows, before anything gets built. The calculation
engines behind the Analytics tab (`lib/analytics/analytics_engine.dart`,
`lib/analytics/progression_engine.dart`, `lib/analytics/heatmap_engine.dart`,
`lib/analytics/rest_days.dart`) and the Strength tab
(`lib/data/lift_rank.dart`, `lib/data/dots_score.dart`,
`lib/data/strength_standards.dart`, `lib/data/plate_calculator.dart`,
`lib/data/calorie_calculator.dart`) all have their own dedicated test
files under `mobile/test/` — pure calculations, not just UI, so every
number you see on either tab traces back to a tested function.

## <img src="https://api.iconify.design/lucide:folder-tree.svg?color=%232f6feb" width="20" height="20" alt=""/> Project structure

```
mobile/
  lib/
    analytics/           Pure calculation engines for trends, consistency,
                         streaks, the training calendar and progression —
                         never a number without real data
    config/              Typed .env access (app_config.dart)
    data/                Constants, ranks, DOTS/1RM/plate/calorie formulas,
                         per-exercise muscle activation, body figure atlas
                         for the muscle diagram, plan templates
    l10n/                ARB translation files (10 languages)
    models/              Data models (Exercise, Program, BigLift, …)
    overlays/            Full-screen screens (plan editor, workout, settings, …)
    screens/             The 4 main tabs (Training/Strength/Analytics/Exercises)
                         + calendar/gallery (reachable from the ⋮ menu)
    services/            External integrations (Health, GitHub, storage, update)
    state/               Providers (app-wide state via package:provider)
    theme/               Design system (colors, radii, typography, app icons)
    widgets/             Reusable UI building blocks (charts, rank badges,
                         editors, sheets, …)
  test/                  Unit/widget tests
  tool/seed_demo_data.dart  Developer script: fills demo data into the local DB
  tool/generate_icons.dart  Developer script: re-renders every app icon (the 16
                             Android launcher variants and their release-only
                             aliases, animated launch icon, web, Windows .ico,
                             iOS/macOS asset PNGs) from lib/widgets/ironpeak_logo.dart
                             and lib/theme/launcher_icons.dart
                             (`flutter test tool/generate_icons.dart`)
website/                 The presentation site on GitHub Pages — plain
                         HTML/CSS/JS, deployed by .github/workflows/pages.yml
                         (see website/README.md)
```

## <img src="https://api.iconify.design/lucide:shield-check.svg?color=%232f6feb" width="20" height="20" alt=""/> Privacy

The app stores everything only on your device (SQLite via `sqflite`).
There is no server and no account. The only network traffic is loading
the exercise database (it falls back to the built-in local copy when
offline), the update check against the public GitHub API — you can
turn the update check off in `.env` (`UPDATE_CHECK_ENABLED`) — and,
while exercise animations are switched on, downloading each animation
from the jsDelivr CDN the first time you open it. That download is a
plain file request with no account or personal data, and afterwards the
file is served from the on-device cache. You can switch it off under
Settings → Exercise animations. The file
export in the backup menu uses your operating system's native share
menu (for example, to save the file to iCloud Drive or Google Drive).
This is something you choose to do — it is not an automatic cloud sync,
and the app itself never uploads anything on its own.

## <img src="https://api.iconify.design/lucide:award.svg?color=%232f6feb" width="20" height="20" alt=""/> Credits

Special thanks to **[Plattnericus](https://github.com/Plattnericus)** for
his contribution to this project.

The illustrated body figure in the muscle diagram
(`mobile/lib/data/body_atlas*.dart`) is based on the SVG body model from
[react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter)
by Hicham ELABBASSI (MIT license, © 2022). The raw path data was carried
over 1:1 (TypeScript → Dart, geometry unchanged). The muscle group
mapping, the split of the deltoid into front/side heads and of
"upper-back" into upper back/lats, the activation color scale, the
hit-testing, and the caching are original work for this project.

<a id="exercise-animations"></a>
### Exercise animations (third-party, not part of this repository)

The exercise demo GIFs are **not** in this repository, **not** in the
app's assets and **not** in any release build. The app fetches them on
demand from the [hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)
repository, pinned to one commit and served through jsDelivr
(`EXERCISE_MEDIA_BASE_URL`), and only keeps a cache on your device. The
same approach is used by the open-source tracker
[openGym](https://github.com/DuarteSantos8/openGym).

- The animations are **© [Gym visual](https://gymvisual.com/)**. The
  dataset redistributes them with that rights holder's permission. That
  permission was granted to the dataset and is not transferable.
- The content originally comes from [ExerciseDB](https://exercisedb.dev/)
  (AscendAPI), which also claims ownership and publishes its own terms.
  These two claims contradict each other, and upstream has not resolved
  this yet ([issue #5](https://github.com/hasaneyldrm/exercises-dataset/issues/5)).
- The dataset's MIT license covers its metadata and text, **not** these
  images.

So treat the animations as third-party content licensed neither to this
project nor to you. Before a store release or any commercial use, clear
it with the rights holder.

The assignment of Kilo's exercises to the animations
(`mobile/lib/data/exercise_gifs.dart`) and all of the loading, caching
and display code are original work for this project. No code was copied
from openGym or the dataset.
