/*
 * The three live demos. Formulas and data are ported from the app, so the
 * page computes exactly what the app does:
 *   plate calculator  <- mobile/lib/data/plate_calculator.dart
 *   strength level    <- mobile/lib/data/strength_standards.dart
 *   muscle map        <- mobile/lib/data/exercise_muscle_map.dart (values),
 *                        mobile/lib/widgets/detailed_body_diagram.dart (colors),
 *                        assets/js/body-atlas.js (figure, lazy-loaded)
 */
(function () {
  'use strict';

  var root = document.documentElement;
  var reduceMotion = root.classList.contains('calm');

  function lang() {
    return root.lang === 'en' ? 'en' : 'de';
  }

  function fmt(value, digits) {
    return new Intl.NumberFormat(lang() === 'de' ? 'de-DE' : 'en-US', {
      maximumFractionDigits: digits === undefined ? 2 : digits
    }).format(value);
  }

  var TEXT = {
    de: {
      barAlone: 'Nur die Stange – keine Scheiben nötig.',
      belowBar: 'Zielgewicht ist leichter als die Stange selbst.',
      approx: 'Nächstmöglich: {value} kg – das Ziel ist mit Standardscheiben nicht exakt erreichbar.',
      none: '–',
      toNext: '{percent}% bis {level}',
      top: 'Höchstes Level erreicht',
      ratio: '{ratio} × Körpergewicht',
      enter: 'Gib Körpergewicht und Bestleistung ein.',
      levels: ['Anfänger', 'Geübt', 'Fortgeschritten', 'Sehr fortgeschritten', 'Elite']
    },
    en: {
      barAlone: 'Just the bar – no plates needed.',
      belowBar: 'Target is lighter than the bar itself.',
      approx: 'Closest possible: {value} kg – the target isn’t exactly loadable with standard plates.',
      none: '–',
      toNext: '{percent}% to {level}',
      top: 'Top level reached',
      ratio: '{ratio}× bodyweight',
      enter: 'Enter your bodyweight and best lift.',
      levels: ['Beginner', 'Novice', 'Intermediate', 'Advanced', 'Elite']
    }
  };

  function t(key, vars) {
    var s = TEXT[lang()][key];
    if (vars) {
      Object.keys(vars).forEach(function (k) {
        s = s.replace('{' + k + '}', vars[k]);
      });
    }
    return s;
  }

  function num(input) {
    var v = input.valueAsNumber;
    if (isNaN(v)) v = parseFloat(String(input.value).replace(',', '.'));
    return v;
  }

  function checkedValue(name) {
    var el = document.querySelector('input[name="' + name + '"]:checked');
    return el ? el.value : null;
  }

  var renderers = [];

  // ===================================================== plate calculator

  var PLATES_KG = [25, 20, 15, 10, 5, 2.5, 1.25, 0.5];

  function round2(v) {
    return Math.round(v * 100) / 100;
  }

  /** calculatePlates() from plate_calculator.dart: greedy is exact here. */
  function calculatePlates(targetKg, barKg) {
    if (barKg <= 0 || targetKg < barKg) return null;
    var remaining = (targetKg - barKg) / 2;
    var perSide = [];
    PLATES_KG.forEach(function (plate) {
      while (remaining + 1e-9 >= plate) {
        perSide.push(plate);
        remaining -= plate;
      }
    });
    var achieved = round2(targetKg - remaining * 2);
    var target = round2(targetKg);
    return {
      perSide: perSide,
      achieved: achieved,
      target: target,
      approximate: Math.abs(target - achieved) > 0.001
    };
  }

  // Competition plate colors; 25-10 kg share the full diameter like real
  // bumper plates, the change plates get smaller.
  var PLATE_LOOK = {
    25: { h: 204, w: 30, fill: '#d8433c' },
    20: { h: 204, w: 26, fill: '#2f6feb' },
    15: { h: 180, w: 22, fill: '#f0b429' },
    10: { h: 156, w: 19, fill: '#1fa76a' },
    5: { h: 118, w: 15, fill: '#eef2f0' },
    2.5: { h: 96, w: 12, fill: '#c23a33' },
    1.25: { h: 80, w: 10, fill: '#b9c3c0' },
    0.5: { h: 64, w: 8, fill: '#dfe6e2' }
  };
  var PLATE_GAP = 2;
  var BAR_Y = 120;
  var LEFT_COLLAR = 280;
  var RIGHT_COLLAR = 680;

  function initPlates() {
    var card = document.querySelector('[data-demo="plates"]');
    if (!card) return;
    var range = card.querySelector('[data-plates-range]');
    var input = card.querySelector('[data-plates-input]');
    var leftGroup = card.querySelector('[data-plates-left]');
    var rightGroup = card.querySelector('[data-plates-right]');
    var list = card.querySelector('[data-plates-list]');
    var total = card.querySelector('[data-plates-total]');
    var out = card.querySelector('[data-plates-out]');
    var hint = document.createElement('span');
    hint.className = 'plates__hint';
    out.appendChild(hint);

    var drawn = []; // [{ w, left, right, offset }]

    function setFill() {
      var min = parseFloat(range.min);
      var max = parseFloat(range.max);
      var pct = ((parseFloat(range.value) - min) / (max - min)) * 100;
      range.style.setProperty('--fill', Math.max(0, Math.min(100, pct)) + '%');
    }

    function plateRect(weight, x, group) {
      var look = PLATE_LOOK[weight];
      var rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
      rect.setAttribute('class', 'plate');
      rect.setAttribute('x', x);
      rect.setAttribute('y', BAR_Y - look.h / 2);
      rect.setAttribute('width', look.w);
      rect.setAttribute('height', look.h);
      rect.setAttribute('rx', Math.min(5, look.w / 3));
      rect.setAttribute('fill', look.fill);
      group.appendChild(rect);
      return rect;
    }

    function animateIn(el, dx, delay) {
      if (window.gsap && !reduceMotion) {
        window.gsap.from(el, { x: dx, opacity: 0, duration: 0.55, delay: delay, ease: 'back.out(1.8)' });
      }
    }

    function remove(el, dx) {
      if (window.gsap && !reduceMotion) {
        window.gsap.to(el, {
          x: dx,
          opacity: 0,
          duration: 0.22,
          ease: 'power2.in',
          onComplete: function () { el.remove(); }
        });
      } else {
        el.remove();
      }
    }

    function draw(perSide) {
      var keep = 0;
      while (keep < drawn.length && keep < perSide.length && drawn[keep].w === perSide[keep]) keep++;
      drawn.slice(keep).forEach(function (p) {
        remove(p.left, -40);
        remove(p.right, 40);
      });
      drawn = drawn.slice(0, keep);
      var offset = keep ? drawn[keep - 1].offset + PLATE_LOOK[drawn[keep - 1].w].w + PLATE_GAP : 0;
      perSide.slice(keep).forEach(function (w, i) {
        var look = PLATE_LOOK[w];
        var left = plateRect(w, LEFT_COLLAR - offset - look.w, leftGroup);
        var right = plateRect(w, RIGHT_COLLAR + offset, rightGroup);
        animateIn(left, -60, i * 0.045);
        animateIn(right, 60, i * 0.045);
        drawn.push({ w: w, left: left, right: right, offset: offset });
        offset += look.w + PLATE_GAP;
      });
    }

    function render() {
      var target = num(input);
      var bar = parseFloat(checkedValue('plates-bar') || '20');
      hint.textContent = '';
      if (isNaN(target)) {
        list.textContent = t('none');
        total.textContent = '';
        draw([]);
        return;
      }
      var result = calculatePlates(target, bar);
      if (!result) {
        list.textContent = t('none');
        total.textContent = '';
        hint.textContent = t('belowBar');
        draw([]);
        return;
      }
      draw(result.perSide);
      if (!result.perSide.length) {
        list.textContent = t('none');
        hint.textContent = t('barAlone');
      } else {
        list.textContent = result.perSide.map(function (w) { return fmt(w); }).join(' · ');
      }
      total.textContent = '= ' + fmt(result.achieved) + ' kg';
      if (result.approximate) hint.textContent = t('approx', { value: fmt(result.achieved) });
    }

    range.addEventListener('input', function () {
      input.value = range.value;
      setFill();
      render();
    });
    input.addEventListener('input', function () {
      var v = num(input);
      if (!isNaN(v)) {
        range.value = String(Math.max(parseFloat(range.min), Math.min(parseFloat(range.max), v)));
        setFill();
      }
      render();
    });
    Array.prototype.forEach.call(card.querySelectorAll('input[name="plates-bar"]'), function (radio) {
      radio.addEventListener('change', render);
    });

    setFill();
    render();
    renderers.push(render);
  }

  // ======================================================= strength level

  // _kMaleThresholds / _kFemaleThresholds: PR ÷ bodyweight per level.
  var THRESHOLDS = {
    m: {
      bench: [0.5, 0.75, 1.0, 1.5, 2.0],
      squat: [0.5, 0.75, 1.25, 1.75, 2.25],
      deadlift: [0.75, 1.0, 1.5, 2.0, 2.5]
    },
    f: {
      bench: [0.25, 0.35, 0.5, 0.75, 1.15],
      squat: [0.35, 0.5, 0.75, 1.25, 1.75],
      deadlift: [0.5, 0.75, 1.0, 1.5, 2.0]
    }
  };

  /** classifyLift() from strength_standards.dart. */
  function classifyLift(liftKey, liftKg, bodyweightKg, sex) {
    if (!(liftKg > 0) || !(bodyweightKg > 0)) return null;
    var thresholds = THRESHOLDS[sex][liftKey];
    if (!thresholds) return null;
    var ratio = liftKg / bodyweightKg;
    var level = 0;
    for (var i = 0; i < thresholds.length; i++) {
      if (ratio >= thresholds[i]) level = i;
    }
    var elite = level === thresholds.length - 1;
    var progress = elite
      ? 1
      : Math.min(1, Math.max(0, (ratio - thresholds[level]) / (thresholds[level + 1] - thresholds[level])));
    return { ratio: ratio, level: level, next: elite ? null : level + 1, progress: progress };
  }

  function initStrength() {
    var card = document.querySelector('[data-demo="strength"]');
    if (!card) return;
    var bw = card.querySelector('[data-strength-bw]');
    var pr = card.querySelector('[data-strength-pr]');
    var name = card.querySelector('[data-level-name]');
    var bar = card.querySelector('[data-level-bar]');
    var meta = card.querySelector('[data-level-meta]');
    var steps = card.querySelectorAll('[data-level-steps] li');

    function render() {
      var result = classifyLift(checkedValue('strength-lift'), num(pr), num(bw), checkedValue('strength-sex'));
      if (!result) {
        name.textContent = t('none');
        bar.style.width = '0%';
        meta.textContent = t('enter');
        Array.prototype.forEach.call(steps, function (li) { li.className = ''; });
        return;
      }
      var levels = TEXT[lang()].levels;
      name.textContent = levels[result.level];
      bar.style.width = (result.next === null ? 100 : Math.round(result.progress * 100)) + '%';
      var ratio = t('ratio', { ratio: fmt(result.ratio) });
      meta.textContent = (result.next === null
        ? t('top')
        : t('toNext', { percent: Math.round(result.progress * 100), level: levels[result.next] })) + ' · ' + ratio;
      Array.prototype.forEach.call(steps, function (li, i) {
        li.className = i < result.level ? 'is-done' : i === result.level ? 'is-on' : '';
      });
    }

    [bw, pr].forEach(function (input) { input.addEventListener('input', render); });
    Array.prototype.forEach.call(card.querySelectorAll('input[name="strength-lift"], input[name="strength-sex"]'), function (radio) {
      radio.addEventListener('change', render);
    });
    render();
    renderers.push(render);
  }

  // =========================================================== muscle map

  // Values verbatim from exercise_muscle_map.dart (_byId).
  var EXERCISES = {
    bench_press: { chest: 100, frontDelts: 40, triceps: 40 },
    squats: { quads: 90, glutes: 60, lowerBack: 30, hamstrings: 20 },
    deadlift: { lowerBack: 90, glutes: 70, hamstrings: 65, traps: 45, forearms: 35, lats: 25 },
    pull_ups: { lats: 100, biceps: 50, upperBack: 35, rearDelts: 15 },
    overhead_press: { frontDelts: 90, sideDelts: 40, triceps: 40, traps: 25 },
    hip_thrust: { glutes: 100, hamstrings: 35, lowerBack: 15 },
    barbell_curl: { biceps: 100, forearms: 25 },
    plank: { abs: 80, obliques: 50 }
  };

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

  function hexToRgb(hex) {
    var n = parseInt(hex.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  function lerpColor(a, b, k) {
    var ca = hexToRgb(a);
    var cb = hexToRgb(b);
    return 'rgb(' + ca.map(function (c, i) { return Math.round(c + (cb[i] - c) * k); }).join(',') + ')';
  }

  /** activationColor() from detailed_body_diagram.dart. */
  function activationColor(value) {
    var v = Math.min(1, Math.max(0, value / 100));
    if (v <= 0) return '#edeff2';
    if (v < 0.5) return lerpColor('#edeff2', '#ff8a80', v / 0.5);
    return lerpColor('#ff8a80', '#9a1212', (v - 0.5) / 0.5);
  }

  var SVG_NS = 'http://www.w3.org/2000/svg';

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
    var card = document.querySelector('[data-demo="muscles"]');
    if (!card) return;
    var picks = card.querySelectorAll('[data-muscle-picks] [data-ex]');
    var listEl = card.querySelector('[data-muscle-list]');
    var current = 'bench_press';
    var shapes = null;

    function renderList() {
      var activation = EXERCISES[current];
      var names = MUSCLES[lang()];
      listEl.innerHTML = '';
      Object.keys(activation)
        .sort(function (a, b) { return activation[b] - activation[a]; })
        .forEach(function (m) {
          var li = document.createElement('li');
          var dot = document.createElement('i');
          dot.style.background = activationColor(activation[m]);
          var label = document.createElement('span');
          label.textContent = names[m] + ' · ';
          var value = document.createElement('b');
          value.textContent = activation[m] + '%';
          li.appendChild(dot);
          li.appendChild(label);
          li.appendChild(value);
          listEl.appendChild(li);
        });
    }

    function renderBodies() {
      if (!shapes) return;
      var activation = EXERCISES[current];
      shapes.forEach(function (s) {
        s.el.style.fill = activationColor(activation[s.m] || 0);
      });
    }

    function select(id) {
      current = id;
      Array.prototype.forEach.call(picks, function (b) {
        var on = b.getAttribute('data-ex') === id;
        b.setAttribute('aria-checked', on ? 'true' : 'false');
        b.tabIndex = on ? 0 : -1;
      });
      renderList();
      renderBodies();
    }

    Array.prototype.forEach.call(picks, function (button, index) {
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

    function loadFigure() {
      if (shapes || loadFigure.started) return;
      loadFigure.started = true;
      var script = document.createElement('script');
      script.src = 'assets/js/body-atlas.js';
      script.onload = function () {
        var data = window.IronpeakBody;
        if (!data) return;
        shapes = buildBody(card.querySelector('[data-body="front"]'), data.front, 'front')
          .concat(buildBody(card.querySelector('[data-body="back"]'), data.back, 'back'));
        renderBodies();
      };
      document.head.appendChild(script);
    }

    if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (entries) {
        if (entries.some(function (e) { return e.isIntersecting; })) {
          io.disconnect();
          loadFigure();
        }
      }, { rootMargin: '900px 0px' });
      io.observe(card);
    } else {
      loadFigure();
    }

    select(current);
    renderers.push(renderList);
  }

  function init() {
    initPlates();
    initStrength();
    initMuscles();
    document.addEventListener('ironpeak:lang', function () {
      renderers.forEach(function (render) { render(); });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
