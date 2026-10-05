/*
 * Ironpeak website — page behavior.
 *
 * Everything here is progressive enhancement: the page is complete without
 * it (both languages are in the markup, content is visible, links work).
 * With it: language switch, the logo intro, smooth scrolling and the
 * scroll choreography (GSAP + ScrollTrigger + Lenis, all vendored), the
 * altimeter, a favicon whose barbell rises as you scroll, live release
 * info from GitHub, and download buttons for the visitor's platform.
 * Reduced motion (html.calm) keeps every feature that isn't motion.
 */
(function () {
  'use strict';

  var REPO = 'Sieder2009/GymTracker';
  var SUMMIT_METERS = 3905;

  var root = document.documentElement;
  var calm = root.classList.contains('calm');
  var gsap = window.gsap;
  var ScrollTrigger = window.ScrollTrigger;
  var motion = !calm && !!gsap && !!ScrollTrigger;
  var finePointer = window.matchMedia && window.matchMedia('(hover: hover) and (pointer: fine)').matches;

  if (motion) gsap.registerPlugin(ScrollTrigger);

  function $(selector, scope) {
    return (scope || document).querySelector(selector);
  }
  function $$(selector, scope) {
    return Array.prototype.slice.call((scope || document).querySelectorAll(selector));
  }
  function lang() {
    return root.lang === 'en' ? 'en' : 'de';
  }
  function numberFormat(options) {
    return new Intl.NumberFormat(lang() === 'de' ? 'de-DE' : 'en-US', options);
  }

  // ============================================================ language

  var TITLE = {
    de: 'Ironpeak Fitness – Trainingsplaner, Krafttracker & Analysen, 100 % lokal',
    en: 'Ironpeak Fitness – workout planner, strength tracker & analytics, 100% local'
  };
  var DESCRIPTION = {
    de: 'Ironpeak Fitness ist Trainingsplaner, Krafttracker und Analyse-Tool in einer nativen App für Android, iOS, Windows und macOS. Kostenlos, ohne Konto, ohne Cloud – alle Daten bleiben auf deinem Gerät.',
    en: 'Ironpeak Fitness is a workout planner, strength tracker and analytics tool in one native app for Android, iOS, Windows and macOS. Free, no account, no cloud – all your data stays on your device.'
  };

  var currentSection = null;

  function updateTitle() {
    var l = lang();
    var name = currentSection && currentSection.id !== 'top' ? currentSection.getAttribute('data-name-' + l) : null;
    document.title = name ? 'Ironpeak Fitness · ' + name : TITLE[l];
  }

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
    var description = $('meta[name="description"]');
    if (description) description.setAttribute('content', DESCRIPTION[next]);
    updateTitle();
    if (persist) {
      try { localStorage.setItem('ironpeak-lang', next); } catch (e) { /* private mode */ }
    }
    document.dispatchEvent(new CustomEvent('ironpeak:lang', { detail: next }));
    if (motion) ScrollTrigger.refresh();
  }

  function initLanguage() {
    applyLang(lang(), false);
    $$('[data-set-lang]').forEach(function (button) {
      button.addEventListener('click', function () {
        var next = button.getAttribute('data-set-lang');
        if (next !== lang()) applyLang(next, true);
      });
    });
  }

  // ======================================================= platform & CTA

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
    var platform = detectPlatform();
    if (!platform) return;
    var card = $('.platform[data-platform="' + platform + '"]');
    if (card) {
      card.classList.add('is-yours');
      card.parentNode.insertBefore(card, card.parentNode.firstElementChild);
    }
    var name = PLATFORM_NAMES[platform];
    var de = $('[data-cta-de]');
    var en = $('[data-cta-en]');
    if (de) de.textContent = 'Für ' + name + ' laden';
    if (en) en.textContent = 'Get it for ' + name;
  }

  // ======================================================= release info

  var release = null;

  function renderRelease() {
    if (!release) return;
    $$('[data-release-version]').forEach(function (el) { el.textContent = release.tag; });
    var date = new Date(release.date);
    if (!isNaN(date)) {
      var formatted = new Intl.DateTimeFormat(lang() === 'de' ? 'de-DE' : 'en-US', {
        day: 'numeric', month: 'long', year: 'numeric'
      }).format(date);
      $$('[data-release-date]').forEach(function (el) { el.textContent = formatted; });
    }
    $$('[data-asset-size]').forEach(function (el) {
      var name = el.getAttribute('data-asset-size');
      var asset = release.assets.filter(function (a) { return a.name === name; })[0];
      el.textContent = asset ? numberFormat({ maximumFractionDigits: 1 }).format(asset.size / 1048576) + ' MB' : '';
    });
    var chip = $('[data-release-chip]');
    if (chip) {
      chip.href = release.url;
      chip.hidden = false;
    }
    var line = $('[data-release-line]');
    if (line) line.hidden = false;
  }

  function initRelease() {
    var KEY = 'ironpeak-release';
    try {
      var cached = JSON.parse(sessionStorage.getItem(KEY));
      if (cached && Date.now() - cached.at < 3600 * 1000) {
        release = cached.data;
        renderRelease();
        return;
      }
    } catch (e) { /* no storage */ }
    if (!window.fetch) return;
    fetch('https://api.github.com/repos/' + REPO + '/releases/latest', {
      headers: { Accept: 'application/vnd.github+json' }
    })
      .then(function (response) {
        if (!response.ok) throw new Error('GitHub ' + response.status);
        return response.json();
      })
      .then(function (json) {
        if (!json || !json.tag_name) return;
        release = {
          tag: json.tag_name,
          date: json.published_at,
          url: json.html_url,
          assets: (json.assets || []).map(function (a) { return { name: a.name, size: a.size }; })
        };
        try { sessionStorage.setItem(KEY, JSON.stringify({ at: Date.now(), data: release })); } catch (e) { /* no storage */ }
        renderRelease();
      })
      .catch(function () { /* offline or rate-limited: the page works without it */ });
    document.addEventListener('ironpeak:lang', renderRelease);
  }

  // ============================================================== logos

  function playLogo(render, from, to, done) {
    var start = null;
    function frame(now) {
      if (start === null) start = now;
      var t = from + (now - start) / 1000;
      if (t >= to) {
        render(window.IronpeakMark.poseAt(to));
        if (done) done();
        return;
      }
      render(window.IronpeakMark.poseAt(t));
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  function initLogos() {
    var mark = window.IronpeakMark;
    if (!mark) return;
    var intro = mark.INTRO_SECONDS;
    var loop = mark.LOOP_SECONDS;

    $$('[data-logo="hover"]').forEach(function (svg) {
      var render = mark.mount(svg);
      var busy = false;
      var host = svg.closest('a') || svg;
      host.addEventListener('mouseenter', function () {
        if (busy || calm) return;
        busy = true;
        playLogo(render, intro, intro + loop, function () { busy = false; });
      });
    });

    $$('[data-logo="static"]').forEach(function (svg) {
      var render = mark.mount(svg);
      if (calm) return;
      var played = false;
      function replay() { playLogo(render, 0, intro + loop); }
      svg.style.cursor = 'pointer';
      svg.addEventListener('click', replay);
      if ('IntersectionObserver' in window) {
        var io = new IntersectionObserver(function (entries) {
          if (!played && entries[0].isIntersecting) {
            played = true;
            io.disconnect();
            replay();
          }
        }, { threshold: 0.6 });
        io.observe(svg);
      }
    });
  }

  // ============================================================== intro

  function runIntro(lenis, startHero) {
    var overlay = $('.intro');
    if (!root.classList.contains('intro-on') || !overlay || !window.IronpeakMark || !motion) {
      root.classList.remove('intro-on');
      startHero(0);
      return;
    }
    try { sessionStorage.setItem('ironpeak-intro', '1'); } catch (e) { /* no storage */ }
    window.scrollTo(0, 0);
    if (lenis) lenis.stop();

    var render = window.IronpeakMark.mount($('.intro__logo', overlay));
    var finished = false;

    function finish() {
      if (finished) return;
      finished = true;
      startHero(0.35);
      gsap.timeline({
        onComplete: function () {
          root.classList.remove('intro-on');
          overlay.removeAttribute('style');
          if (lenis) lenis.start();
        }
      })
        .to('.intro__logo', { y: -40, opacity: 0, duration: 0.5, ease: 'power2.in' }, 0)
        .to('.intro__bar', { opacity: 0, duration: 0.3 }, 0)
        .fromTo(overlay, { clipPath: 'inset(0% 0% 0% 0%)' }, { clipPath: 'inset(0% 0% 100% 0%)', duration: 0.95, ease: 'expo.inOut' }, 0.1);
    }

    overlay.addEventListener('click', finish);
    playLogo(render, 0, window.IronpeakMark.INTRO_SECONDS, function () {
      setTimeout(finish, 260);
    });
  }

  // ======================================================= hero (motion)

  function splitLetters(el) {
    var text = el.textContent;
    el.textContent = '';
    text.split('').forEach(function (c) {
      var span = document.createElement('span');
      span.className = 'lt';
      span.textContent = c;
      el.appendChild(span);
    });
    el.classList.add('is-split');
    return $$('.lt', el);
  }

  function prepareHero() {
    var letters = splitLetters($('[data-hero-letters]'));
    var ins = $$('[data-hero-in]');
    gsap.set(letters, { yPercent: 70, opacity: 0, rotateX: -60, transformOrigin: '50% 100%' });
    gsap.set(ins, { y: 26, opacity: 0 });
    gsap.set('.hero__front', { yPercent: 10 });
    gsap.set('.hero__ridge--mid', { yPercent: 16 });
    gsap.set('.hero__ridge--far', { yPercent: 22 });
    gsap.set('.hero__stars', { opacity: 0 });
    root.classList.add('ready');

    return function play(delay) {
      var tl = gsap.timeline({ delay: delay || 0 });
      tl.to('.hero__stars', { opacity: 1, duration: 2, ease: 'power1.out' }, 0)
        .to(['.hero__ridge--far', '.hero__ridge--mid', '.hero__front'], { yPercent: 0, duration: 1.8, ease: 'expo.out', stagger: 0.06 }, 0)
        .to(letters, { yPercent: 0, opacity: 1, rotateX: 0, duration: 1.3, ease: 'expo.out', stagger: 0.055 }, 0.12)
        .to(ins, { y: 0, opacity: 1, duration: 1, ease: 'expo.out', stagger: 0.09 }, 0.45);
    };
  }

  function heroScroll() {
    var vh = function (k) { return function () { return k * window.innerHeight; }; };
    gsap.timeline({
      scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom bottom', scrub: true, invalidateOnRefresh: true }
    })
      .to('.hero__front', { y: vh(-0.36), scale: 1.12, ease: 'none', duration: 1 }, 0)
      .to('.hero__ridge--mid', { y: vh(-0.16), ease: 'none', duration: 1 }, 0)
      .to('.hero__ridge--far', { y: vh(-0.08), ease: 'none', duration: 1 }, 0)
      .to('.hero__stars', { y: vh(-0.05), ease: 'none', duration: 1 }, 0)
      .to('.hero__aurora', { opacity: 0.25, ease: 'none', duration: 1 }, 0)
      .to('.hero__title', { y: vh(0.14), scale: 0.92, ease: 'none', duration: 1 }, 0)
      .to('.hero__title', { opacity: 0, ease: 'power1.in', duration: 0.45 }, 0.35)
      .to('.hero__foot', { y: vh(-0.05), opacity: 0, ease: 'power1.in', duration: 0.28 }, 0);
  }

  // ============================================================== stars

  function initStars() {
    var canvas = $('.hero__stars');
    if (!canvas || !canvas.getContext) return;
    var ctx = canvas.getContext('2d');
    var stars = [];
    var width = 0;
    var height = 0;
    var running = false;
    var visible = true;
    var last = 0;
    var meteor = null;
    var nextMeteor = 0;

    function resize() {
      var dpr = Math.min(2, window.devicePixelRatio || 1);
      width = canvas.clientWidth;
      height = canvas.clientHeight;
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      var count = Math.max(110, Math.min(420, Math.round((width * height) / 4300)));
      if (Math.abs(count - stars.length) > stars.length * 0.4) {
        stars = [];
        for (var i = 0; i < count; i++) {
          stars.push({
            x: Math.random(),
            y: Math.pow(Math.random(), 1.35) * 0.82,
            r: Math.random() < 0.08 ? 1.1 + Math.random() * 0.6 : 0.35 + Math.random() * 0.75,
            a: 0.3 + Math.random() * 0.7,
            s: 0.6 + Math.random() * 2.2,
            p: Math.random() * Math.PI * 2
          });
        }
      }
      draw(performance.now());
    }

    function draw(now) {
      var time = now / 1000;
      ctx.clearRect(0, 0, width, height);
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i];
        var alpha = calm ? s.a : s.a * (0.62 + 0.38 * Math.sin(time * s.s + s.p));
        ctx.globalAlpha = alpha;
        ctx.fillStyle = s.r > 1.05 ? '#f4fffa' : '#cfe9dd';
        ctx.beginPath();
        ctx.arc(s.x * width, s.y * height, s.r, 0, Math.PI * 2);
        ctx.fill();
      }
      if (meteor) {
        var k = (now - meteor.start) / meteor.duration;
        if (k >= 1) {
          meteor = null;
        } else {
          var head = { x: meteor.x + meteor.dx * k, y: meteor.y + meteor.dy * k };
          var tail = { x: head.x - meteor.dx * 0.22, y: head.y - meteor.dy * 0.22 };
          var gradient = ctx.createLinearGradient(tail.x, tail.y, head.x, head.y);
          gradient.addColorStop(0, 'rgba(255,255,255,0)');
          gradient.addColorStop(1, 'rgba(235,255,246,0.9)');
          ctx.globalAlpha = Math.sin(Math.PI * k);
          ctx.strokeStyle = gradient;
          ctx.lineWidth = 1.4;
          ctx.beginPath();
          ctx.moveTo(tail.x, tail.y);
          ctx.lineTo(head.x, head.y);
          ctx.stroke();
        }
      }
      ctx.globalAlpha = 1;
    }

    function frame(now) {
      if (!running) return;
      requestAnimationFrame(frame);
      if (now - last < 33) return; // ~30 fps is plenty for twinkling
      last = now;
      if (!meteor && now > nextMeteor) {
        if (nextMeteor) {
          meteor = {
            start: now,
            duration: 900,
            x: width * (0.15 + Math.random() * 0.6),
            y: height * (0.05 + Math.random() * 0.25),
            dx: width * (0.18 + Math.random() * 0.12) * (Math.random() < 0.5 ? -1 : 1),
            dy: height * (0.12 + Math.random() * 0.08)
          };
        }
        nextMeteor = now + 6000 + Math.random() * 9000;
      }
      draw(now);
    }

    function setRunning() {
      var should = !calm && visible && !document.hidden;
      if (should && !running) {
        running = true;
        requestAnimationFrame(frame);
      } else if (!should) {
        running = false;
      }
    }

    resize();
    window.addEventListener('resize', resize);
    if (calm) return;
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        visible = entries[0].isIntersecting;
        setRunning();
      }).observe(canvas);
    }
    document.addEventListener('visibilitychange', setRunning);
    setRunning();
  }

  // ===================================================== scroll reveals

  function splitWords(el) {
    var words = el.textContent.trim().split(/\s+/);
    el.textContent = '';
    words.forEach(function (word, i) {
      var span = document.createElement('span');
      span.className = 'w';
      span.textContent = word;
      el.appendChild(span);
      if (i < words.length - 1) el.appendChild(document.createTextNode(' '));
    });
    return $$('.w', el);
  }

  function initReveals() {
    // manifesto: words light up as you read. Painted from one scrubbed
    // progress value, so a ScrollTrigger refresh can never leave words
    // that haven't started yet at full opacity.
    $$('[data-words] [data-l]').forEach(function (span) {
      var words = splitWords(span);
      var state = { p: 0 };
      var paint = function () {
        var lit = state.p * (words.length + 3);
        words.forEach(function (word, i) {
          word.style.opacity = String(0.14 + 0.86 * Math.min(1, Math.max(0, lit - i)));
        });
      };
      paint();
      gsap.to(state, {
        p: 1,
        ease: 'none',
        onUpdate: paint,
        scrollTrigger: { trigger: span.parentNode, start: 'top 82%', end: 'bottom 48%', scrub: true }
      });
    });

    [
      ['[data-reveal]', 0],
      ['.stat', 0.08],
      ['.chapter', 0],
      ['.card', 0.08],
      ['.tile', 0.05],
      ['.zeros li', 0.1],
      ['.platform', 0.08]
    ].forEach(function (pair) {
      var els = $$(pair[0]);
      if (!els.length) return;
      var show = function (batch) {
        gsap.to(batch, { y: 0, opacity: 1, duration: 1.1, ease: 'expo.out', stagger: pair[1], overwrite: true });
      };
      gsap.set(els, { y: 50, opacity: 0 });
      ScrollTrigger.batch(els, { start: 'top 90%', onEnter: show, onEnterBack: show, onLeave: show });
    });

    // privacy: the sun comes up behind the snowfield
    gsap.fromTo('.privacy__sun', { yPercent: 70 }, {
      yPercent: -6,
      ease: 'none',
      scrollTrigger: { trigger: '.privacy', start: 'top bottom', end: 'bottom bottom', scrub: true }
    });

    // footer: the outlined wordmark fills with green as you reach the bottom
    gsap.fromTo('.foot__word', { backgroundPosition: '100% 0' }, {
      backgroundPosition: '0% 0',
      ease: 'none',
      scrollTrigger: { trigger: '.foot', start: 'top bottom', end: 'bottom bottom', scrub: true }
    });
  }

  function initCounters() {
    $$('[data-count]').forEach(function (el) {
      var target = parseInt(el.textContent, 10);
      if (isNaN(target)) return;
      var from = target === 0 ? 12 : 0;
      var state = { v: from };
      var started = false;
      ScrollTrigger.create({
        trigger: el,
        start: 'top 92%',
        onEnter: function () {
          if (started) return;
          started = true;
          el.textContent = String(from);
          gsap.to(state, {
            v: target,
            duration: target === 0 ? 1.2 : 1.8,
            ease: target === 0 ? 'power2.out' : 'expo.out',
            onUpdate: function () { el.textContent = String(Math.round(state.v)); }
          });
        }
      });
    });
  }

  // ================================================================ tour

  function initTour() {
    var chapters = $$('.chapter');
    var shots = $$('.phone__screen img');
    var dots = $$('.tour__dots li');
    var bignum = $('[data-tour-num]');
    if (!chapters.length || !shots.length) return;
    var active = 0;

    function setActive(i) {
      if (i === active) return;
      active = i;
      shots.forEach(function (img, k) { img.classList.toggle('is-active', k === i); });
      dots.forEach(function (li, k) { li.classList.toggle('is-active', k === i); });
      if (bignum) {
        bignum.textContent = '0' + (i + 1);
        if (motion) gsap.fromTo(bignum, { opacity: 0, scale: 0.94 }, { opacity: 1, scale: 1, duration: 0.6, ease: 'expo.out', overwrite: true });
      }
    }

    if (motion) {
      chapters.forEach(function (chapter, i) {
        ScrollTrigger.create({
          trigger: chapter,
          start: 'top center',
          end: 'bottom center',
          onToggle: function (self) { if (self.isActive) setActive(i); }
        });
      });
    } else if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) setActive(chapters.indexOf(entry.target));
        });
      }, { rootMargin: '-50% 0px -50% 0px' });
      chapters.forEach(function (chapter) { io.observe(chapter); });
    }
  }

  // ============================================================== marquee

  function initMarquee() {
    if (calm) return;
    $$('.marquee__track').forEach(function (track) {
      Array.prototype.slice.call(track.children).forEach(function (child) {
        var copy = child.cloneNode(true);
        copy.setAttribute('aria-hidden', 'true');
        track.appendChild(copy);
      });
    });
    root.classList.add('marquee-ready');
  }

  // ============================================================ buttons

  function initPills() {
    $$('.pill .pill__text').forEach(function (text) {
      var leaves = $$('[data-l]', text);
      if (!leaves.length) leaves = [text];
      leaves.forEach(function (leaf) {
        var label = leaf.textContent.trim();
        leaf.textContent = '';
        var readable = document.createElement('span');
        readable.className = 'sr-only';
        readable.textContent = label;
        var roll = document.createElement('span');
        roll.className = 'roll';
        roll.setAttribute('aria-hidden', 'true');
        label.split('').forEach(function (c, i) {
          var ch = document.createElement('span');
          var glyph = c === ' ' ? ' ' : c;
          ch.className = 'ch';
          ch.style.setProperty('--i', i);
          ch.setAttribute('data-c', glyph);
          ch.textContent = glyph;
          roll.appendChild(ch);
        });
        leaf.appendChild(readable);
        leaf.appendChild(roll);
      });
    });

    if (!motion || !finePointer) return;
    $$('[data-magnetic]').forEach(function (el) {
      var toX = gsap.quickTo(el, 'x', { duration: 0.5, ease: 'power3.out' });
      var toY = gsap.quickTo(el, 'y', { duration: 0.5, ease: 'power3.out' });
      el.addEventListener('pointermove', function (e) {
        var r = el.getBoundingClientRect();
        toX((e.clientX - r.left - r.width / 2) * 0.22);
        toY((e.clientY - r.top - r.height / 2) * 0.32);
      });
      el.addEventListener('pointerleave', function () {
        toX(0);
        toY(0);
      });
    });
  }

  function initTiles() {
    if (!finePointer) return;
    $$('.tile').forEach(function (tile) {
      tile.addEventListener('pointermove', function (e) {
        var r = tile.getBoundingClientRect();
        tile.style.setProperty('--mx', e.clientX - r.left + 'px');
        tile.style.setProperty('--my', e.clientY - r.top + 'px');
      });
    });
  }

  // =================================================== nav, anchors, menu

  function initNav(lenis) {
    var nav = $('[data-nav]');
    var menu = $('[data-menu]');

    function closeMenu() {
      nav.classList.remove('is-open');
      if (menu) menu.setAttribute('aria-expanded', 'false');
    }

    if (menu) {
      menu.addEventListener('click', function () {
        var open = !nav.classList.contains('is-open');
        nav.classList.toggle('is-open', open);
        menu.setAttribute('aria-expanded', open ? 'true' : 'false');
      });
      document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') closeMenu();
      });
    }

    document.addEventListener('click', function (e) {
      var link = e.target.closest && e.target.closest('a[href^="#"]');
      if (!link) return;
      var id = link.getAttribute('href').slice(1);
      var target = id ? document.getElementById(id) : null;
      if (!target) return;
      e.preventDefault();
      closeMenu();
      if (lenis) {
        lenis.scrollTo(id === 'top' ? 0 : target, { duration: 1.4 });
      } else {
        target.scrollIntoView({ behavior: calm ? 'auto' : 'smooth' });
      }
      if (history.replaceState) history.replaceState(null, '', '#' + id);
      if (id !== 'top' && id !== 'main') {
        if (!target.hasAttribute('tabindex')) target.setAttribute('tabindex', '-1');
        target.focus({ preventScroll: true });
      }
    });

    return { nav: nav, closeMenu: closeMenu };
  }

  // ================================= altimeter, progress, favicon, title

  function initScrollState(navApi) {
    var nav = navApi.nav;
    var altimeter = $('.altimeter');
    var altValue = $('[data-alt-value]');
    var altMarker = $('[data-alt-marker]');
    var altCamp = $('[data-alt-camp]');
    var track = $('.altimeter__track');
    var bar = $('[data-progress]');
    var sections = $$('main > section');
    var lights = $$('[data-theme="light"]');
    var lastY = window.scrollY;
    var ticking = false;
    var faviconStep = -1;
    var icon = null;
    var canvas = document.createElement('canvas');
    canvas.width = canvas.height = 64;
    var ctx = canvas.getContext && canvas.getContext('2d');
    var canPaintIcon = !calm && !!ctx && !!window.IronpeakMark && typeof Path2D !== 'undefined';

    function updateFavicon(progress) {
      var step = Math.round(progress * 14);
      if (step === faviconStep) return;
      faviconStep = step;
      window.IronpeakMark.paintCanvas(ctx, 64, -step);
      if (!icon) {
        $$('link[rel~="icon"]').forEach(function (link) { link.remove(); });
        icon = document.createElement('link');
        icon.rel = 'icon';
        icon.type = 'image/png';
        document.head.appendChild(icon);
      }
      icon.href = canvas.toDataURL('image/png');
    }

    function update() {
      ticking = false;
      var y = window.scrollY;
      var max = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
      var progress = Math.min(1, Math.max(0, y / max));

      nav.classList.toggle('is-scrolled', y > 8);
      if (!nav.classList.contains('is-open')) {
        if (y > window.innerHeight && y > lastY + 6) nav.classList.add('is-tucked');
        else if (y < lastY - 6 || y <= window.innerHeight) nav.classList.remove('is-tucked');
      }
      lastY = y;

      var probe = (nav.offsetHeight || 68) / 2;
      var onLight = lights.some(function (el) {
        var r = el.getBoundingClientRect();
        return r.top <= probe && r.bottom >= probe;
      });
      nav.classList.toggle('is-light', onLight);

      var middle = window.innerHeight * 0.5;
      var light = lights.some(function (el) {
        var r = el.getBoundingClientRect();
        return r.top <= middle && r.bottom >= middle;
      });
      if (altimeter) altimeter.classList.toggle('is-light', light);

      var section = sections[0];
      sections.forEach(function (s) {
        if (s.getBoundingClientRect().top <= window.innerHeight * 0.4) section = s;
      });
      if (section !== currentSection) {
        currentSection = section;
        updateTitle();
        if (altCamp) altCamp.textContent = section.getAttribute('data-name-' + lang()) || '';
      }

      if (altValue) altValue.textContent = numberFormat().format(Math.round(progress * SUMMIT_METERS));
      if (altMarker && track) altMarker.style.transform = 'translateY(' + (-progress * track.offsetHeight) + 'px)';
      if (bar) bar.style.transform = 'scaleX(' + progress + ')';
      if (canPaintIcon) updateFavicon(progress);
    }

    function request() {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    }

    window.addEventListener('scroll', request, { passive: true });
    window.addEventListener('resize', request);
    document.addEventListener('ironpeak:lang', function () {
      currentSection = null;
      update();
    });
    update();
  }

  // ================================================================ boot

  function boot() {
    initLanguage();
    initPlatform();
    initPills();
    initLogos();
    initRelease();
    initStars();
    initTour();
    initTiles();
    initMarquee();

    var lenis = null;
    if (!calm && window.Lenis) {
      lenis = new window.Lenis({ autoRaf: !motion, lerp: 0.11 });
      if (motion) {
        lenis.on('scroll', ScrollTrigger.update);
        gsap.ticker.add(function (time) { lenis.raf(time * 1000); });
        gsap.ticker.lagSmoothing(0);
      }
    }

    var navApi = initNav(lenis);
    initScrollState(navApi);

    if (!motion) {
      root.classList.remove('intro-on');
      root.classList.add('ready');
      return;
    }

    var playHero = prepareHero();
    heroScroll();
    initReveals();
    initCounters();
    runIntro(lenis, playHero);

    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () { ScrollTrigger.refresh(); });
    }
    window.addEventListener('load', function () { ScrollTrigger.refresh(); });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
