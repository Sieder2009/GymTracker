# Kilo — website

The presentation site for the app, in German and English, light and dark.
Plain HTML, CSS and JavaScript — **no build step, no libraries**. It is
served straight from this folder (Vercel, `https://ironpeak.siggidy.dev/`);
[`.github/workflows/pages.yml`](../.github/workflows/pages.yml) can publish
the same folder to GitHub Pages.

## Preview locally

Serve the folder with any static server and open the printed address:

```bash
npx serve website            # or: python -m http.server -d website
```

## What's on the page

| Section | What it shows |
|---|---|
| Hero | The headline, the home screen in a phone, rank/streak/PR cards, live release chip |
| Die App | The app's three tabs (Training, Kraft, Übungen) as a tab bar; each tab switches the phone between its real screenshots |
| Training | A GitHub-style training calendar, the streak flame (slider), the creatine tracker (tap it) and "what's next time?" |
| Ränge | All seven rank badges and a rank calculator |
| Ausprobieren | Plate calculator (target weight or tap plates) and the muscle map |
| Funktionen | Feature tiles and the 16 app-icon variants |
| Datenschutz | 0 servers / accounts / trackers, and the three things the app goes online for |
| Download | Every platform, the visitor's own first, with live version and file sizes |
| FAQ | Price, stores, importing, switching phones, ranks, the old name |

Details worth knowing:

- **The look is the app's.** Colors are the tokens from
  `mobile/lib/theme/app_colors.dart`: light is `#F5F5F7` with the blue
  accent, dark is GitHub's black with its green (and the calendar's five
  GitHub greens). The page follows the system like the app does; the
  sun/moon button in the nav overrides it (saved in `localStorage`). Fonts
  are the app's pairing, Sora and Inter.
- **The logo moves exactly like the app's.** `assets/js/logo.js` is a 1:1
  port of `mobile/lib/widgets/ironpeak_logo.dart`: same path strings, same
  timeline (the barbell drops in with Android's bounce, squashes on impact,
  then does one calm rep). It plays as a short launch screen on the first
  visit per tab, on hover in the nav, and on loop in the download section.
- **Screenshots follow the theme.** Every screenshot is a `<picture>` with a
  dark `<source>`; `main.js` points its `media` at the theme that is shown.
- **Live release info.** The page asks the GitHub API for the latest
  release (version, date, file sizes) and falls back silently. Download
  buttons use `releases/latest/download/<file>`, so they never need
  updating. The file names still carry the old name (`ironpeak-fitness-…`)
  on purpose: the in-app updater looks for them.
- **Reduced motion** (`prefers-reduced-motion`) keeps everything except the
  motion. **No JavaScript?** Every section is still there, in German.
- **Nothing from third parties**: fonts are in `assets/fonts/`, no cookies,
  no analytics. The only outside request is the release lookup to
  `api.github.com`.

## The live demos

They run the app's own logic and data, so keep them in sync if those change:

| Demo | Ported from |
|---|---|
| Rank calculator | `mobile/lib/data/lift_rank.dart`, `strength_standards.dart` |
| Plate calculator | `mobile/lib/data/plate_calculator.dart` (exact search, plates can be switched off; tap mode adds plates up) |
| Next session | `mobile/lib/analytics/progression_engine.dart`, texts from `progression*` in the ARB files |
| Muscle map | `mobile/lib/data/exercise_muscle_map.dart` (values), `mobile/lib/widgets/detailed_body_diagram.dart` (colors, shares) |
| Streak flame | `StreakFlame.sizeFor` in `mobile/lib/widgets/streak_flame.dart` |
| App icons | hues from `mobile/lib/theme/launcher_icons.dart` |

`window.KiloDemos` exposes `rankLift`, `calculatePlates`, `suggest` and
`shares` for a quick check in the browser console.

The body figure in `assets/js/body-atlas.js` is generated from
`mobile/lib/data/body_atlas_data.dart` — rerun the generator instead of
editing it:

```bash
npm install --no-save svg-path-bbox
node website/tools/extract-body.mjs
```

## Images

- `assets/img/screens/*-{light,dark}-780.webp` — captures from the Android
  emulator (Pixel 7) with the demo data from `mobile/tool/seed_demo_data.dart`
  (German), status bar in demo mode (9:41). Dark mode is the system's dark
  mode at app start. Exercise names exist in German only, so there is no
  English set.
- `assets/img/ranks/*.webp` and `flame-*.webp` — rendered from
  `RankEmblem` and `StreakFlame` with a throwaway `flutter test` script
  (`RepaintBoundary.toImage`), named after the internal tiers
  (iron = Mortal … champion = Olympian).
- `favicon.svg` is the mark from `ironpeak_logo.dart` (blue tile, or dark
  tile with a white bar in dark mode); `favicon-32.png` and
  `apple-touch-icon.png` come from `mobile/web/`.
- `og.jpg` (1200×630) is the link preview: headline, home screen, rank card.

## Editing text

Both languages sit next to each other in `index.html`:

```html
<span data-l="de">Dein Training.</span><span data-l="en">Your training.</span>
```

CSS hides whichever language isn't active. Attributes (`aria-label`, `alt`)
use `data-i18n` with `data-de-…` / `data-en-…` variants; texts that
JavaScript writes (demo results, page title, meta description, screenshot
alt texts) live in `assets/js/main.js` and `assets/js/demos.js`. The
language comes from the visitor's browser (German if German comes before
English, otherwise English) until they pick one with the DE/EN switch.

Icons are an inline `<symbol>` sprite at the top of `index.html` (Lucide,
plus the GitHub mark from Octicons). To add one, copy the icon's inner SVG
from [lucide.dev](https://lucide.dev) into a new `<symbol id="i-name">`.

## Deployment

Vercel serves this folder as it is, so absolute URLs (canonical, `og:image`,
sitemap, robots, the 404 page) are written out as
`https://ironpeak.siggidy.dev/`. The exercise count (546) is in the HTML
too; `pages.yml` refreshes it from `mobile/assets/exercises.json` when it
builds the GitHub Pages copy.

## Files

```
index.html            the page (both languages, inline icon sprite)
404.html              self-contained "page not found"
robots.txt, sitemap.xml
assets/css/site.css   all styles and the light/dark tokens
assets/js/main.js     language, theme, nav, launch, tour, calendar, flame, creatine, icons, releases
assets/js/demos.js    rank, plates, next session, muscle map
assets/js/logo.js     the Kilo mark and its motion (port of the app's)
assets/js/body-atlas.js   generated body figure (MIT, see header)
assets/fonts/         Sora, Inter (woff2 + OFL licences)
assets/img/           screenshots, rank badges, flame, icons, og.jpg
tools/                generator for body-atlas.js (not deployed)
```

## Credits & licences

- Body figure: [react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter)
  by Hicham ELABBASSI, MIT.
- Fonts: [Sora](https://github.com/sora-xor/sora-font) and
  [Inter](https://github.com/rsms/inter), SIL Open Font License 1.1
  (`assets/fonts/OFL-*.txt`).
- Icons: [Lucide](https://lucide.dev), ISC; GitHub mark from
  [Octicons](https://github.com/primer/octicons), MIT.
- The exercise animations the app can show are third-party media and are
  not used on this site.
