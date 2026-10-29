/*
 * The live demos. Logic and data are ported from the app, so the page
 * computes exactly what the app does:
 *   rank             <- mobile/lib/data/lift_rank.dart + strength_standards.dart
 *   plate calculator <- mobile/lib/data/plate_calculator.dart
 *   next session     <- mobile/lib/analytics/progression_engine.dart
 *                       (texts: progression* in app_de.arb / app_en.arb)
 *   muscle map       <- mobile/lib/data/exercise_muscle_map.dart (values),
 *                       mobile/lib/widgets/detailed_body_diagram.dart (colors,
 *                       shares), assets/js/body-atlas.js (figure, lazy-loaded)
 */
(function () {
  'use strict';

  var root = document.documentElement;
  var calm = root.classList.contains('calm');

  function $(selector, scope) { return (scope || document).querySelector(selector); }
  function $$(selector, scope) { return Array.prototype.slice.call((scope || document).querySelectorAll(selector)); }
  function lang() { return root.lang === 'en' ? 'en' : 'de'; }
  function locale() { return lang() === 'de' ? 'de-DE' : 'en-US'; }

  function fmt(value, min, max) {
    return new Intl.NumberFormat(locale(), {
      minimumFractionDigits: min || 0,
      maximumFractionDigits: max === undefined ? 2 : max
    }).format(value);
  }

  function num(input) {
    var v = parseFloat(String(input.value).replace(',', '.'));
    return isFinite(v) ? v : NaN;
  }

  function checked(scope, name) {
    var el = $('input[name="' + name + '"]:checked', scope);
    return el ? el.value : null;
  }

  function fill(template, vars) {
    return template.replace(/\{(\w+)\}/g, function (_, k) { return vars[k]; });
  }

  function setRangeFill(range) {
    var min = parseFloat(range.min) || 0;
    var max = parseFloat(range.max) || 100;
    var p = (parseFloat(range.value) - min) / (max - min) * 100;
    range.style.setProperty('--p', Math.max(0, Math.min(100, p)) + '%');
  }

  var renderers = [];

  // =========================================================== ranks

  // strength_standards.dart: PR / bodyweight, beginner..elite.
  var THRESHOLDS = {
    m: { bench: [0.5, 0.75, 1.0, 1.5, 2.0], squat: [0.5, 0.75, 1.25, 1.75, 2.25], deadlift: [0.75, 1.0, 1.5, 2.0, 2.5] },
    f: { bench: [0.25, 0.35, 0.5, 0.75, 1.15], squat: [0.35, 0.5, 0.75, 1.25, 1.75], deadlift: [0.5, 0.75, 1.0, 1.5, 2.0] }
  };

  // RankTier iron..champion, shown as these names in every language.
  var TIERS = [
    { key: 'iron', name: 'Mortal', glow: '#9fb6cf' },
    { key: 'bronze', name: 'Warrior', glow: '#ff8a3d' },
    { key: 'silver', name: 'Spartan', glow: '#ff4757' },
    { key: 'gold', name: 'Hero', glow: '#ffc83d' },
    { key: 'platinum', name: 'Demigod', glow: '#2ef2d0' },
    { key: 'diamond', name: 'Titan', glow: '#a585ff' },
    { key: 'champion', name: 'Olympian', glow: '#ffd34d' }
  ];

  /** lift_rank.dart rankLift(): tier, division (3..1, null = champion), progress, kgToNext. */
  function rankLift(lift, liftKg, bodyweightKg, sex) {
    if (!(liftKg > 0) || !(bodyweightKg > 0)) return null;
    var t = THRESHOLDS[sex][lift];
    var bounds = [0].concat(t, [t[4] + (t[4] - t[3])]);
    var ratio = liftKg / bodyweightKg;
    if (ratio >= bounds[bounds.length - 1]) return { tier: 6, division: null, progress: 1, kgToNext: null, ratio: ratio };
    var tier = 0;
    while (ratio >= bounds[tier + 1]) tier++;
    var lo = bounds[tier];
    var span = (bounds[tier + 1] - lo) / 3;
    var step = Math.min(2, Math.floor((ratio - lo) / span));
    var nextAt = lo + (step + 1) * span;
    return {
      tier: tier,
      division: 3 - step,
      progress: Math.max(0, Math.min(1, (ratio - (lo + step * span)) / span)),
      // Up to the next half kilo a plate setup can actually load.
      kgToNext: Math.max(0.5, Math.ceil((nextAt * bodyweightKg - liftKg) * 2) / 2),
      ratio: ratio
    };
  }

  function rankLabel(tier, division) {
    return TIERS[tier].name + (division ? ' ' + 'III'.slice(0, division) : '');
  }

  function nextRank(rank) {
    if (rank.division === null) return null;
    if (rank.division > 1) return rankLabel(rank.tier, rank.division - 1);
    return rankLabel(rank.tier + 1, rank.tier + 1 === 6 ? null : 3);
  }

  var RANK_TEXT = {
    de: { toNext: 'Noch {kg} kg bis {rank}', top: 'Höchster Rang erreicht', ratio: '{ratio} × Körpergewicht', enter: 'Gib Körpergewicht und Bestleistung ein.' },
    en: { toNext: '{kg} kg to {rank}', top: 'Top rank reached', ratio: '{ratio}× bodyweight', enter: 'Enter your bodyweight and best lift.' }
  };

  function initRank() {
    var card = $('[data-demo="rank"]');
    if (!card) return;
    var bw = $('[data-rank-bw]', card);
    var pr = $('[data-rank-pr]', card);
    var range = $('[data-rank-range]', card);
    var img = $('[data-rank-img]', card);
    var nameEl = $('[data-rank-name]', card);
    var bar = $('[data-rank-bar]', card);
    var nextEl = $('[data-rank-next]', card);
    var ratioEl = $('[data-rank-ratio]', card);
    var out = $('.rankcalc__out', card);
    var shownTier = null;

    function render() {
      var text = RANK_TEXT[lang()];
      var rank = rankLift(checked(card, 'rank-lift'), num(pr), num(bw), checked(card, 'rank-sex'));
      setRangeFill(range);
      if (!rank) {
        nameEl.textContent = '–';
        bar.style.width = '0%';
        nextEl.textContent = text.enter;
        ratioEl.textContent = '';
        return;
      }
      var tier = TIERS[rank.tier];
      if (shownTier !== rank.tier) {
        img.setAttribute('src', 'assets/img/ranks/' + tier.key + '.webp');
        if (shownTier !== null && !calm) {
          img.classList.remove('is-swapping');
          void img.offsetWidth;
          img.classList.add('is-swapping');
        }
        shownTier = rank.tier;
      }
      out.style.setProperty('--rank-glow', tier.glow);
      nameEl.textContent = rankLabel(rank.tier, rank.division);
      bar.style.width = (rank.progress * 100).toFixed(1) + '%';
      var next = nextRank(rank);
      nextEl.textContent = next ? fill(text.toNext, { kg: fmt(rank.kgToNext, 0, 1), rank: next }) : text.top;
      ratioEl.textContent = fill(text.ratio, { ratio: fmt(rank.ratio, 2, 2) });
    }

    range.addEventListener('input', function () { pr.value = range.value; render(); });
    pr.addEventListener('input', function () {
      var v = num(pr);
      if (isFinite(v)) range.value = Math.max(parseFloat(range.min), Math.min(parseFloat(range.max), v));
      render();
    });
    bw.addEventListener('input', render);
    $$('input[type="radio"]', card).forEach(function (r) { r.addEventListener('change', render); });
    renderers.push(render);
    render();
  }

  // =========================================================== plates

  var PLATES_KG = [25, 20, 15, 10, 5, 2.5, 1.25, 0.5];
  var STEP = 0.05;
  var MAX_PER_SIDE = 1000;

  function round2(v) { return Math.round(v * 100) / 100; }

  /**
   * plate_calculator.dart calculatePlates(): not greedy -- the fewest
   * plates that make the per-side load exactly (coin change), ties going
   * to the larger plates; else the heaviest load below it.
   */
  function calculatePlates(targetKg, barKg, available) {
    if (barKg < 0 || targetKg < barKg) return null;
    var perSideTarget = Math.min((targetKg - barKg) / 2, MAX_PER_SIDE);
    var goal = Math.floor(perSideTarget / STEP + 1e-6);
    var plates = available.filter(function (p, i, all) { return p > 0 && all.indexOf(p) === i; })
      .sort(function (a, b) { return b - a; });
    var steps = plates.map(function (p) { return Math.round(p / STEP); });
    var fewest = new Int32Array(goal + 1).fill(-1);
    var last = new Int32Array(goal + 1).fill(-1);
    fewest[0] = 0;
    for (var a = 1; a <= goal; a++) {
      for (var i = 0; i < steps.length; i++) {
        var rest = a - steps[i];
        if (rest < 0 || fewest[rest] < 0) continue;
        if (fewest[a] < 0 || fewest[rest] + 1 < fewest[a]) {
          fewest[a] = fewest[rest] + 1;
          last[a] = i;
        }
      }
    }
    var reached = goal;
    while (fewest[reached] < 0) reached--;
    var perSide = [];
    for (var b = reached; b > 0; b -= steps[last[b]]) perSide.push(plates[last[b]]);
    perSide.sort(function (x, y) { return y - x; });
    var achieved = round2(barKg + 2 * reached * STEP);
    return { perSide: perSide, achievedTotal: achieved, targetTotal: round2(targetKg), approximate: Math.abs(round2(targetKg) - achieved) > 0.001 };
  }

  // Competition colors; height and thickness by weight.
  var PLATE_LOOK = {
    25: { fill: '#d6332e', h: 196, w: 30, ink: '#fff' },
    20: { fill: '#2f6feb', h: 196, w: 26, ink: '#fff' },
    15: { fill: '#f2c230', h: 176, w: 22, ink: '#1a1a1a' },
    10: { fill: '#23a356', h: 156, w: 18, ink: '#fff' },
    5: { fill: '#f4f4f6', h: 122, w: 15, ink: '#1a1a1a' },
    2.5: { fill: '#d6332e', h: 98, w: 13, ink: '#fff' },
    1.25: { fill: '#b9bec6', h: 82, w: 11, ink: '#1a1a1a' },
    0.5: { fill: '#8a9099', h: 66, w: 9, ink: '#fff' }
  };
  var GAP = 2;
  var MID_Y = 110;
  var LEFT_COLLAR = 284;
  var RIGHT_COLLAR = 676;
  var SVG_NS = 'http://www.w3.org/2000/svg';

  var PLATE_TEXT = {
    de: {
      barOnly: 'Nur die Stange – keine Scheiben nötig.', nothing: 'Noch keine Scheiben – tipp unten welche an.',
      below: 'Das Ziel ist leichter als das Leergewicht.', approx: 'Genau {target} kg geht mit diesen Scheiben nicht – am nächsten dran: {value} kg.',
      none: 'Schalte mindestens eine Scheibe ein.', total: '= {kg} kg gesamt', sideTotal: '{side} kg pro Seite'
    },
    en: {
      barOnly: 'Just the bar – no plates needed.', nothing: 'No plates yet – tap some below.',
      below: 'The target is lighter than the empty weight.', approx: 'Exactly {target} kg isn’t possible with these plates – closest: {value} kg.',
      none: 'Switch on at least one plate.', total: '= {kg} kg total', sideTotal: '{side} kg per side'
    }
  };

  function initPlates() {
    var card = $('[data-demo="plates"]');
    if (!card) return;
    var left = $('[data-plates-left]', card);
    var right = $('[data-plates-right]', card);
    var list = $('[data-plates-list]', card);
    var total = $('[data-plates-total]', card);
    var msg = $('[data-plates-msg]', card);
    var range = $('[data-plates-range]', card);
    var input = $('[data-plates-input]', card);
    var avail = $('[data-plates-avail]', card);
    var pad = $('[data-plates-pad]', card);
    var targetUi = $('[data-plates-target-ui]', card);
    var tapUi = $('[data-plates-tap-ui]', card);
    var modeButtons = $$('[data-plates-mode]', card);
    var mode = 'target';
    var enabled = PLATES_KG.slice();
    var tapped = [];
    var drawn = [];
    var padLabels = [];

    PLATES_KG.forEach(function (w) {
      var b = document.createElement('button');
      b.type = 'button';
      b.setAttribute('aria-pressed', 'true');
      b.addEventListener('click', function () {
        var on = b.getAttribute('aria-pressed') !== 'true';
        b.setAttribute('aria-pressed', on ? 'true' : 'false');
        enabled = PLATES_KG.filter(function (p) {
          var btn = $$('button', avail)[PLATES_KG.indexOf(p)];
          return btn.getAttribute('aria-pressed') === 'true';
        });
        render();
      });
      avail.appendChild(b);

      var t = document.createElement('button');
      t.type = 'button';
      t.style.setProperty('--c', PLATE_LOOK[w].fill);
      t.innerHTML = '<i></i>';
      padLabels.push(t.appendChild(document.createTextNode('')));
      t.addEventListener('click', function () {
        if (tapped.length >= 14) return;
        tapped.push(w);
        render();
      });
      pad.appendChild(t);
    });
    $('[data-plates-undo]', card).addEventListener('click', function () { tapped.pop(); render(); });
    $('[data-plates-clear]', card).addEventListener('click', function () { tapped = []; render(); });

    function plateNode(weight, x, side) {
      var look = PLATE_LOOK[weight];
      var g = document.createElementNS(SVG_NS, 'g');
      var rect = document.createElementNS(SVG_NS, 'rect');
      rect.setAttribute('class', 'plate');
      rect.setAttribute('x', x);
      rect.setAttribute('y', MID_Y - look.h / 2);
      rect.setAttribute('width', look.w);
      rect.setAttribute('height', look.h);
      rect.setAttribute('rx', 4);
      rect.setAttribute('fill', look.fill);
      g.appendChild(rect);
      if (look.w >= 18) {
        var label = document.createElementNS(SVG_NS, 'text');
        label.setAttribute('class', 'plate-label');
        label.setAttribute('x', x + look.w / 2);
        label.setAttribute('y', MID_Y);
        label.setAttribute('fill', look.ink);
        label.setAttribute('transform', 'rotate(-90 ' + (x + look.w / 2) + ' ' + MID_Y + ')');
        label.textContent = fmt(weight);
        g.appendChild(label);
      }
      g.__w = weight;
      if (!calm && g.animate) {
        g.animate([{ transform: 'translateX(' + (side * 40) + 'px)', opacity: 0 }, { transform: 'none', opacity: 1 }],
          { duration: 320, easing: 'cubic-bezier(.2,.7,.2,1)' });
      }
      return g;
    }

    /** Keeps the plates that didn't change and slides in the new ones. */
    function draw(perSide) {
      var keep = 0;
      while (keep < drawn.length && keep < perSide.length && drawn[keep] === perSide[keep]) keep++;
      [left, right].forEach(function (group) {
        $$('g', group).slice(keep).forEach(function (g) { g.remove(); });
      });
      var xl = LEFT_COLLAR, xr = RIGHT_COLLAR + 14;
      perSide.slice(0, keep).forEach(function (w) { xl -= PLATE_LOOK[w].w + GAP; xr += PLATE_LOOK[w].w + GAP; });
      perSide.slice(keep).forEach(function (w) {
        var look = PLATE_LOOK[w];
        xl -= look.w + GAP;
        left.appendChild(plateNode(w, xl + GAP, -1));
        right.appendChild(plateNode(w, xr, 1));
        xr += look.w + GAP;
      });
      drawn = perSide.slice();
    }

    /** Plate labels use the page language's decimal comma or point. */
    function relabel() {
      $$('button', avail).forEach(function (b, i) { b.textContent = fmt(PLATES_KG[i]); });
      padLabels.forEach(function (node, i) { node.textContent = fmt(PLATES_KG[i]) + ' kg'; });
    }

    function render() {
      var text = PLATE_TEXT[lang()];
      var bar = parseFloat(checked(card, 'plates-bar')) || 0;
      relabel();
      setRangeFill(range);
      msg.textContent = '';
      if (mode === 'tap') {
        draw(tapped.slice());
        var side = tapped.reduce(function (s, w) { return s + w; }, 0);
        list.textContent = tapped.length ? tapped.map(function (w) { return fmt(w); }).join(' · ') : '–';
        total.textContent = fill(text.total, { kg: fmt(round2(bar + 2 * side)) });
        if (!tapped.length) msg.textContent = text.nothing;
        return;
      }
      var target = num(input);
      if (!enabled.length) {
        draw([]);
        list.textContent = '–';
        total.textContent = '';
        msg.textContent = text.none;
        return;
      }
      var result = isFinite(target) ? calculatePlates(target, bar, enabled) : null;
      if (!result) {
        draw([]);
        list.textContent = '–';
        total.textContent = '';
        msg.textContent = isFinite(target) ? text.below : '';
        return;
      }
      draw(result.perSide);
      list.textContent = result.perSide.length ? result.perSide.map(function (w) { return fmt(w); }).join(' · ') : '–';
      total.textContent = fill(text.total, { kg: fmt(result.achievedTotal) });
      if (!result.perSide.length && !result.approximate) msg.textContent = text.barOnly;
      if (result.approximate) msg.textContent = fill(text.approx, { target: fmt(result.targetTotal), value: fmt(result.achievedTotal) });
    }

    function setMode(next) {
      mode = next;
      modeButtons.forEach(function (b) { b.setAttribute('aria-pressed', b.getAttribute('data-plates-mode') === next ? 'true' : 'false'); });
      targetUi.hidden = next !== 'target';
      tapUi.hidden = next !== 'tap';
      render();
    }
    modeButtons.forEach(function (b) { b.addEventListener('click', function () { setMode(b.getAttribute('data-plates-mode')); }); });

    range.addEventListener('input', function () { input.value = range.value; render(); });
    input.addEventListener('input', function () {
      var v = num(input);
      if (isFinite(v)) range.value = Math.max(parseFloat(range.min), Math.min(parseFloat(range.max), v));
      render();
    });
    $$('input[name="plates-bar"]', card).forEach(function (r) { r.addEventListener('change', render); });
    renderers.push(render);
    render();
  }

  // =========================================================== next session

  var TOO_HEAVY_GAP = 3; // kTooHeavyRepGap
  var WEIGHT_STEP = 2.5; // _weightStep

  var PG_TEXT = {
    de: {
      up: 'Ziel geschafft ({reps} bei {weight}) — nächstes Mal {nextWeight}, Ziel wieder {range} Wdh.',
      hold: 'Bleib bei {weight}. Letztes Mal {reps}, Ziel {range} — versuch nächstes Mal {nextReps}.',
      down: 'Zweimal klar unter dem Ziel ({reps} bei {weight}, Ziel {range}) — mit {nextWeight} schaffst du den Bereich wieder.',
      set: 'Satz'
    },
    en: {
      up: 'Target hit ({reps} at {weight}) — next time {nextWeight}, again aiming for {range} reps.',
      hold: 'Stay at {weight}. Last time {reps}, target {range} — next time try {nextReps}.',
      down: 'Clearly below target twice ({reps} at {weight}, target {range}) — {nextWeight} gets you back into the range.',
      set: 'Set'
    }
  };

  /** suggestNextSession() for a reps exercise whose last two sessions match. */
  function suggest(reps, min, max, weight, legs, twice) {
    if (reps.every(function (r) { return r >= max; })) {
      return { kind: 'up', weight: weight + (legs ? 5 : 2.5) };
    }
    var tooHeavy = reps.every(function (r) { return r <= min - TOO_HEAVY_GAP; });
    if (twice && tooHeavy) {
      var best = Math.max.apply(null, reps);
      var oneRepMax = weight * (1 + best / 30);
      var next = Math.floor(oneRepMax / (1 + min / 30) / WEIGHT_STEP) * WEIGHT_STEP;
      if (next >= weight) next = weight - WEIGHT_STEP;
      if (next > 0) return { kind: 'down', weight: next };
    }
    return { kind: 'hold', weight: weight, nextReps: reps.map(function (r) { return r >= max ? r : r + 1; }) };
  }

  function initProgression() {
    var card = $('[data-progression]');
    if (!card) return;
    var weightEl = $('[data-pg-weight]', card);
    var targetEl = $('[data-pg-target]', card);
    var twiceEl = $('[data-pg-twice]', card);
    var setsHost = $('[data-pg-sets]', card);
    var out = $('[data-pg-out]', card);
    var icon = $('[data-pg-icon] use', card);
    var textEl = $('[data-pg-text]', card);
    var reps = [8, 7, 7];
    var outputs = [];

    reps.forEach(function (_, i) {
      var box = document.createElement('div');
      box.className = 'stepper';
      box.innerHTML = '<small></small><button type="button" data-d="-1"><svg aria-hidden="true"><use href="#i-minus"/></svg></button>' +
        '<output></output><button type="button" data-d="1"><svg aria-hidden="true"><use href="#i-plus"/></svg></button>';
      $$('button', box).forEach(function (b) {
        b.addEventListener('click', function () {
          reps[i] = Math.max(1, Math.min(30, reps[i] + parseInt(b.getAttribute('data-d'), 10)));
          render();
        });
      });
      setsHost.appendChild(box);
      outputs.push(box);
    });

    function render() {
      var text = PG_TEXT[lang()];
      var parts = targetEl.value.split('-');
      var min = parseInt(parts[0], 10), max = parseInt(parts[1], 10);
      // A non-breaking hyphen keeps '8-10' on one line.
      var range = min === max ? String(min) : min + '‑' + max;
      var weight = num(weightEl);
      outputs.forEach(function (box, i) {
        $('output', box).textContent = reps[i];
        $('small', box).textContent = text.set + ' ' + (i + 1);
        $$('button', box)[0].setAttribute('aria-label', text.set + ' ' + (i + 1) + ' −1');
        $$('button', box)[1].setAttribute('aria-label', text.set + ' ' + (i + 1) + ' +1');
      });
      if (!(weight > 0)) { textEl.textContent = '–'; return; }
      var s = suggest(reps, min, max, weight, checked(card, 'pg-ex') === 'legs', twiceEl.checked);
      var kg = function (v) { return fmt(v, 1, 1) + ' kg'; };
      out.setAttribute('data-kind', s.kind);
      icon.setAttribute('href', s.kind === 'up' ? '#i-trending-up' : s.kind === 'down' ? '#i-trending-down' : '#i-repeat');
      textEl.textContent = fill(text[s.kind], {
        reps: reps.join(' · '),
        weight: kg(weight),
        nextWeight: kg(s.weight),
        range: range,
        nextReps: s.nextReps ? s.nextReps.join(' · ') : ''
      });
    }

    [weightEl, targetEl, twiceEl].forEach(function (el) { el.addEventListener('input', render); el.addEventListener('change', render); });
    $$('input[name="pg-ex"]', card).forEach(function (r) { r.addEventListener('change', render); });
    renderers.push(render);
    render();
  }

  // =========================================================== muscle map

  // Values verbatim from exercise_muscle_map.dart.
  var EXERCISES = {
    bench_press: { chest: 100, frontDelts: 40, triceps: 40 },
    squats: { quads: 90, glutes: 60, lowerBack: 30, hamstrings: 20 },
    deadlift: { lowerBack: 90, hamstrings: 65, glutes: 70, traps: 45, forearms: 35, lats: 25 },
    pull_ups: { lats: 100, biceps: 50, upperBack: 35, rearDelts: 15 },
    overhead_press: { frontDelts: 90, sideDelts: 40, triceps: 40, traps: 25 },
    hip_thrust: { glutes: 100, hamstrings: 35, lowerBack: 15 },
    barbell_curl: { biceps: 100, forearms: 25 },
    plank: { abs: 80, obliques: 50 }
  };

  // MuscleGroup enum order (tie-break for the shares).
  var ORDER = ['chest', 'abs', 'obliques', 'frontDelts', 'sideDelts', 'biceps', 'forearms', 'quads', 'calves',
    'upperBack', 'lowerBack', 'lats', 'traps', 'rearDelts', 'triceps', 'glutes', 'hamstrings'];

  // Names from app_de.arb / app_en.arb (muscle*).
  var MUSCLES = {
    de: {
      chest: 'Brust', abs: 'Bauch', obliques: 'Seitliche Bauchmuskeln', frontDelts: 'Vordere Schulter',
      sideDelts: 'Seitliche Schulter', biceps: 'Bizeps', forearms: 'Unterarme', quads: 'Quadrizeps',
      calves: 'Waden', upperBack: 'Oberer Rücken', lowerBack: 'Unterer Rücken', lats: 'Latissimus',
      traps: 'Trapezmuskel', rearDelts: 'Hintere Schulter', triceps: 'Trizeps', glutes: 'Gesäß',
      hamstrings: 'Beinbeuger'
    },
    en: {
      chest: 'Chest', abs: 'Abs', obliques: 'Obliques', frontDelts: 'Front delts', sideDelts: 'Side delts',
      biceps: 'Biceps', forearms: 'Forearms', quads: 'Quads', calves: 'Calves', upperBack: 'Upper back',
      lowerBack: 'Lower back', lats: 'Lats', traps: 'Traps', rearDelts: 'Rear delts', triceps: 'Triceps',
      glutes: 'Glutes', hamstrings: 'Hamstrings'
    }
  };

  /** activationShares(): whole percent adding up to 100 (largest remainder). */
  function shares(activation) {
    var keys = Object.keys(activation).filter(function (m) { return activation[m] > 0; });
    var sum = keys.reduce(function (s, m) { return s + activation[m]; }, 0);
    var exact = {}, out = {}, left = 100;
    keys.forEach(function (m) { exact[m] = activation[m] * 100 / sum; out[m] = Math.floor(exact[m]); left -= out[m]; });
    keys.slice().sort(function (a, b) {
      var byRest = (exact[b] - out[b]) - (exact[a] - out[a]);
      if (byRest !== 0) return byRest;
      var byValue = activation[b] - activation[a];
      return byValue !== 0 ? byValue : ORDER.indexOf(a) - ORDER.indexOf(b);
    }).forEach(function (m) { if (left > 0) { out[m]++; left--; } });
    return out;
  }

  function hexToRgb(hex) {
    var n = parseInt(hex.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  function lerpColor(a, b, k) {
    var ca = hexToRgb(a), cb = hexToRgb(b);
    return 'rgb(' + ca.map(function (c, i) { return Math.round(c + (cb[i] - c) * k); }).join(',') + ')';
  }

  /** activationColor() from detailed_body_diagram.dart. */
  function activationColor(value) {
    var v = Math.min(1, Math.max(0, value / 100));
    if (v <= 0) return '#edeff2';
    if (v < 0.5) return lerpColor('#edeff2', '#ff8a80', v / 0.5);
    return lerpColor('#ff8a80', '#9a1212', (v - 0.5) / 0.5);
  }

  function buildBody(svg, view, prefix) {
    svg.setAttribute('viewBox', view.viewBox);
    var defs = document.createElementNS(SVG_NS, 'defs');
    var base = document.createElementNS(SVG_NS, 'g');
    var overlay = document.createElementNS(SVG_NS, 'g');
    var seen = {};
    var muscles = [];
    view.shapes.forEach(function (shape, i) {
      if (!seen[shape.d]) {
        seen[shape.d] = true;
        var silhouette = document.createElementNS(SVG_NS, 'path');
        silhouette.setAttribute('d', shape.d);
        silhouette.setAttribute('class', 'base');
        base.appendChild(silhouette);
      }
      if (!shape.m) return;
      var path = document.createElementNS(SVG_NS, 'path');
      path.setAttribute('d', shape.d);
      path.setAttribute('class', 'm');
      if (shape.clip) {
        var id = prefix + '-clip-' + i;
        var clip = document.createElementNS(SVG_NS, 'clipPath');
        clip.setAttribute('id', id);
        var rect = document.createElementNS(SVG_NS, 'rect');
        rect.setAttribute('x', shape.clip[0]);
        rect.setAttribute('y', shape.clip[1]);
        rect.setAttribute('width', shape.clip[2]);
        rect.setAttribute('height', shape.clip[3]);
        clip.appendChild(rect);
        defs.appendChild(clip);
        path.setAttribute('clip-path', 'url(#' + id + ')');
      }
      overlay.appendChild(path);
      muscles.push({ el: path, m: shape.m });
    });
    svg.appendChild(defs);
    svg.appendChild(base);
    svg.appendChild(overlay);
    return muscles;
  }

  function initMuscles() {
    var card = $('[data-demo="muscles"]');
    if (!card) return;
    var picks = $$('[data-muscle-picks] [data-ex]', card);
    var listEl = $('[data-muscle-list]', card);
    var current = 'bench_press';
    var shapes = null;

    function renderList() {
      var activation = EXERCISES[current];
      var names = MUSCLES[lang()];
      var share = shares(activation);
      listEl.innerHTML = '';
      Object.keys(activation)
        .sort(function (a, b) { return share[b] - share[a] || activation[b] - activation[a]; })
        .forEach(function (m) {
          var li = document.createElement('li');
          var label = document.createElement('span');
          label.textContent = names[m];
          var value = document.createElement('b');
          value.textContent = share[m] + ' %';
          if (lang() === 'en') value.textContent = share[m] + '%';
          var track = document.createElement('span');
          track.className = 'track';
          var bar = document.createElement('i');
          bar.style.width = share[m] + '%';
          bar.style.background = activationColor(activation[m]);
          track.appendChild(bar);
          li.appendChild(label);
          li.appendChild(value);
          li.appendChild(track);
          listEl.appendChild(li);
        });
    }

    function renderBodies() {
      if (!shapes) return;
      var activation = EXERCISES[current];
      shapes.forEach(function (s) { s.el.style.fill = activationColor(activation[s.m] || 0); });
    }

    function select(id) {
      current = id;
      picks.forEach(function (b) {
        var on = b.getAttribute('data-ex') === id;
        b.setAttribute('aria-checked', on ? 'true' : 'false');
        b.tabIndex = on ? 0 : -1;
      });
      renderList();
      renderBodies();
    }

    picks.forEach(function (button, index) {
      button.addEventListener('click', function () { select(button.getAttribute('data-ex')); });
      button.addEventListener('keydown', function (e) {
        var step = e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : e.key === 'ArrowLeft' || e.key === 'ArrowUp' ? -1 : 0;
        if (!step) return;
        e.preventDefault();
        var next = picks[(index + step + picks.length) % picks.length];
        next.focus();
        select(next.getAttribute('data-ex'));
      });
    });

    var started = false;
    function loadFigure() {
      if (started) return;
      started = true;
      var script = document.createElement('script');
      script.src = 'assets/js/body-atlas.js';
      script.onload = function () {
        var data = window.IronpeakBody;
        if (!data) return;
        shapes = buildBody($('[data-body="front"]', card), data.front, 'front')
          .concat(buildBody($('[data-body="back"]', card), data.back, 'back'));
        renderBodies();
      };
      document.head.appendChild(script);
    }

    if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (entries) {
        if (entries.some(function (e) { return e.isIntersecting; })) { io.disconnect(); loadFigure(); }
      }, { rootMargin: '900px 0px' });
      io.observe(card);
    } else {
      loadFigure();
    }

    select(current);
    renderers.push(renderList);
  }

  function init() {
    initRank();
    initPlates();
    initProgression();
    initMuscles();
    document.addEventListener('kilo:lang', function () { renderers.forEach(function (render) { render(); }); });
  }

  // Exposed for a quick check against the Dart tests from the console.
  window.KiloDemos = { rankLift: rankLift, calculatePlates: calculatePlates, suggest: suggest, shares: shares };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
