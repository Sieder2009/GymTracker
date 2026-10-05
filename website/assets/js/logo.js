/*
 * The Ironpeak mark -- a two-peak mountain with a barbell across it -- and
 * its motion, ported 1:1 from mobile/lib/widgets/ironpeak_logo.dart, the
 * app's single source of truth. Same path strings, same colors, same
 * timeline (pop-in, barbell drop with Android's BounceInterpolator, glint,
 * then one rep forever), so the logo on this page moves exactly like the
 * app's launch animation.
 */
(function (global) {
  'use strict';

  var UNIT = 100;
  var GLYPH_FRACTION = 0.7; // IronpeakMark.badgeGlyphFraction

  var COLORS = {
    gradientStart: '#38D08F',
    gradientMid: '#1FA76A',
    gradientEnd: '#0B6644',
    gradientMidStop: 0.55,
    rock: '#04382A',
    snow: '#FFFFFF',
    iron: '#FFFFFF'
  };
  var BACK_PEAK_ALPHA = 0.3;
  var FRONT_PEAK_ALPHA = 0.42;
  var SHADOW_ALPHA = 0.25;

  // --- geometry (SVG path syntax, logo units) ------------------------------

  var BACK_PEAK = 'M74,24L88,82L34,82Z';
  var FRONT_PEAK = 'M42,8L66,82L14,82Z';
  var BACK_SNOW = 'M74,24L77.4,38L74.2,34.6L71,39L67.6,34.8L64.3,38Z';
  var FRONT_SNOW = 'M42,8L49.1,30L44.5,35L41,29.8L37.5,34L33.7,30Z';
  var SPARK = 'M0,-6.5Q0.9,-0.9 6.5,0Q0.9,0.9 0,6.5Q-0.9,0.9 -6.5,0Q-0.9,-0.9 0,-6.5Z';
  var SPARK_ANCHOR = [51, 13];
  var MOUNTAIN_PIVOT = [50, 82];

  var BARBELL_REST_Y = 60;
  var REP_HEIGHT = 14;
  var SHADOW_OFFSET = 1.6;

  /** Compact number for path data: no trailing zeros, no "-0". */
  function num(v) {
    var s = v.toFixed(2);
    if (s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, '');
    return s === '-0' ? '0' : s;
  }

  function rrect(x, y, w, h, r) {
    var x2 = x + w;
    var y2 = y + h;
    var arc = 'A' + num(r) + ',' + num(r) + ' 0 0 1 ';
    return 'M' + num(x + r) + ',' + num(y) +
      'H' + num(x2 - r) + arc + num(x2) + ',' + num(y + r) +
      'V' + num(y2 - r) + arc + num(x2 - r) + ',' + num(y2) +
      'H' + num(x + r) + arc + num(x) + ',' + num(y2 - r) +
      'V' + num(y + r) + arc + num(x + r) + ',' + num(y) + 'Z';
  }

  function barbell(cy) {
    return [
      rrect(20, cy - 2.7, 60, 5.4, 1.6), // bar
      rrect(15.5, cy - 19, 8, 38, 3), // big plates
      rrect(76.5, cy - 19, 8, 38, 3),
      rrect(9, cy - 12.5, 5.5, 25, 2.4), // small plates
      rrect(85.5, cy - 12.5, 5.5, 25, 2.4),
      rrect(5, cy - 3.4, 4.6, 6.8, 1.6), // sleeve ends
      rrect(90.4, cy - 3.4, 4.6, 6.8, 1.6)
    ].join('');
  }

  var BARBELL = barbell(BARBELL_REST_Y);
  var BARBELL_SHADOW = barbell(BARBELL_REST_Y + SHADOW_OFFSET);

  // --- motion --------------------------------------------------------------

  var INTRO_SECONDS = 0.64;
  var LOOP_SECONDS = 3.0;
  var DROP_FROM = 44;
  var DROP_START = 0.08;
  var DROP_SECONDS = 0.52;
  var IMPACT_SECONDS = DROP_START + DROP_SECONDS * (0.3535 / 1.1226);

  /** Flutter's Cubic curve, including its bisection solver and error bound. */
  function cubic(a, b, c, d) {
    function evaluate(p, q, m) {
      return 3 * p * (1 - m) * (1 - m) * m + 3 * q * (1 - m) * m * m + m * m * m;
    }
    return function (t) {
      if (t <= 0) return 0;
      if (t >= 1) return 1;
      var start = 0;
      var end = 1;
      for (;;) {
        var mid = (start + end) / 2;
        var estimate = evaluate(a, c, mid);
        if (Math.abs(t - estimate) < 0.001) return evaluate(b, d, mid);
        if (estimate < t) start = mid; else end = mid;
      }
    };
  }

  var fastOutSlowIn = cubic(0.4, 0.0, 0.2, 1.0);
  var easeInOutCubic = cubic(0.645, 0.045, 0.355, 1.0);

  function seg(t, start, seconds) {
    return Math.min(1, Math.max(0, (t - start) / seconds));
  }
  function decel(x) { return 1 - (1 - x) * (1 - x); }
  function accel(x) { return x * x; }

  /** android.view.animation.BounceInterpolator, verbatim. */
  function androidBounce(t) {
    function bounce(x) { return x * x * 8; }
    var x = t * 1.1226;
    if (x < 0.3535) return bounce(x);
    if (x < 0.7408) return bounce(x - 0.54719) + 0.7;
    if (x < 0.9644) return bounce(x - 0.8526) + 0.9;
    return bounce(x - 1.0435) + 0.95;
  }

  function pose(p) {
    return {
      mountainAlpha: p.mountainAlpha === undefined ? 1 : p.mountainAlpha,
      mountainScale: p.mountainScale === undefined ? 1 : p.mountainScale,
      mountainSquash: p.mountainSquash === undefined ? 1 : p.mountainSquash,
      barbellDy: p.barbellDy || 0,
      barbellAlpha: p.barbellAlpha === undefined ? 1 : p.barbellAlpha,
      sparkScale: p.sparkScale || 0,
      sparkTurn: p.sparkTurn || 0
    };
  }

  var REST = pose({});

  function intro(t) {
    var pop = seg(t, 0, 0.24);
    var fade = seg(t, 0, 0.18);
    var drop = seg(t, DROP_START, DROP_SECONDS);

    var squashDown = seg(t, IMPACT_SECONDS, 0.07);
    var squashUp = seg(t, IMPACT_SECONDS + 0.07, 0.12);
    var squash = 1 - 0.045 * decel(squashDown) * (1 - decel(squashUp));

    var glintUp = seg(t, 0.26, 0.14);
    var glintDown = seg(t, 0.40, 0.24);

    return pose({
      mountainAlpha: fastOutSlowIn(fade),
      mountainScale: 0.86 + 0.14 * fastOutSlowIn(pop),
      mountainSquash: squash,
      barbellDy: -DROP_FROM * (1 - androidBounce(drop)),
      barbellAlpha: seg(t, DROP_START, 0.08),
      sparkScale: 1.15 * decel(glintUp) * (1 - accel(glintDown)),
      sparkTurn: seg(t, 0.26, 0.38) * Math.PI / 2
    });
  }

  function loop(u) {
    var up = easeInOutCubic(seg(u, 0.55, 0.70));
    var down = easeInOutCubic(seg(u, 1.65, 0.65));
    var land = seg(u, 2.30, 0.30);
    var glint = seg(u, 1.20, 0.50);
    return pose({
      barbellDy: -REP_HEIGHT * (up - down),
      mountainSquash: 1 - 0.02 * Math.sin(Math.PI * land),
      sparkScale: Math.sin(Math.PI * glint),
      sparkTurn: glint * Math.PI / 2
    });
  }

  /** The pose at [seconds] since the logo appeared; repeats past the intro. */
  function poseAt(seconds) {
    if (seconds < INTRO_SECONDS) return intro(seconds);
    return loop((seconds - INTRO_SECONDS) % LOOP_SECONDS);
  }

  // --- SVG renderer ---------------------------------------------------------

  var SVG_NS = 'http://www.w3.org/2000/svg';
  var uid = 0;

  function node(name, attrs, parent) {
    var el = document.createElementNS(SVG_NS, name);
    for (var key in attrs) el.setAttribute(key, attrs[key]);
    if (parent) parent.appendChild(el);
    return el;
  }

  /**
   * Builds the badge + glyph inside [svg] and returns render(pose).
   * opts.badge: false draws the glyph alone on a transparent background.
   */
  function mount(svg, opts) {
    opts = opts || {};
    var badge = opts.badge !== false;
    var fraction = opts.glyphFraction || GLYPH_FRACTION;
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    svg.setAttribute('viewBox', '0 0 100 100');

    if (badge) {
      var id = 'ip-badge-' + (++uid);
      var defs = node('defs', {}, svg);
      var grad = node('linearGradient', { id: id, x1: '0', y1: '0', x2: '1', y2: '1' }, defs);
      node('stop', { offset: '0', 'stop-color': COLORS.gradientStart }, grad);
      node('stop', { offset: String(COLORS.gradientMidStop), 'stop-color': COLORS.gradientMid }, grad);
      node('stop', { offset: '1', 'stop-color': COLORS.gradientEnd }, grad);
      node('rect', { width: '100', height: '100', rx: '22', fill: 'url(#' + id + ')' }, svg);
    }

    var inset = 100 * (1 - fraction) / 2;
    var glyph = node('g', { transform: 'translate(' + inset + ' ' + inset + ') scale(' + (fraction * 100 / UNIT) + ')' }, svg);

    var mountain = node('g', {}, glyph);
    var backPeak = node('path', { d: BACK_PEAK, fill: COLORS.rock }, mountain);
    var frontPeak = node('path', { d: FRONT_PEAK, fill: COLORS.rock }, mountain);
    var backSnow = node('path', { d: BACK_SNOW, fill: COLORS.snow }, mountain);
    var frontSnow = node('path', { d: FRONT_SNOW, fill: COLORS.snow }, mountain);

    var bar = node('g', {}, glyph);
    var barShadow = node('path', { d: BARBELL_SHADOW, fill: '#000' }, bar);
    var barBody = node('path', { d: BARBELL, fill: COLORS.iron }, bar);

    var spark = node('g', {}, glyph);
    node('path', { d: SPARK, fill: COLORS.snow }, spark);

    function render(p) {
      var px = MOUNTAIN_PIVOT[0];
      var py = MOUNTAIN_PIVOT[1];
      var sx = p.mountainScale;
      var sy = p.mountainScale * p.mountainSquash;
      mountain.setAttribute('transform',
        'translate(' + px + ' ' + py + ') scale(' + sx + ' ' + sy + ') translate(' + (-px) + ' ' + (-py) + ')');
      var ma = p.mountainAlpha;
      backPeak.setAttribute('fill-opacity', BACK_PEAK_ALPHA * ma);
      frontPeak.setAttribute('fill-opacity', FRONT_PEAK_ALPHA * ma);
      backSnow.setAttribute('fill-opacity', 0.9 * ma);
      frontSnow.setAttribute('fill-opacity', ma);

      bar.setAttribute('transform', 'translate(0 ' + p.barbellDy + ')');
      barShadow.setAttribute('fill-opacity', SHADOW_ALPHA * p.barbellAlpha);
      barBody.setAttribute('fill-opacity', p.barbellAlpha);

      if (p.sparkScale > 0.001) {
        spark.setAttribute('transform', 'translate(' + SPARK_ANCHOR[0] + ' ' + SPARK_ANCHOR[1] + ') rotate(' +
          (p.sparkTurn * 180 / Math.PI) + ') scale(' + p.sparkScale + ')');
        spark.removeAttribute('display');
      } else {
        spark.setAttribute('display', 'none');
      }
    }

    render(REST);
    return render;
  }

  // --- canvas renderer (favicon) -------------------------------------------

  var paths = null;
  function canvasPaths() {
    if (!paths) {
      paths = {
        backPeak: new Path2D(BACK_PEAK),
        frontPeak: new Path2D(FRONT_PEAK),
        backSnow: new Path2D(BACK_SNOW),
        frontSnow: new Path2D(FRONT_SNOW),
        barbell: new Path2D(BARBELL),
        barbellShadow: new Path2D(BARBELL_SHADOW)
      };
    }
    return paths;
  }

  /** Paints the rounded badge with the barbell lifted by [barbellDy] units. */
  function paintCanvas(ctx, size, barbellDy) {
    var p = canvasPaths();
    ctx.clearRect(0, 0, size, size);
    var grad = ctx.createLinearGradient(0, 0, size, size);
    grad.addColorStop(0, COLORS.gradientStart);
    grad.addColorStop(COLORS.gradientMidStop, COLORS.gradientMid);
    grad.addColorStop(1, COLORS.gradientEnd);
    ctx.fillStyle = grad;
    var r = size * 0.22;
    ctx.beginPath();
    ctx.moveTo(r, 0);
    ctx.arcTo(size, 0, size, size, r);
    ctx.arcTo(size, size, 0, size, r);
    ctx.arcTo(0, size, 0, 0, r);
    ctx.arcTo(0, 0, size, 0, r);
    ctx.closePath();
    ctx.fill();

    ctx.save();
    var inset = size * (1 - GLYPH_FRACTION) / 2;
    ctx.translate(inset, inset);
    ctx.scale(size * GLYPH_FRACTION / UNIT, size * GLYPH_FRACTION / UNIT);
    ctx.fillStyle = 'rgba(4,56,42,' + BACK_PEAK_ALPHA + ')';
    ctx.fill(p.backPeak);
    ctx.fillStyle = 'rgba(4,56,42,' + FRONT_PEAK_ALPHA + ')';
    ctx.fill(p.frontPeak);
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.fill(p.backSnow);
    ctx.fillStyle = '#fff';
    ctx.fill(p.frontSnow);
    ctx.translate(0, barbellDy);
    ctx.fillStyle = 'rgba(0,0,0,' + SHADOW_ALPHA + ')';
    ctx.fill(p.barbellShadow);
    ctx.fillStyle = '#fff';
    ctx.fill(p.barbell);
    ctx.restore();
  }

  global.IronpeakMark = {
    INTRO_SECONDS: INTRO_SECONDS,
    LOOP_SECONDS: LOOP_SECONDS,
    REP_HEIGHT: REP_HEIGHT,
    SPARK: SPARK,
    REST: REST,
    poseAt: poseAt,
    mount: mount,
    paintCanvas: paintCanvas
  };
})(window);
