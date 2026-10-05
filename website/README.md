# Ironpeak Fitness — website

The presentation site for the app: one page you climb from base camp to the
summit, in German and English. Plain HTML, CSS and JavaScript — **no build
step** — published to GitHub Pages by
[`.github/workflows/pages.yml`](../.github/workflows/pages.yml) whenever
something in `website/` changes on `master`.

## Preview locally

Serve the folder with any static server and open the printed address:

```bash
npx serve website            # or: python -m http.server -d website
```

## What's on the page

| Section | What it shows |
|---|---|
| Hero | Night sky, the Ironpeak mountains, the wordmark — the scene rises as you scroll |
| 01 Basislager | What the app is; the words light up as you read, plus live numbers |
| 02 Die App | The four tabs with the real screenshots in a phone that stays put while you scroll |
| 03 Probier's aus | Three working tools, ported from the app's Dart code (see below) |
| 04 Ausrüstung | Feature grid and two marquee rows |
| 05 Datenschutz | 0 servers, 0 accounts, 0 trackers — while the sun comes up |
| 06 Gipfel | Downloads for every platform, the visitor's own platform first |

Details worth knowing:

- **The logo moves exactly like the app's.** `assets/js/logo.js` is a 1:1
  port of `mobile/lib/widgets/ironpeak_logo.dart`: same path strings, same
  colors, same timeline (pop-in, barbell drop with Android's bounce, glint,
  one rep forever). It plays in the intro, on hover in the nav, and in the
  footer.
- **The favicon lifts the barbell as you scroll down**, and the tab title
  follows the section you're in. A small altimeter on the right counts the
  meters up to the summit.
- **Live release info.** The download section asks the GitHub API for the
  latest release (version, date, file sizes) and falls back silently when it
  can't. The download buttons use `releases/latest/download/<file>`, so they
  never need updating.
- **Reduced motion** (`prefers-reduced-motion`) keeps everything except the
  motion: no intro, no smooth scrolling, no scroll choreography.
- **No JavaScript?** Every section is still there, in German.
- **Nothing from third parties**: fonts and libraries are in `assets/`, there
  are no cookies and no analytics. The only outside request is the release
  lookup to `api.github.com`.

## The live demos

They run the app's own formulas and data, so keep them in sync if those
change in the app:

| Demo | Ported from |
|---|---|
| Plate calculator | `mobile/lib/data/plate_calculator.dart` |
| Strength level | `mobile/lib/data/strength_standards.dart` (thresholds, level names from the ARB files) |
| Muscle map | `mobile/lib/data/exercise_muscle_map.dart` (values), `mobile/lib/widgets/detailed_body_diagram.dart` (color scale) |

The body figure in `assets/js/body-atlas.js` is generated from
`mobile/lib/data/body_atlas_data.dart` — rerun the generator instead of
editing it:

```bash
npm install --no-save svg-path-bbox
node website/tools/extract-body.mjs
```

## Editing text

Both languages sit next to each other in `index.html`:

```html
<span data-l="de">Dein Training.</span><span data-l="en">Your training.</span>
```

CSS hides whichever language isn't active. Attributes (`aria-label`, `alt`)
use `data-i18n` with `data-de-…` / `data-en-…` variants; texts that
JavaScript writes (demo results, page title, meta description) live in
`assets/js/main.js` and `assets/js/demos.js`. The language comes from the
visitor's browser (German if German comes before English, otherwise English)
until they pick one with the DE/EN switch.

Icons are an inline `<symbol>` sprite at the top of `index.html` (Lucide,
plus the GitHub mark from Octicons). To add one, copy the icon's inner SVG
from [lucide.dev](https://lucide.dev) into a new `<symbol id="i-name">`.

## Deployment

`.github/workflows/pages.yml` copies `website/` (without this README and
`tools/`) and fills in two things before uploading:

- `__SITE_URL__` — the site's absolute address, taken from the repository's
  Pages settings. It is only used where a relative URL doesn't work: the
  canonical link, `og:image`, the sitemap and the 404 page. Everything else
  is relative, so the site works on a custom domain and under
  `https://<user>.github.io/<repo>/` alike.
- The exercise count, counted from `mobile/assets/exercises.json` — which is
  why the workflow also runs when the database changes.

Pages must be set to **Settings → Pages → Source: GitHub Actions**.

## Files

```
index.html            the page (both languages, inline icon sprite)
404.html              self-contained "wrong trail" page
robots.txt, sitemap.xml
assets/css/site.css   all styles
assets/js/main.js     language, intro, scrolling, altimeter, favicon, releases
assets/js/demos.js    plate calculator, strength level, muscle map
assets/js/logo.js     the Ironpeak mark and its motion (port of the app's)
assets/js/body-atlas.js   generated body figure (MIT, see header)
assets/js/vendor/     GSAP + ScrollTrigger 3.15, Lenis 1.3
assets/fonts/         Big Shoulders Display, Archivo (woff2 + OFL licences)
assets/img/           screenshots (WebP), icons, og.jpg link preview
tools/                generator for body-atlas.js (not deployed)
```

`assets/img/og.jpg` (1200×630) is a capture of the hero with the page chrome
hidden — take a new one if the hero changes.

## Credits & licences

- Body figure: [react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter)
  by Hicham ELABBASSI, MIT.
- Fonts: [Big Shoulders Display](https://github.com/xotypeco/big_shoulders)
  and [Archivo](https://github.com/Omnibus-Type/Archivo), SIL Open Font
  License 1.1 (`assets/fonts/OFL-*.txt`).
- [GSAP](https://gsap.com) and ScrollTrigger under GreenSock's
  [standard "no charge" license](https://gsap.com/standard-license);
  [Lenis](https://github.com/darkroomengineering/lenis), MIT
  (`assets/js/vendor/LICENSE-lenis.txt`).
- Icons: [Lucide](https://lucide.dev), ISC; GitHub mark from
  [Octicons](https://github.com/primer/octicons), MIT.
