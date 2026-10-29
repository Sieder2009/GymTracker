/*
 * The Kilo mark -- a loaded barbell -- and its motion. A 1:1 port of
 * mobile/lib/widgets/ironpeak_logo.dart (IronpeakMark): the same path
 * strings, the same 100x100 logo units and the same timeline (the barbell
 * drops in with Android's bounce and squashes on impact, then does one calm
 * rep forever), so the site moves exactly like the app's launch screen.
 *
 *   KiloMark.mount(el, { size, motion: 'loop' | 'intro' | 'hover' | 'none' })
 *
 * draws an <svg> into el. The tile and glyph colors come from CSS
 * (--logo-tile, --logo-glyph, --logo-line), so the mark follows the page's
 * light/dark theme like the in-app logo follows the app's.
 */
(function (w) {
  'use strict';

  var BAR =
    'M33,47H67A1,1 0 0 1 68,48V52A1,1 0 0 1 67,53H33A1,1 0 0 1 32,52V48A1,1 0 0 1 33,47Z' +
    'M4,46H32A1.5,1.5 0 0 1 33.5,47.5V52.5A1.5,1.5 0 0 1 32,54H4A1.5,1.5 0 0 1 2.5,52.5V47.5A1.5,1.5 0 0 1 4,46Z' +
    'M68,46H96A1.5,1.5 0 0 1 97.5,47.5V52.5A1.5,1.5 0 0 1 96,54H68A1.5,1.5 0 0 1 66.5,52.5V47.5A1.5,1.5 0 0 1 68,46Z';

  var PLATES =
    'M32.5,42H33.5A1,1 0 0 1 34.5,43V57A1,1 0 0 1 33.5,58H32.5A1,1 0 0 1 31.5,57V43A1,1 0 0 1 32.5,42Z' +
    'M66.5,42H67.5A1,1 0 0 1 68.5,43V57A1,1 0 0 1 67.5,58H66.5A1,1 0 0 1 65.5,57V43A1,1 0 0 1 66.5,42Z' +
    'M24.3,21H28.8A1.5,1.5 0 0 1 30.3,22.5V77.5A1.5,1.5 0 0 1 28.8,79H24.3A1.5,1.5 0 0 1 22.8,77.5V22.5A1.5,1.5 0 0 1 24.3,21Z' +
    'M71.2,21H75.7A1.5,1.5 0 0 1 77.2,22.5V77.5A1.5,1.5 0 0 1 75.7,79H71.2A1.5,1.5 0 0 1 69.7,77.5V22.5A1.5,1.5 0 0 1 71.2,21Z' +
    'M15.6,21H20.1A1.5,1.5 0 0 1 21.6,22.5V77.5A1.5,1.5 0 0 1 20.1,79H15.6A1.5,1.5 0 0 1 14.1,77.5V22.5A1.5,1.5 0 0 1 15.6,21Z' +
    'M79.9,21H84.4A1.5,1.5 0 0 1 85.9,22.5V77.5A1.5,1.5 0 0 1 84.4,79H79.9A1.5,1.5 0 0 1 78.4,77.5V22.5A1.5,1.5 0 0 1 79.9,21Z' +
    'M9.6,31H11.7A1.2,1.2 0 0 1 12.9,32.2V67.8A1.2,1.2 0 0 1 11.7,69H9.6A1.2,1.2 0 0 1 8.4,67.8V32.2A1.2,1.2 0 0 1 9.6,31Z' +
    'M88.3,31H90.4A1.2,1.2 0 0 1 91.6,32.2V67.8A1.2,1.2 0 0 1 90.4,69H88.3A1.2,1.2 0 0 1 87.1,67.8V32.2A1.2,1.2 0 0 1 88.3,31Z' +
    'M5.6,42.5H6.2A1,1 0 0 1 7.2,43.5V56.5A1,1 0 0 1 6.2,57.5H5.6A1,1 0 0 1 4.6,56.5V43.5A1,1 0 0 1 5.6,42.5Z' +
    'M93.8,42.5H94.4A1,1 0 0 1 95.4,43.5V56.5A1,1 0 0 1 94.4,57.5H93.8A1,1 0 0 1 92.8,56.5V43.5A1,1 0 0 1 93.8,42.5Z';

  // Bottom middle of the big plates: the barbell squashes around it.
  var FOOT_X = 50;
  var FOOT_Y = 79;

  // Glyph box as a fraction of the badge (IronpeakMark.badgeGlyphFraction).
  var GLYPH = 0.72;

  var INTRO = 0.72;
  var LOOP = 3.6;
  var DROP_HEIGHT = 60;
  var DROP = [0.08, 0.6];
  var FADE = [0.08, 0.1];
  var SQUASH_DEPTH = 0.06;
  var SQUASH_DOWN = 0.07;
  var SQUASH_UP = 0.12;
  var IMPACT = DROP[0] + DROP[1] * (0.3535 / 1.1226);
  var REP_HEIGHT = 6;
  var REP_UP = [1.2, 0.55];
  var REP_DOWN = [2.05, 0.75];

  function seg(t, timing) {
    return Math.min(1, Math.max(0, (t - timing[0]) / timing[1]));
  }

  // Android's interpolators, verbatim.
  function bounce(t) {
    function b(x) { return x * x * 8; }
    var x = t * 1.1226;
    if (x < 0.3535) return b(x);
    if (x < 0.7408) return b(x - 0.54719) + 0.7;
    if (x < 0.9644) return b(x - 0.8526) + 0.9;
    return b(x - 1.0435) + 0.95;
  }
  function decelerate(t) { return 1 - (1 - t) * (1 - t); }
  function accelerateDecelerate(t) { return Math.cos((t + 1) * Math.PI) / 2 + 0.5; }

  // Flutter's Curves.fastOutSlowIn: cubic-bezier(0.4, 0, 0.2, 1).
  function fastOutSlowIn(t) {
    var x1 = 0.4, y1 = 0, x2 = 0.2, y2 = 1;
    function at(a, b, m) { return 3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m; }
    var lo = 0, hi = 1, mid = t;
    for (var i = 0; i < 24; i++) {
      mid = (lo + hi) / 2;
      if (at(x1, x2, mid) < t) lo = mid; else hi = mid;
    }
    return at(y1, y2, mid);
  }

  /** The pose at `seconds` since the logo appeared (IronpeakMark.poseAt). */
  function poseAt(seconds) {
    if (seconds < INTRO) {
      var down = decelerate(seg(seconds, [IMPACT, SQUASH_DOWN]));
      var up = decelerate(seg(seconds, [IMPACT + SQUASH_DOWN, SQUASH_UP]));
      return {
        dy: -DROP_HEIGHT * (1 - bounce(seg(seconds, DROP))),
        alpha: seg(seconds, FADE),
        squash: 1 - SQUASH_DEPTH * down * (1 - up)
      };
    }
    var u = (seconds - INTRO) % LOOP;
    var lift = fastOutSlowIn(seg(u, REP_UP));
    var lower = accelerateDecelerate(seg(u, REP_DOWN));
    return { dy: -REP_HEIGHT * (lift - lower), alpha: 1, squash: 1 };
  }

  var NS = 'http://www.w3.org/2000/svg';
  var uid = 0;

  function el(name, attrs) {
    var node = document.createElementNS(NS, name);
    Object.keys(attrs).forEach(function (k) { node.setAttribute(k, attrs[k]); });
    return node;
  }

  /** Builds the badge and returns a function that draws a pose. */
  function build(host) {
    // Replaces the static fallback image the page ships for no-JS visitors.
    while (host.firstChild) host.removeChild(host.firstChild);
    var id = 'kilo-clip-' + (++uid);
    var svg = el('svg', { viewBox: '0 0 100 100', 'aria-hidden': 'true', focusable: 'false', class: 'kilo-mark' });
    var clip = el('clipPath', { id: id });
    clip.appendChild(el('rect', { width: 100, height: 100, rx: 22 }));
    svg.appendChild(clip);
    svg.appendChild(el('rect', { class: 'kilo-mark__tile', width: 100, height: 100, rx: 22 }));
    svg.appendChild(el('rect', { class: 'kilo-mark__line', x: 0.5, y: 0.5, width: 99, height: 99, rx: 21.5 }));
    var clipped = el('g', { 'clip-path': 'url(#' + id + ')' });
    var inset = (100 - 100 * GLYPH) / 2;
    var place = el('g', { transform: 'translate(' + inset + ' ' + inset + ') scale(' + GLYPH + ')' });
    var glyph = el('g', { class: 'kilo-mark__glyph' });
    glyph.appendChild(el('path', { d: BAR }));
    glyph.appendChild(el('path', { d: PLATES }));
    place.appendChild(glyph);
    clipped.appendChild(place);
    svg.appendChild(clipped);
    host.appendChild(svg);

    return function draw(pose) {
      var t = 'translate(0 ' + pose.dy.toFixed(3) + ')';
      if (pose.squash !== 1) {
        t += ' translate(' + FOOT_X + ' ' + FOOT_Y + ') scale(1 ' + pose.squash.toFixed(4) + ') translate(' + -FOOT_X + ' ' + -FOOT_Y + ')';
      }
      glyph.setAttribute('transform', t);
      glyph.style.opacity = pose.alpha < 1 ? pose.alpha.toFixed(3) : '';
    };
  }

  var calm = document.documentElement.classList.contains('calm');

  /**
   * Plays the timeline from `from` to `to` seconds (`to` = Infinity keeps
   * looping) and calls `done` at the end. Returns a stop function.
   */
  function play(draw, from, to, done) {
    var start = null;
    var raf = 0;
    function frame(now) {
      if (start === null) start = now;
      var t = from + (now - start) / 1000;
      if (t >= to) {
        draw(poseAt(to));
        if (done) done();
        return;
      }
      draw(poseAt(t));
      raf = w.requestAnimationFrame(frame);
    }
    raf = w.requestAnimationFrame(frame);
    return function () { w.cancelAnimationFrame(raf); };
  }

  function mount(host, opts) {
    opts = opts || {};
    var draw = build(host);
    var motion = calm ? 'none' : (opts.motion || 'none');
    draw(poseAt(motion === 'intro' || motion === 'loop' ? 0 : INTRO));
    if (motion === 'none') return { replay: function () {} };

    var stop = function () {};
    function intro() {
      stop();
      stop = play(draw, 0, motion === 'loop' ? Infinity : INTRO);
    }
    function rep() {
      stop();
      stop = play(draw, INTRO, INTRO + LOOP);
    }

    if (motion === 'hover') {
      var target = opts.trigger || host;
      var busy = false;
      target.addEventListener('mouseenter', function () {
        if (busy) return;
        busy = true;
        stop = play(draw, INTRO, INTRO + LOOP, function () { busy = false; });
      });
      return { replay: rep };
    }

    if (motion === 'loop' && 'IntersectionObserver' in w) {
      // Only animate while visible; start with the drop the first time.
      var started = false;
      new IntersectionObserver(function (entries) {
        var visible = entries.some(function (e) { return e.isIntersecting; });
        if (visible) {
          stop = started ? play(draw, INTRO, Infinity) : play(draw, 0, Infinity);
          started = true;
        } else {
          stop();
        }
      }).observe(host);
    } else {
      intro();
    }
    return { replay: intro };
  }

  w.KiloMark = { BAR: BAR, PLATES: PLATES, INTRO: INTRO, LOOP: LOOP, GLYPH: GLYPH, poseAt: poseAt, mount: mount };
})(window);
