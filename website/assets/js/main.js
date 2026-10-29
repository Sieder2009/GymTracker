/*
 * The page's behavior: language and theme switches, nav, the launch
 * animation, scroll reveals, the app tour, the live training calendar,
 * streak flame and creatine tracker, the app-icon grid, and the release
 * lookup. No libraries; everything degrades to a readable page without it.
 */
(function () {
  'use strict';

  var root = document.documentElement;
  var calm = root.classList.contains('calm');

  function $(selector, scope) { return (scope || document).querySelector(selector); }
  function $$(selector, scope) { return Array.prototype.slice.call((scope || document).querySelectorAll(selector)); }
  function lang() { return root.lang === 'en' ? 'en' : 'de'; }
  function locale() { return lang() === 'de' ? 'de-DE' : 'en-US'; }
  function store(key, value) { try { window.localStorage.setItem(key, value); } catch (e) {} }

  var META = {
    de: {
      title: 'Kilo – Trainingsplaner, Krafttracker & Ränge, 100 % lokal',
      description: 'Kilo plant dein Training, merkt sich jeden Satz und zeigt dir mit Rängen von Mortal bis Olympian, wie stark du wirklich bist. Kostenlos für Android, iOS, Windows und macOS – ohne Konto, ohne Cloud.'
    },
    en: {
      title: 'Kilo – workout planner, strength tracker & ranks, 100% local',
      description: 'Kilo plans your training, remembers every set and shows you with ranks from Mortal to Olympian how strong you really are. Free for Android, iOS, Windows and macOS – no account, no cloud.'
    }
  };

  // ========================================================== language

  function applyLang(next, persist) {
    root.lang = next;
    $$('[data-i18n]').forEach(function (el) {
      Array.prototype.slice.call(el.attributes).forEach(function (attr) {
        var prefix = 'data-' + next + '-';
        if (attr.name.indexOf(prefix) === 0) el.setAttribute(attr.name.slice(prefix.length), attr.value);
      });
    });
    $$('[data-set-lang]').forEach(function (button) {
      button.setAttribute('aria-pressed', button.getAttribute('data-set-lang') === next ? 'true' : 'false');
    });
    document.title = META[next].title;
    var description = $('meta[name="description"]');
    if (description) description.setAttribute('content', META[next].description);
    if (persist) store('kilo-lang', next);
    document.dispatchEvent(new CustomEvent('kilo:lang'));
  }

  function initLanguage() {
    applyLang(lang(), false);
    $$('[data-set-lang]').forEach(function (button) {
      button.addEventListener('click', function () { applyLang(button.getAttribute('data-set-lang'), true); });
    });
  }

  // ========================================================== theme

  var systemDark = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  function theme() {
    var chosen = root.getAttribute('data-theme');
    if (chosen === 'light' || chosen === 'dark') return chosen;
    return systemDark && systemDark.matches ? 'dark' : 'light';
  }

  /** Points every <picture>'s dark source at the theme actually shown. */
  function syncPictures() {
    var chosen = root.getAttribute('data-theme');
    var media = chosen === 'dark' ? 'all' : chosen === 'light' ? 'not all' : '(prefers-color-scheme: dark)';
    $$('source[data-dark-source]').forEach(function (source) { source.setAttribute('media', media); });
  }

  function initTheme() {
    syncPictures();
    var toggle = $('[data-theme-toggle]');
    if (toggle) {
      toggle.addEventListener('click', function () {
        var next = theme() === 'dark' ? 'light' : 'dark';
        root.setAttribute('data-theme', next);
        store('kilo-theme', next);
        syncPictures();
        document.dispatchEvent(new CustomEvent('kilo:theme'));
      });
    }
    if (systemDark && systemDark.addEventListener) {
      systemDark.addEventListener('change', function () {
        if (!root.getAttribute('data-theme')) document.dispatchEvent(new CustomEvent('kilo:theme'));
      });
    }
  }

  // ========================================================== nav

  function initNav() {
    var nav = $('[data-nav]');
    var menu = $('[data-menu]');
    var links = $('#nav-links');
    function onScroll() { nav.classList.toggle('is-scrolled', window.scrollY > 8); }
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });

    function close() {
      menu.setAttribute('aria-expanded', 'false');
      links.classList.remove('is-open');
    }
    menu.addEventListener('click', function () {
      var open = menu.getAttribute('aria-expanded') !== 'true';
      menu.setAttribute('aria-expanded', open ? 'true' : 'false');
      links.classList.toggle('is-open', open);
    });
    $$('a', links).forEach(function (a) { a.addEventListener('click', close); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });

    if (!('IntersectionObserver' in window)) return;
    var map = {};
    $$('a[href^="#"]', links).forEach(function (a) { map[a.getAttribute('href').slice(1)] = a; });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        var a = map[entry.target.id];
        if (a) a.classList.toggle('is-active', entry.isIntersecting);
      });
    }, { rootMargin: '-45% 0px -50% 0px' });
    Object.keys(map).forEach(function (id) {
      var section = document.getElementById(id);
      if (section) io.observe(section);
    });
  }

  // ========================================================== platform

  var PLATFORM_NAMES = { android: 'Android', ios: 'iOS', windows: 'Windows', macos: 'macOS' };

  function detectPlatform() {
    var ua = navigator.userAgent || '';
    var platform = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';
    if (/android/i.test(ua)) return 'android';
    if (/iphone|ipad|ipod/i.test(ua) || (/mac/i.test(platform) && navigator.maxTouchPoints > 1)) return 'ios';
    if (/win/i.test(platform) || /windows/i.test(ua)) return 'windows';
    if (/mac/i.test(platform) || /mac os x/i.test(ua)) return 'macos';
    return null;
  }

  function initPlatform() {
    var mine = detectPlatform();
    if (!mine) return;
    var card = $('.platform[data-platform="' + mine + '"]');
    if (card) {
      card.classList.add('is-mine');
      card.parentNode.insertBefore(card, card.parentNode.firstElementChild);
    }
    // Most iPhones can't install the unsigned IPA, so iOS keeps the plain
    // button; its card (moved up) explains the catch.
    if (mine === 'ios') return;
    var de = $('[data-cta-de]');
    var en = $('[data-cta-en]');
    if (de) de.textContent = 'Für ' + PLATFORM_NAMES[mine] + ' laden';
    if (en) en.textContent = 'Download for ' + PLATFORM_NAMES[mine];
  }

  // ========================================================== releases

  var release = null;

  function renderRelease() {
    if (!release) return;
    $$('[data-release-version]').forEach(function (el) { el.textContent = release.tag; });
    if (release.date) {
      var formatted = new Intl.DateTimeFormat(locale(), { day: 'numeric', month: 'long', year: 'numeric' }).format(release.date);
      $$('[data-release-date]').forEach(function (el) { el.textContent = formatted; });
    }
    var mb = new Intl.NumberFormat(locale(), { maximumFractionDigits: 1 });
    $$('[data-asset-size]').forEach(function (el) {
      var asset = release.assets.filter(function (a) { return a.name === el.getAttribute('data-asset-size'); })[0];
      el.textContent = asset ? mb.format(asset.size / 1048576) + ' MB' : '';
    });
    $$('[data-release-chip], [data-release-line]').forEach(function (el) { el.hidden = false; });
  }

  function initRelease() {
    if (!window.fetch) return;
    fetch('https://api.github.com/repos/Sieder2009/GymTracker/releases/latest', { headers: { Accept: 'application/vnd.github+json' } })
      .then(function (response) {
        if (!response.ok) throw new Error(response.status);
        return response.json();
      })
      .then(function (json) {
        if (!json || !json.tag_name) return;
        release = {
          tag: json.tag_name,
          date: json.published_at ? new Date(json.published_at) : null,
          assets: (json.assets || []).map(function (a) { return { name: a.name, size: a.size }; })
        };
        renderRelease();
      })
      .catch(function () { /* offline or rate-limited: the page works without it */ });
    document.addEventListener('kilo:lang', renderRelease);
  }

  // ========================================================== logos

  function initLogos() {
    var mark = window.KiloMark;
    if (!mark) return;
    $$('[data-logo]').forEach(function (host) {
      var kind = host.getAttribute('data-logo');
      if (kind === 'launch') {
        if (!root.classList.contains('intro-on')) return;
        mark.mount(host, { motion: 'intro' });
        try { window.sessionStorage.setItem('kilo-intro', '1'); } catch (e) {}
        window.setTimeout(function () {
          var launch = host.parentNode;
          if (launch && launch.parentNode) launch.parentNode.removeChild(launch);
        }, 1700);
      } else if (kind === 'hover') {
        mark.mount(host, { motion: 'hover', trigger: host.closest('a') || host });
      } else if (kind === 'loop') {
        mark.mount(host, { motion: 'loop' });
      } else {
        mark.mount(host, { motion: 'none' });
      }
    });
  }

  // ========================================================== reveals & counters

  function initReveals() {
    var items = $$('[data-reveal]');
    if (calm || !('IntersectionObserver' in window)) {
      items.forEach(function (el) { el.classList.add('is-in'); });
      return;
    }
    // Siblings that come in together are staggered a little.
    items.forEach(function (el) {
      var siblings = $$(':scope > [data-reveal]', el.parentNode);
      var index = siblings.indexOf(el);
      if (index > 0) el.style.setProperty('--d', Math.min(index, 6) * 0.06 + 's');
    });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-in');
        io.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    items.forEach(function (el) { io.observe(el); });

    var others = $$('.look__icons');
    others.forEach(function (el) { io.observe(el); });
  }

  function initCounters() {
    var counters = $$('[data-count]');
    if (calm || !('IntersectionObserver' in window)) return;
    var nf = function () { return new Intl.NumberFormat(locale()); };
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        io.unobserve(entry.target);
        var el = entry.target;
        var target = parseInt(el.textContent.replace(/\D/g, ''), 10) || 0;
        if (target < 2) return;
        var start = null;
        var format = nf();
        function frame(now) {
          if (start === null) start = now;
          var k = Math.min(1, (now - start) / 1300);
          var eased = 1 - Math.pow(1 - k, 3);
          el.textContent = format.format(Math.round(target * eased));
          if (k < 1) requestAnimationFrame(frame);
        }
        requestAnimationFrame(frame);
      });
    }, { threshold: 0.6 });
    counters.forEach(function (el) { io.observe(el); });
  }

  // ========================================================== tour

  var TABS = {
    training: ['training', 'calendar'],
    strength: ['strength', 'prs', 'lift'],
    exercises: ['exercises', 'exercise']
  };
  var SHOT_ALT = {
    training: { de: 'Startbildschirm: Trainingskalender, Kreatin-Tracker und der Plan für Samstag', en: "Home screen: training calendar, creatine tracker and Saturday's plan" },
    calendar: { de: 'Trainingskalender: 129 Workouts im letzten Jahr, aktuelle und beste Serie', en: 'Training calendar: 129 workouts in the last year, current and best streak' },
    strength: { de: 'Kraft-Tab: Gesamtrang Demigod III mit Kristallabzeichen und Körpergewicht', en: 'Strength tab: overall rank Demigod III with its crystal badge, and bodyweight' },
    prs: { de: 'Kraft-Tab: Bankdrücken, Kreuzheben und Kniebeuge mit Rängen und PR-Radar', en: 'Strength tab: bench press, deadlift and squat with ranks and a PR radar' },
    lift: { de: 'Kreuzheben: Rang Demigod II, noch 8 kg bis Demigod I, Verlauf über drei Monate', en: 'Deadlift: rank Demigod II, 8 kg to Demigod I, three months of history' },
    exercises: { de: 'Übungen-Tab: 546 Übungen mit Muskeldiagramm, nach Kategorie filterbar', en: 'Exercises tab: 546 exercises with muscle diagrams, filterable by category' },
    exercise: { de: 'Bankdrücken: Muskelaktivierung vorne – Brust 56 %, vordere Schulter und Trizeps je 22 %', en: 'Bench press: muscle activation, front – chest 56%, front delts and triceps 22% each' }
  };

  function initTour() {
    var tour = $('[data-tour]');
    if (!tour) return;
    var tabs = $$('[role="tab"]', tour);
    var panels = $$('[data-panel]', tour);
    var picture = $('[data-tour-picture]', tour);
    var img = $('[data-tour-img]', tour);
    var source = $('source', picture);
    var current = 'training';

    function setShot(shot, animate) {
      current = shot;
      $$('.thumb', tour).forEach(function (t) {
        t.setAttribute('aria-pressed', t.getAttribute('data-shot') === shot ? 'true' : 'false');
      });
      var light = 'assets/img/screens/' + shot + '-light-780.webp';
      var dark = 'assets/img/screens/' + shot + '-dark-780.webp';
      var apply = function () {
        source.setAttribute('srcset', dark);
        img.setAttribute('src', light);
        img.setAttribute('alt', SHOT_ALT[shot][lang()]);
      };
      if (!animate || calm) { apply(); return; }
      img.classList.add('is-swapping');
      window.setTimeout(function () {
        apply();
        var done = function () { img.classList.remove('is-swapping'); };
        if (img.complete) requestAnimationFrame(done); else img.addEventListener('load', done, { once: true });
      }, 180);
    }

    function select(name, focus) {
      tabs.forEach(function (tab) {
        var on = tab.getAttribute('data-tab') === name;
        tab.setAttribute('aria-selected', on ? 'true' : 'false');
        tab.tabIndex = on ? 0 : -1;
        if (on && focus) tab.focus();
      });
      panels.forEach(function (panel) { panel.classList.toggle('is-active', panel.getAttribute('data-panel') === name); });
      setShot(TABS[name][0], true);
    }

    tabs.forEach(function (tab, i) {
      tab.addEventListener('click', function () { select(tab.getAttribute('data-tab')); });
      tab.addEventListener('keydown', function (e) {
        var step = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
        if (!step) return;
        e.preventDefault();
        select(tabs[(i + step + tabs.length) % tabs.length].getAttribute('data-tab'), true);
      });
    });
    $$('.thumb', tour).forEach(function (thumb) {
      thumb.addEventListener('click', function () { setShot(thumb.getAttribute('data-shot'), true); });
    });
    panels[0].classList.add('is-active');
    setShot('training', false);
    document.addEventListener('kilo:lang', function () { img.setAttribute('alt', SHOT_ALT[current][lang()]); });
  }

  // ========================================================== training calendar

  // A seeded generator, so the demo calendar looks the same on every visit.
  function rng(seed) {
    return function () {
      seed |= 0; seed = seed + 0x6d2b79f5 | 0;
      var t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  function dayKey(d) { return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate(); }

  /**
   * A year of plausible training: a six-day split with Thursday off (like
   * the app's demo plan), a lighter week now and then, two short breaks,
   * and volume that grows over time. Levels 0..4 like the app's heatmap.
   */
  function demoYear(weeks) {
    var rand = rng(42);
    var today = new Date();
    today.setHours(0, 0, 0, 0);
    var monday = new Date(today);
    monday.setDate(today.getDate() - ((today.getDay() + 6) % 7));
    var start = new Date(monday);
    start.setDate(monday.getDate() - (weeks - 1) * 7);
    var days = [];
    var breaks = [Math.floor(weeks * 0.3), Math.floor(weeks * 0.62)];
    for (var w = 0; w < weeks; w++) {
      var easy = rand() < 0.18;
      var off = breaks.indexOf(w) >= 0;
      for (var r = 0; r < 7; r++) {
        var d = new Date(start);
        d.setDate(start.getDate() + w * 7 + r);
        var future = d > today;
        var level = 0;
        if (!future && !off && r !== 3) {
          var skip = rand() < (easy ? 0.45 : 0.12);
          if (!skip) {
            var base = 1 + (w / weeks) * 1.6 + rand() * 1.8 + (r === 0 || r === 2 ? 0.6 : 0) - (easy ? 0.8 : 0);
            level = Math.max(1, Math.min(4, Math.round(base)));
          }
        }
        days.push({ date: d, week: w, row: r, level: level, future: future, rest: r === 3, today: d.getTime() === today.getTime() });
      }
    }
    return days;
  }

  /** Longest run of training days; planned rest days don't break it. */
  function bestStreak(days) {
    var best = 0, run = 0;
    days.forEach(function (day) {
      if (day.future) return;
      if (day.level > 0) { run++; best = Math.max(best, run); }
      else if (!day.rest && !day.today) run = 0;
    });
    return best;
  }

  var SVG_NS = 'http://www.w3.org/2000/svg';
  function svgEl(name, attrs) {
    var el = document.createElementNS(SVG_NS, name);
    Object.keys(attrs).forEach(function (k) { el.setAttribute(k, attrs[k]); });
    return el;
  }

  function initHeatmap() {
    var host = $('[data-heatmap]');
    if (!host) return;
    var card = host.closest('.card');
    var tip = $('[data-hm-tip]', card);
    var weeks = 53;
    var days = demoYear(weeks);
    var cell = 11, gap = 3, left = 28, top = 16;
    var width = left + weeks * (cell + gap);
    var height = top + 7 * (cell + gap);
    var svg = svgEl('svg', { viewBox: '0 0 ' + width + ' ' + height, 'aria-hidden': 'true' });
    var labels = svgEl('g', {});
    var cells = svgEl('g', {});
    svg.appendChild(labels);
    svg.appendChild(cells);

    days.forEach(function (day, i) {
      if (day.future) return;
      var rect = svgEl('rect', {
        class: 'c l0' + (day.today ? ' today' : ''),
        x: left + day.week * (cell + gap), y: top + day.row * (cell + gap), width: cell, height: cell
      });
      rect.__day = day;
      rect.__level = day.level;
      cells.appendChild(rect);
    });
    host.appendChild(svg);
    // On a narrow screen the calendar scrolls; start at today, like the app.
    host.scrollLeft = host.scrollWidth;

    function renderLabels() {
      while (labels.firstChild) labels.removeChild(labels.firstChild);
      var month = new Intl.DateTimeFormat(locale(), { month: 'short' });
      var lastMonth = -1;
      for (var w = 0; w < weeks; w++) {
        var first = days[w * 7].date;
        if (first.getMonth() !== lastMonth && w < weeks - 2) {
          if (lastMonth !== -1 || first.getDate() <= 7) {
            var t = svgEl('text', { x: left + w * (cell + gap), y: 10 });
            t.textContent = month.format(first).replace('.', '');
            labels.appendChild(t);
          }
          lastMonth = first.getMonth();
        }
      }
      var names = lang() === 'de' ? ['Mo', 'Mi', 'Fr'] : ['Mon', 'Wed', 'Fri'];
      [0, 2, 4].forEach(function (row, i) {
        var t = svgEl('text', { x: 0, y: top + row * (cell + gap) + cell - 2 });
        t.textContent = names[i];
        labels.appendChild(t);
      });
    }

    var count = days.filter(function (d) { return d.level > 0; }).length;
    var now = new Date();
    var month = days.filter(function (d) {
      return d.level > 0 && d.date.getMonth() === now.getMonth() && d.date.getFullYear() === now.getFullYear();
    }).length;
    var nf = function (n) { return new Intl.NumberFormat(locale()).format(n); };
    function renderStats() {
      $('[data-hm-workouts]', card).textContent = nf(count);
      $('[data-hm-best]', card).textContent = nf(bestStreak(days));
      $('[data-hm-month]', card).textContent = nf(month);
    }

    function paint() {
      $$('rect.c', cells).forEach(function (rect) {
        rect.setAttribute('class', 'c l' + rect.__level + (rect.__day.today ? ' today' : ''));
      });
    }

    function showTip(rect) {
      var day = rect.__day;
      var date = new Intl.DateTimeFormat(locale(), { weekday: 'short', day: 'numeric', month: 'short' }).format(day.date);
      var what;
      if (day.level > 0) what = lang() === 'de' ? 'Workout' : 'Workout';
      else if (day.rest) what = lang() === 'de' ? 'Ruhetag' : 'Rest day';
      else what = lang() === 'de' ? 'kein Training' : 'no training';
      tip.textContent = date + ' · ' + what;
      var box = rect.getBoundingClientRect();
      var cardBox = card.getBoundingClientRect();
      tip.style.left = (box.left + box.width / 2 - cardBox.left) + 'px';
      tip.style.top = (box.top - cardBox.top) + 'px';
      tip.hidden = false;
    }
    cells.addEventListener('mouseover', function (e) { if (e.target.__day) showTip(e.target); });
    cells.addEventListener('mouseleave', function () { tip.hidden = true; });

    renderLabels();
    renderStats();
    document.addEventListener('kilo:lang', function () { renderLabels(); renderStats(); });

    // Fill the squares in, week by week, the first time the card shows up.
    if (calm || !('IntersectionObserver' in window)) { paint(); return; }
    var io = new IntersectionObserver(function (entries) {
      if (!entries.some(function (e) { return e.isIntersecting; })) return;
      io.disconnect();
      $$('rect.c', cells).forEach(function (rect) {
        window.setTimeout(function () {
          rect.setAttribute('class', 'c l' + rect.__level + (rect.__day.today ? ' today' : ''));
        }, 200 + rect.__day.week * 22);
      });
    }, { threshold: 0.3 });
    io.observe(host);
  }

  /** The decorative calendar behind the hero. */
  function initHeroGrid() {
    var host = $('[data-hero-grid]');
    if (!host) return;
    var rand = rng(7);
    var cols = 46, rows = 26, cell = 18, gap = 6;
    var svg = svgEl('svg', { viewBox: '0 0 ' + cols * (cell + gap) + ' ' + rows * (cell + gap), preserveAspectRatio: 'xMidYMid slice' });
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        var v = rand();
        var level = v < 0.42 ? 0 : v < 0.62 ? 1 : v < 0.8 ? 2 : v < 0.93 ? 3 : 4;
        svg.appendChild(svgEl('rect', { class: 'l' + level, x: c * (cell + gap), y: r * (cell + gap), width: cell, height: cell, rx: 4 }));
      }
    }
    host.appendChild(svg);
  }

  // ========================================================== streak flame

  /** StreakFlame.sizeFor (streak_flame.dart): 18 at none, 40 from ~60 days. */
  function flameSize(days) {
    if (days <= 0) return 18;
    return 18 + 22 * Math.min(1, Math.log(1 + days) / Math.log(61));
  }

  function initFlame() {
    var card = $('[data-flame]');
    if (!card) return;
    var img = $('[data-flame-img]', card);
    var range = $('[data-flame-range]', card);
    var label = $('[data-flame-days]', card);
    var note = $('[data-flame-note]', card);
    var NOTES = {
      de: ['Keine Serie: die Flamme ist aus – klein und grau.', 'Sie wächst mit jedem Tag, am stärksten am Anfang.', 'Ab drei Tagen sprühen Funken.', 'Ab 30 Tagen brennt der Kern weißglühend.', 'Ab etwa zwei Monaten volle Größe.'],
      en: ['No streak: the flame is out – small and grey.', 'It grows with every day, most at the start.', 'From three days on it throws sparks.', 'From 30 days the core burns white-hot.', 'Full size from about two months on.']
    };
    function render() {
      var days = parseInt(range.value, 10) || 0;
      range.style.setProperty('--p', (days / 90 * 100) + '%');
      label.textContent = days;
      var src = days >= 30 ? 'assets/img/flame-45.webp' : 'assets/img/flame-6.webp';
      if (img.getAttribute('src') !== src) img.setAttribute('src', src);
      img.style.transform = 'scale(' + (flameSize(days) / 40).toFixed(3) + ')';
      img.classList.toggle('is-out', days === 0);
      var i = days === 0 ? 0 : days < 3 ? 1 : days < 30 ? 2 : days < 60 ? 3 : 4;
      note.textContent = NOTES[lang()][i];
    }
    range.addEventListener('input', render);
    document.addEventListener('kilo:lang', render);
    render();
  }

  // ========================================================== creatine

  function initCreatine() {
    var card = $('[data-creatine]');
    if (!card) return;
    var week = $('[data-creatine-week]', card);
    var todayBtn = $('[data-creatine-today]', card);
    var status = $('[data-creatine-status]', card);
    var streakEl = $('[data-creatine-streak]', card);
    // The last seven days, oldest first; today not ticked yet. Two more
    // days before the window keep the streak going, like a real run.
    var taken = [true, true, true, true, true, true, false];
    var before = 2;
    var dots = [];

    function streak() {
      var i = taken[6] ? 6 : 5;
      var n = 0;
      while (i >= 0 && taken[i]) { n++; i--; }
      return i < 0 ? n + before : n;
    }

    function render() {
      var short = new Intl.DateTimeFormat(locale(), { weekday: 'short' });
      dots.forEach(function (dot, i) {
        dot.btn.setAttribute('aria-pressed', taken[i] ? 'true' : 'false');
        dot.label.textContent = short.format(dot.date).replace('.', '').slice(0, 2);
        dot.btn.setAttribute('aria-label', new Intl.DateTimeFormat(locale(), { weekday: 'long', day: 'numeric', month: 'long' }).format(dot.date));
      });
      todayBtn.setAttribute('aria-pressed', taken[6] ? 'true' : 'false');
      status.textContent = taken[6]
        ? (lang() === 'de' ? 'Heute genommen' : 'Taken today')
        : (lang() === 'de' ? 'Heute noch nicht abgehakt' : 'Not ticked off today');
      status.classList.toggle('is-done', taken[6]);
      streakEl.textContent = streak();
    }

    var today = new Date();
    for (var i = 0; i < 7; i++) {
      var d = new Date(today);
      d.setDate(today.getDate() - (6 - i));
      var li = document.createElement('li');
      if (i === 6) li.className = 'is-today';
      var label = document.createElement('span');
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'creatine__day';
      btn.innerHTML = '<svg aria-hidden="true"><use href="#i-check"/></svg>';
      (function (index) {
        btn.addEventListener('click', function () { taken[index] = !taken[index]; render(); });
      })(i);
      li.appendChild(label);
      li.appendChild(btn);
      week.appendChild(li);
      dots.push({ date: d, btn: btn, label: label });
    }
    todayBtn.addEventListener('click', function () { taken[6] = !taken[6]; render(); });
    document.addEventListener('kilo:lang', render);
    render();
  }

  // ========================================================== app icons

  // launcher_icons.dart: accent per hue (light mode, dark mode).
  var HUES = [
    ['#2F6FEB', '#5588FF'], ['#009B78', '#1FD6A8'], ['#6D5CE8', '#9585FF'], ['#BA7C00', '#E0A83A'],
    ['#009C60', '#35C98A'], ['#E24B4A', '#E24B4A'], ['#D4537E', '#D4537E'], ['#16171B', '#F2F2F4']
  ];

  function initIcons() {
    var grid = $('[data-icon-grid]');
    var mark = window.KiloMark;
    if (!grid || !mark) return;
    var n = 0;
    [false, true].forEach(function (dark) {
      HUES.forEach(function (hue, i) {
        var graphite = i === HUES.length - 1;
        var tile = dark ? '#101114' : graphite ? '#FFFFFF' : hue[0];
        var glyph = dark ? hue[1] : graphite ? hue[0] : '#FFFFFF';
        var el = document.createElement('div');
        el.className = 'ic' + (dark ? ' ic--dark' : '');
        el.style.setProperty('--i', n++);
        // The launcher shows the glyph at 66 of the 72dp a mask leaves.
        var scale = (66 / 72) * 100 / 100;
        var inset = (100 - 100 * scale) / 2;
        el.innerHTML = '<svg viewBox="0 0 100 100"><rect width="100" height="100" fill="' + tile + '"/>' +
          '<g fill="' + glyph + '" transform="translate(' + inset + ' ' + inset + ') scale(' + scale + ')">' +
          '<path d="' + mark.BAR + '"/><path d="' + mark.PLATES + '"/></g></svg>';
        grid.appendChild(el);
      });
    });
  }

  // ========================================================== boot

  function init() {
    initLanguage();
    initTheme();
    initNav();
    initPlatform();
    initLogos();
    initHeroGrid();
    initTour();
    initHeatmap();
    initFlame();
    initCreatine();
    initIcons();
    initReveals();
    initCounters();
    initRelease();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
