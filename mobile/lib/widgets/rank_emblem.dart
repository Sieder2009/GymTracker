import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/lift_rank.dart';
import '../l10n/app_localizations.dart';

/// "Hero II", "Olympian" -- a rank's name with its division numeral.
String rankLabel(AppLocalizations t, RankTier tier, int? division) {
  final name = switch (tier) {
    RankTier.iron => t.rankIron,
    RankTier.bronze => t.rankBronze,
    RankTier.silver => t.rankSilver,
    RankTier.gold => t.rankGold,
    RankTier.platinum => t.rankPlatinum,
    RankTier.diamond => t.rankDiamond,
    RankTier.champion => t.rankChampion,
  };
  return division == null ? name : '$name ${'III'.substring(0, division)}';
}

/// A rank's badge, drawn (no image assets) in the style of game ranks, and
/// alive: a framed, brilliant-cut crystal with the rank's symbol in it -- a
/// skull (Mortal), crossed axes (Warrior), a Corinthian helmet (Spartan), a
/// Greek hero (Hero), Hermes' winged helmet (Demigod), Atlas carrying the
/// heavens (Titan) and Zeus himself (Olympian). The division shows as one to
/// three lit gems (III one, I three).
///
/// The higher the rank, the more there is: blades, rays, a crown, wings and
/// a halo, rising embers, and for Olympian the grandest of each. A light
/// sweep runs over the badge now and then, the glow breathes, rays turn and
/// sparks twinkle -- from one repeating clock, only at [animated] sizes and
/// never when the OS asks to remove animations.
class RankEmblem extends StatefulWidget {
  const RankEmblem({
    super.key,
    required this.tier,
    this.division,
    this.size = 56,
    this.semanticsLabel,
    this.animated,
  });

  final RankTier tier;
  final int? division;
  final double size;
  final String? semanticsLabel;

  /// Whether the badge moves; by default only from 48 logical pixels up --
  /// at list size the motion is noise.
  final bool? animated;

  @override
  State<RankEmblem> createState() => _RankEmblemState();
}

class _RankEmblemState extends State<RankEmblem> with SingleTickerProviderStateMixin {
  static const Duration _cycle = Duration(milliseconds: 4200);

  late final AnimationController _clock = AnimationController(vsync: this, duration: _cycle, value: 0.62);

  bool get _wantsMotion => widget.animated ?? widget.size >= 48;

  void _sync() {
    final move = _wantsMotion && !MediaQuery.disableAnimationsOf(context);
    if (move && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!move && _clock.isAnimating) {
      _clock
        ..stop()
        ..value = 0.62; // a resting frame: no sweep, glow in the middle
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant RankEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _EmblemPainter(
            tier: widget.tier,
            division: widget.division,
            clock: _clock,
          ),
        ),
      ),
    );
  }
}

/// One rank's palette.
class _Palette {
  const _Palette({
    required this.light,
    required this.base,
    required this.dark,
    required this.glow,
    required this.plateTop,
    required this.plateBottom,
    required this.ink,
  });

  /// The metal: highlight, body and shadow.
  final Color light;
  final Color base;
  final Color dark;

  /// Aura, rays, sparks and the symbol's glow.
  final Color glow;

  /// The inset plate (or enamel face) the symbol sits on.
  final Color plateTop;
  final Color plateBottom;

  /// The symbol's brightest colour.
  final Color ink;
}

const List<_Palette> _kPalettes = [
  // Mortal: steel.
  _Palette(
      light: Color(0xFFF2F5F8),
      base: Color(0xFF8E98A5),
      dark: Color(0xFF262C34),
      glow: Color(0xFF9FB6CF),
      plateTop: Color(0xFF2E3640),
      plateBottom: Color(0xFF0C0F13),
      ink: Color(0xFFE8F1FB)),
  // Warrior: bronze.
  _Palette(
      light: Color(0xFFFFE0C2),
      base: Color(0xFFC77A3E),
      dark: Color(0xFF3F1D06),
      glow: Color(0xFFFF8A3D),
      plateTop: Color(0xFF4A2410),
      plateBottom: Color(0xFF140803),
      ink: Color(0xFFFFE6CC)),
  // Spartan: silver on crimson.
  _Palette(
      light: Color(0xFFFFFFFF),
      base: Color(0xFFAEB9C6),
      dark: Color(0xFF323C48),
      glow: Color(0xFFFF4757),
      plateTop: Color(0xFF8E1220),
      plateBottom: Color(0xFF2A040A),
      ink: Color(0xFFFFE2B8)),
  // Hero: gold on royal blue.
  _Palette(
      light: Color(0xFFFFF7D1),
      base: Color(0xFFE9AE1C),
      dark: Color(0xFF5E3A00),
      glow: Color(0xFFFFC83D),
      plateTop: Color(0xFF2448B8),
      plateBottom: Color(0xFF081340),
      ink: Color(0xFFFFF1B0)),
  // Demigod: teal crystal.
  _Palette(
      light: Color(0xFFE2FFFB),
      base: Color(0xFF34CDB9),
      dark: Color(0xFF033F39),
      glow: Color(0xFF2EF2D0),
      plateTop: Color(0xFF0E5A53),
      plateBottom: Color(0xFF021C19),
      ink: Color(0xFFDDFFF9)),
  // Titan: violet crystal.
  _Palette(
      light: Color(0xFFF0EAFF),
      base: Color(0xFF8E6BFF),
      dark: Color(0xFF1E0D57),
      glow: Color(0xFFA585FF),
      plateTop: Color(0xFF41219A),
      plateBottom: Color(0xFF100530),
      ink: Color(0xFFF1EBFF)),
  // Olympian: gold with Zeus' electric blue.
  _Palette(
      light: Color(0xFFFFF9DE),
      base: Color(0xFFF2B320),
      dark: Color(0xFF5C3300),
      glow: Color(0xFFFFD34D),
      plateTop: Color(0xFF16296B),
      plateBottom: Color(0xFF040920),
      ink: Color(0xFF9BE6FF)),
];

/// How much of each ornament a rank gets, by level 0 (Mortal) to 6.
const List<int> _kBladePairs = [0, 1, 2, 2, 2, 3, 3];
const List<double> _kWingScale = [0, 0, 0, 0, 0.82, 1.0, 1.14];
const List<int> _kCrownSpikes = [0, 0, 0, 3, 3, 5, 5];
const List<int> _kRays = [0, 0, 8, 10, 12, 14, 18];

/// The colour an accent of a symbol is painted in, from the rank's palette.
enum _Tint {
  /// The badge's metal.
  metal,

  /// The rank's glow colour, with a halo.
  glow,

  /// The glow colour lightened, for an accent on a plate of the same hue.
  paleGlow,

  /// White fading into the symbol's brightest colour, with a halo.
  ink,

  /// Old ivory -- bone or marble -- the same in every rank.
  bone,
}

/// A symbol in its own coordinates: the outline (holes cut out), accents
/// painted in a second colour, facets in shade, light patches, dark engraved
/// lines and bright glints.
class _Symbol {
  _Symbol(this.fill, {this.accents = const [], this.shade = const [], this.lights = const [], this.lines, this.glints});

  final Path fill;
  final List<(_Tint, Path)> accents;
  final List<Path> shade;
  final List<Path> lights;
  final Path? lines;
  final Path? glints;

  _Symbol transformed(Matrix4 m) => _Symbol(
        fill.transform(m.storage),
        accents: [for (final (tint, p) in accents) (tint, p.transform(m.storage))],
        shade: [for (final p in shade) p.transform(m.storage)],
        lights: [for (final p in lights) p.transform(m.storage)],
        lines: lines?.transform(m.storage),
        glints: glints?.transform(m.storage),
      );

  static _Symbol union(_Symbol a, _Symbol b) => _Symbol(
        Path.combine(PathOperation.union, a.fill, b.fill),
        accents: [...a.accents, ...b.accents],
        shade: [...a.shade, ...b.shade],
        lights: [...a.lights, ...b.lights],
        lines: _merge(a.lines, b.lines),
        glints: _merge(a.glints, b.glints),
      );

  static Path? _merge(Path? a, Path? b) {
    if (a == null) return b;
    if (b == null) return a;
    return Path()
      ..addPath(a, Offset.zero)
      ..addPath(b, Offset.zero);
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter({required this.tier, required this.division, required this.clock}) : super(repaint: clock);

  final RankTier tier;
  final int? division;
  final Animation<double> clock;

  int get level => tier.index;
  _Palette get p => _kPalettes[level];

  /// Lit division marks: one for III, two for II, three for I and the top.
  int get lit => division == null ? 3 : 4 - division!;

  static const Offset _center = Offset(50, 52);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    // Everything is drawn on a 100 x 100 grid (blur radii included: the
    // mask filters scale with the canvas), and nothing spills past it.
    canvas.save();
    canvas.scale(size.width / 100);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 100, 100));
    final breathe = 0.78 + 0.22 * math.sin(t * 2 * math.pi);
    _paintBadge(canvas, t, breathe);
    canvas.restore();
  }

  // ===========================================================================
  // The badge
  // ===========================================================================

  void _paintBadge(Canvas canvas, double t, double breathe) {
    if (level >= 1) _paintAura(canvas, breathe);
    if (_kRays[level] > 0) _paintRays(canvas, t);
    if (level >= 4) _paintHalo(canvas, t, 45);
    if (_kWingScale[level] > 0) _paintWings(canvas, _kWingScale[level]);
    for (var k = 0; k < _kBladePairs[level]; k++) {
      _paintBlade(canvas, k);
    }
    if (_kCrownSpikes[level] > 0) _paintCrown(canvas, _kCrownSpikes[level], baseY: 17);

    // An angular frame around the crystal: chrome, an inlaid line of light
    // and a gem set in each shoulder.
    final frame = _poly(const [
      Offset(50, 8),
      Offset(78, 28),
      Offset(74, 68),
      Offset(50, 93),
      Offset(26, 68),
      Offset(22, 28),
    ]);
    canvas.drawShadow(frame, Colors.black, 3, false);
    _paintMetalPart(canvas, frame, edge: 1.3);
    final inlay = _scaled(frame, const Offset(50, 50), 0.92);
    _stroke(canvas, inlay, p.glow.withValues(alpha: 0.35 + 0.35 * breathe), 0.9);
    final inner = _scaled(frame, const Offset(50, 50), 0.84);
    canvas.drawPath(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.plateTop, p.plateBottom],
        ).createShader(inner.getBounds()),
    );
    _stroke(canvas, inner, Colors.black.withValues(alpha: 0.55), 1);
    for (final at in const [Offset(23.5, 29), Offset(76.5, 29)]) {
      _paintShard(canvas, at, 3.2, lit: true, breathe: breathe, tall: false);
    }

    const c = Offset(50, 45);
    final r = 21.0 + level * 0.8;
    _paintCrystal(canvas, c, r, t, breathe);

    _paintSymbol(canvas, _symbol(), Rect.fromCenter(center: c, width: r * 1.3, height: r * 1.3), breathe);
    _paintSweep(canvas, _regular(c, r, 6), t);
    _paintGlint(canvas, c, r, t);
    // Division: one to three small crystals under the big one.
    for (var i = 0; i < 3; i++) {
      _paintShard(canvas, Offset(40 + i * 10.0, 76.5), 4.6, lit: i < lit, breathe: breathe, tall: true);
    }
    _paintSweep(canvas, frame, (t + 0.08) % 1);
    if (level >= 2) _paintFloatingShards(canvas, t, breathe);
    if (level >= 4) _paintSparks(canvas, t);
    if (level >= 5) _paintEmbers(canvas, t);
  }

  /// A brilliant-cut hexagon: a deep body, a light core breathing behind
  /// the symbol, facets lit or shaded by where they face (light comes from
  /// the upper left), and edges catching the light the same way.
  void _paintCrystal(Canvas canvas, Offset c, double r, double t, double breathe) {
    final crystal = _regular(c, r, 6);
    canvas.drawPath(
      crystal,
      Paint()
        ..color = p.glow.withValues(alpha: 0.75 * breathe)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + level * 0.5),
    );
    canvas.drawPath(
      crystal,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(p.plateTop, p.glow, 0.55)!, p.plateTop, p.plateBottom],
          stops: const [0, 0.45, 1],
        ).createShader(crystal.getBounds()),
    );
    canvas.save();
    canvas.clipPath(crystal);
    canvas.drawCircle(
      c,
      r * 0.8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35 * breathe),
            p.glow.withValues(alpha: 0.35 * breathe),
            p.glow.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.8)),
    );
    canvas.restore();

    const light = Offset(-0.62, -0.78);
    final vertices = [
      for (var k = 0; k < 6; k++)
        c + Offset(math.cos(-math.pi / 2 + k * math.pi / 3), math.sin(-math.pi / 2 + k * math.pi / 3)) * r,
    ];
    final table = [for (final v in vertices) c + (v - c) * 0.5];
    for (var k = 0; k < 6; k++) {
      final a = vertices[k];
      final b = vertices[(k + 1) % 6];
      final mid = (a + b) / 2;
      final facing = (mid - c) / r;
      final lit = facing.dx * light.dx + facing.dy * light.dy;
      // Two star facets per side, meeting at the side's midpoint.
      for (final (from, to) in [(a, table[k]), (b, table[(k + 1) % 6])]) {
        final facet = _poly([from, mid, to]);
        canvas.drawPath(
          facet,
          Paint()
            ..color =
                lit > 0 ? Colors.white.withValues(alpha: 0.24 * lit) : Colors.black.withValues(alpha: 0.32 * -lit),
        );
      }
      final kite = _poly([table[k], mid, table[(k + 1) % 6]]);
      canvas.drawPath(kite, Paint()..color = Colors.black.withValues(alpha: 0.12));
      _stroke(
          canvas,
          Path()
            ..moveTo(table[k].dx, table[k].dy)
            ..lineTo(mid.dx, mid.dy)
            ..lineTo(table[(k + 1) % 6].dx, table[(k + 1) % 6].dy),
          Colors.white.withValues(alpha: 0.22),
          0.5);
      // The edge itself: bright where it faces the light, dark where not.
      _stroke(
        canvas,
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy),
        lit > 0 ? Colors.white.withValues(alpha: 0.55 + 0.4 * lit) : Colors.black.withValues(alpha: 0.35 * -lit),
        1.2,
      );
    }
    final tablePath = _poly(table);
    canvas.drawPath(tablePath, Paint()..color = Colors.black.withValues(alpha: 0.22));
    _stroke(canvas, tablePath, Colors.white.withValues(alpha: 0.3), 0.6);
  }

  /// A star of light that runs along the crystal's upper-left edges once per
  /// cycle, just after the sweep.
  void _paintGlint(Canvas canvas, Offset c, double r, double t) {
    const start = 0.36;
    const span = 0.24;
    if (t < start || t > start + span) return;
    final u = (t - start) / span;
    // From the lower-left corner over the top-left one to the top.
    final corners = [
      c + Offset(math.cos(-math.pi / 2 + 4 * math.pi / 3), math.sin(-math.pi / 2 + 4 * math.pi / 3)) * r,
      c + Offset(math.cos(-math.pi / 2 + 5 * math.pi / 3), math.sin(-math.pi / 2 + 5 * math.pi / 3)) * r,
      c + Offset(0, -r),
    ];
    final at =
        u < 0.5 ? Offset.lerp(corners[0], corners[1], u * 2)! : Offset.lerp(corners[1], corners[2], (u - 0.5) * 2)!;
    final size = 3.6 * math.sin(u * math.pi) + 0.6;
    canvas.drawCircle(
        at,
        size * 1.3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
    canvas.drawPath(_star(at, size, size * 0.18, 4), Paint()..color = Colors.white);
  }

  /// A small crystal: a lit, glowing one or an empty dark socket.
  void _paintShard(Canvas canvas, Offset c, double r,
      {required bool lit, required double breathe, required bool tall}) {
    final w = r * (tall ? 0.62 : 0.85);
    final shard =
        _poly([Offset(c.dx, c.dy - r), Offset(c.dx + w, c.dy), Offset(c.dx, c.dy + r), Offset(c.dx - w, c.dy)]);
    if (!lit) {
      canvas.drawPath(shard, Paint()..color = Colors.black.withValues(alpha: 0.6));
      _stroke(canvas, shard, p.light.withValues(alpha: 0.3), 0.6);
      return;
    }
    canvas.drawCircle(
        c,
        r * 1.4,
        Paint()
          ..color = p.glow.withValues(alpha: 0.6 * breathe)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(
      shard,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, p.glow, Color.lerp(p.glow, Colors.black, 0.5)!],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // The left half catches the light.
    canvas.drawPath(_poly([Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), Offset(c.dx - w, c.dy)]),
        Paint()..color = Colors.white.withValues(alpha: 0.25));
    _stroke(canvas, shard, Colors.black.withValues(alpha: 0.45), 0.5);
  }

  /// Crystal shards floating round the badge, bobbing gently -- more of them
  /// the higher the rank.
  void _paintFloatingShards(Canvas canvas, double t, double breathe) {
    final spots = <(Offset, double, double)>[
      (const Offset(13, 80), 4.6, 0.0),
      (const Offset(87, 80), 4.6, 0.5),
      if (level >= 4) ...[(const Offset(7, 58), 3.6, 0.25), (const Offset(93, 58), 3.6, 0.75)],
      if (level >= 6) ...[(const Offset(18, 9), 3.4, 0.12), (const Offset(82, 9), 3.4, 0.62)],
    ];
    for (final (at, r, phase) in spots) {
      final bob = math.sin((t + phase) * 2 * math.pi) * 1.8;
      _paintShard(canvas, at + Offset(0, bob), r, lit: true, breathe: breathe, tall: true);
    }
  }

  // ===========================================================================
  // Shared ornaments
  // ===========================================================================

  static Path _poly(List<Offset> points) => Path()..addPolygon(points, true);

  static Path _scaled(Path path, Offset c, double s) {
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    return path.transform(m.storage);
  }

  static Path _regular(Offset c, double r, int n) {
    final path = Path();
    for (var k = 0; k < n; k++) {
      final a = -math.pi / 2 + k * 2 * math.pi / n;
      final q = c + Offset(math.cos(a), math.sin(a)) * r;
      k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }

  static Path _star(Offset c, double outer, double inner, int n) {
    final path = Path();
    for (var k = 0; k < n * 2; k++) {
      final a = -math.pi / 2 + k * math.pi / n;
      final q = c + Offset(math.cos(a), math.sin(a)) * (k.isEven ? outer : inner);
      k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }

  static void _stroke(Canvas canvas, Path path, Color color, double width) => canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color,
      );

  /// Polished metal: bands of light and shadow across the surface the way a
  /// chrome finish reflects its surroundings.
  Shader _chrome(Rect r) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.light, p.base, p.dark, Color.lerp(p.base, p.light, 0.75)!, p.base, p.dark],
        stops: const [0, 0.28, 0.47, 0.55, 0.74, 1],
      ).createShader(r);

  /// A metal part: chrome body, a light upper-left edge, a dark outline.
  void _paintMetalPart(Canvas canvas, Path path, {double edge = 1}) {
    final b = path.getBounds();
    canvas.drawPath(path, Paint()..shader = _chrome(b));
    _stroke(canvas, path, const Color(0x8C000000), 1.4 * edge);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7 * edge
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0)],
        ).createShader(b),
    );
  }

  void _paintAura(Canvas canvas, double breathe) {
    final strength = (0.18 + level * 0.06) * breathe;
    canvas.drawCircle(
      _center,
      50,
      Paint()
        ..shader = RadialGradient(
          colors: [p.glow.withValues(alpha: strength), p.glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: _center, radius: 50)),
    );
  }

  void _paintRays(Canvas canvas, double t) {
    final n = _kRays[level];
    final turn = t * 2 * math.pi / n; // one ray step per cycle: slow and calm
    final path = Path();
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + turn + i * 2 * math.pi / n;
      final half = math.pi / n * (i.isEven ? 0.34 : 0.2);
      final reach = i.isEven ? 52.0 : 40.0;
      path
        ..moveTo(_center.dx, _center.dy)
        ..lineTo(_center.dx + math.cos(a - half) * reach, _center.dy + math.sin(a - half) * reach)
        ..lineTo(_center.dx + math.cos(a + half) * reach, _center.dy + math.sin(a + half) * reach)
        ..close();
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [p.glow.withValues(alpha: 0.5), p.glow.withValues(alpha: 0)],
          stops: const [0.2, 1],
        ).createShader(Rect.fromCircle(center: _center, radius: 52)),
    );
  }

  /// A thin ring of light with dashes travelling round it.
  void _paintHalo(Canvas canvas, double t, double r) {
    canvas.drawCircle(
      _center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = p.glow.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(p.glow, Colors.white, 0.55)!;
    final rect = Rect.fromCircle(center: _center, radius: r);
    const n = 12;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, t * 2 * math.pi / 3 + i * 2 * math.pi / n, math.pi / n * 1.1, false, dash);
    }
  }

  /// Swept wings: two layers of curved blade feathers, the upper ones
  /// longest.
  void _paintWings(Canvas canvas, double scale) {
    const feathers = [(218.0, 36.0), (199.0, 35.0), (181.0, 30.0), (164.0, 23.0)];
    const root = Offset(31, 45);
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(100, 0);
        canvas.scale(-1, 1);
      }
      for (final back in [true, false]) {
        for (final (i, (deg, len)) in feathers.indexed) {
          final a = (deg + (back ? 9 : 0)) * math.pi / 180;
          final l = (len + (back ? 3 : 0)) * scale;
          final d = Offset(math.cos(a), math.sin(a));
          final n = Offset(-d.dy, d.dx);
          final r = root + Offset(0, i * 3.0);
          final tip = r + d * l;
          final w = l * 0.17;
          final blade = Path()
            ..moveTo(r.dx, r.dy)
            ..quadraticBezierTo(
                r.dx + d.dx * l * 0.45 + n.dx * w * 2, r.dy + d.dy * l * 0.45 + n.dy * w * 2, tip.dx, tip.dy)
            ..quadraticBezierTo(r.dx + d.dx * l * 0.5 - n.dx * w, r.dy + d.dy * l * 0.5 - n.dy * w, r.dx, r.dy)
            ..close();
          if (back) {
            canvas.drawPath(
              blade,
              Paint()
                ..shader = LinearGradient(colors: [p.dark, Color.lerp(p.dark, p.base, 0.45)!])
                    .createShader(Rect.fromPoints(r, tip)),
            );
            _stroke(canvas, blade, p.glow.withValues(alpha: 0.4), 0.6);
          } else {
            _paintMetalPart(canvas, blade, edge: 0.7);
          }
        }
      }
      canvas.restore();
    }
  }

  /// One pair of angular blades along the sides.
  void _paintBlade(Canvas canvas, int k) {
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(100, 0);
        canvas.scale(-1, 1);
      }
      final y = 34.0 + k * 14;
      final blade = Path()
        ..moveTo(29, y)
        ..quadraticBezierTo(18, y - 4, 9 - k * 1.5, y - 9 + k * 3)
        ..quadraticBezierTo(17, y + 6, 27, y + 11)
        ..close();
      _paintMetalPart(canvas, blade, edge: 0.8);
      canvas.restore();
    }
  }

  /// Crown spikes standing on [baseY], a gem on each tip for the top rank.
  void _paintCrown(Canvas canvas, int spikes, {required double baseY}) {
    final heights = spikes == 3 ? const [11.0, 17.0, 11.0] : const [7.0, 12.0, 18.0, 12.0, 7.0];
    final spacing = spikes == 3 ? 10.0 : 8.5;
    for (var i = 0; i < spikes; i++) {
      final x = 50 + (i - (spikes - 1) / 2) * spacing;
      final h = heights[i];
      _paintMetalPart(canvas, _poly([Offset(x - 4.5, baseY), Offset(x, baseY - h), Offset(x + 4.5, baseY)]), edge: 0.8);
      if (level == 6) {
        final tip = Offset(x, baseY - h + 1.5);
        canvas.drawCircle(
            tip,
            2.6,
            Paint()
              ..color = const Color(0xFFFF3B6B).withValues(alpha: 0.6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
        canvas.drawCircle(tip, 1.7, Paint()..color = const Color(0xFFFF5C84));
        canvas.drawCircle(tip + const Offset(-0.5, -0.5), 0.6, Paint()..color = Colors.white);
      }
    }
  }

  /// A band of light that crosses [shape] once per cycle, then rests.
  void _paintSweep(Canvas canvas, Path shape, double t) {
    const span = 0.32;
    if (t > span) return;
    final x = -30 + (t / span) * 160;
    canvas.save();
    canvas.clipPath(shape);
    final band = Path()
      ..moveTo(x, 0)
      ..lineTo(x + 14, 0)
      ..lineTo(x - 16, 100)
      ..lineTo(x - 30, 100)
      ..close();
    canvas.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0)
          ],
        ).createShader(Rect.fromLTRB(x - 30, 0, x + 14, 100)),
    );
    canvas.restore();
  }

  void _paintSparks(Canvas canvas, double t) {
    const spots = [
      (Offset(13, 20), 0.0),
      (Offset(88, 16), 0.37),
      (Offset(8, 72), 0.7),
      (Offset(92, 70), 0.18),
      (Offset(50, 3), 0.55)
    ];
    for (final (c, phase) in spots) {
      final v = math.sin(((t + phase) % 1) * math.pi);
      final r = 1.2 + 3.2 * v * v * v;
      if (r < 1.4) continue;
      canvas.drawPath(_star(c, r, r * 0.2, 4), Paint()..color = Colors.white.withValues(alpha: 0.95));
      canvas.drawCircle(
          c,
          r * 0.9,
          Paint()
            ..color = p.glow.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    }
  }

  void _paintEmbers(Canvas canvas, double t) {
    const seeds = [(30.0, 0.0), (40.0, 0.43), (60.0, 0.21), (70.0, 0.66), (50.0, 0.85), (35.0, 0.58), (65.0, 0.33)];
    for (final (x, phase) in seeds) {
      final u = (t + phase) % 1;
      final c = Offset(x + math.sin((u + phase) * 2 * math.pi) * 3, 96 - u * 46);
      final alpha = math.sin(u * math.pi);
      canvas.drawCircle(
          c,
          1.9,
          Paint()
            ..color = p.glow.withValues(alpha: 0.55 * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2));
      canvas.drawCircle(c, 0.8, Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha));
    }
  }

  // ===========================================================================
  // Symbols
  // ===========================================================================

  _Symbol _symbol() => switch (level) {
        0 => _skull(),
        1 => _crossedAxes(),
        2 => _spartanHelmet(),
        3 => _hero(),
        4 => _wingedHelmet(),
        5 => _atlas(),
        _ => _zeus(),
      };

  /// Spartan: a Corinthian helmet in profile -- almond eye, nose guard,
  /// cheek guard and flared neck -- under a great crimson horsehair crest.
  static _Symbol _spartanHelmet() {
    final shell = Path()
      ..moveTo(26, 46)
      ..cubicTo(26, 30, 40, 23, 54, 23)
      ..cubicTo(70, 23, 79, 35, 79, 52)
      ..lineTo(78, 64)
      ..quadraticBezierTo(79, 74, 88, 80)
      ..lineTo(86, 85)
      ..quadraticBezierTo(71, 84, 62, 77)
      ..quadraticBezierTo(52, 84, 36, 90)
      ..lineTo(34, 73)
      ..lineTo(26, 71)
      ..lineTo(25, 52)
      ..close();
    // The eye and the slit down between nose guard and cheek guard.
    final opening = Path.combine(
      PathOperation.union,
      Path()
        ..moveTo(29, 51)
        ..quadraticBezierTo(39, 45.5, 49, 50.5)
        ..quadraticBezierTo(39, 55.5, 29, 51)
        ..close(),
      _poly(const [Offset(30, 52), Offset(33.5, 52), Offset(34, 76), Offset(30.5, 76)]),
    );
    final helmet = Path.combine(PathOperation.difference, shell, opening);

    // The crest: an arc of bristles from over the brow to past the neck,
    // its outer edge ragged like a brush.
    const cc = Offset(58, 42);
    const steps = 30;
    final outer = <Offset>[];
    final inner = <Offset>[];
    final bristles = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final a = (198 + t * 192) * math.pi / 180;
      final ro = 36 - 5 * t * t * t - (i.isOdd ? 2.6 : 0);
      final ri = 19 + 10.5 * math.pow(math.max(0, t - 0.75) / 0.25, 2);
      outer.add(cc + Offset(math.cos(a), math.sin(a)) * ro);
      inner.add(cc + Offset(math.cos(a), math.sin(a)) * ri);
      if (i % 4 == 2 && i < steps - 2) {
        final from = cc + Offset(math.cos(a), math.sin(a)) * (ri + 2);
        final to = cc + Offset(math.cos(a + 0.08), math.sin(a + 0.08)) * (ro - 3.5);
        bristles
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy);
      }
    }
    final crest = _poly([...outer, ...inner.reversed]);
    return _Symbol(
      Path.combine(PathOperation.union, helmet, crest),
      accents: [(_Tint.paleGlow, crest)],
      shade: [Path.combine(PathOperation.intersect, helmet, Path()..addRect(const Rect.fromLTRB(61, 0, 100, 100)))],
      lights: [Path()..addOval(Rect.fromCenter(center: const Offset(48, 33), width: 9, height: 5))],
      lines: bristles
        // The brow ridge and the seam of the cheek guard.
        ..moveTo(27.5, 44)
        ..quadraticBezierTo(50, 38.5, 74, 46)
        ..moveTo(49.5, 51)
        ..quadraticBezierTo(57, 62, 61, 76),
      glints: Path()
        ..moveTo(37.5, 63)
        ..quadraticBezierTo(36.5, 74, 38.5, 85),
    );
  }

  /// Mortal: a human skull in bone -- memento mori. Domed cranium, deep
  /// orbits, flared cheekbones, the nasal cavity, a row of teeth and the jaw.
  static _Symbol _skull() {
    final mirror = Matrix4.identity()
      ..translateByDouble(100, 0, 0, 1)
      ..scaleByDouble(-1, 1, 1, 1);
    Path both(Path left) => Path.combine(PathOperation.union, left, left.transform(mirror.storage));

    final outline = Path()
      ..moveTo(50, 8)
      ..cubicTo(68, 8, 80, 20, 80, 36)
      ..cubicTo(80, 44, 77, 49, 74, 52)
      ..lineTo(77.5, 58)
      ..quadraticBezierTo(76.5, 64, 70, 66)
      ..lineTo(69, 75)
      ..quadraticBezierTo(67, 85, 60, 90)
      ..quadraticBezierTo(50, 94, 40, 90)
      ..quadraticBezierTo(33, 85, 31, 75)
      ..lineTo(30, 66)
      ..quadraticBezierTo(23.5, 64, 22.5, 58)
      ..lineTo(26, 52)
      ..cubicTo(23, 49, 20, 44, 20, 36)
      ..cubicTo(20, 20, 32, 8, 50, 8)
      ..close();
    final orbit = Path()
      ..moveTo(30.5, 41.5)
      ..quadraticBezierTo(38, 35.5, 45.5, 40)
      ..quadraticBezierTo(48, 47, 44.5, 51.5)
      ..quadraticBezierTo(37, 54.5, 32, 50.5)
      ..quadraticBezierTo(28.5, 46, 30.5, 41.5)
      ..close();
    final holes = _unionAll([
      both(orbit),
      // The nasal cavity, an upturned heart.
      Path()
        ..moveTo(50, 53)
        ..quadraticBezierTo(45.5, 58, 44.5, 63.5)
        ..quadraticBezierTo(46, 66.5, 50, 64.5)
        ..quadraticBezierTo(54, 66.5, 55.5, 63.5)
        ..quadraticBezierTo(54.5, 58, 50, 53)
        ..close(),
      // Between the teeth rows, and the notch behind each cheekbone.
      Path()
        ..moveTo(36, 74)
        ..quadraticBezierTo(50, 77.5, 64, 74)
        ..lineTo(64, 75.4)
        ..quadraticBezierTo(50, 78.9, 36, 75.4)
        ..close(),
      both(_poly(const [Offset(30.8, 67), Offset(35, 66.5), Offset(35.5, 72.5), Offset(31.8, 73)])),
    ]);
    final skull = Path.combine(PathOperation.difference, outline, holes);
    final teeth = Path.combine(
      PathOperation.difference,
      Path()
        ..moveTo(36.5, 68.5)
        ..quadraticBezierTo(50, 71.5, 63.5, 68.5)
        ..lineTo(63, 80)
        ..quadraticBezierTo(50, 83.5, 37, 80)
        ..close(),
      holes,
    );
    final toothLines = Path();
    for (var i = -3; i <= 3; i++) {
      final x = 50 + i * 3.6;
      final bow = 1.6 * (1 - (i * i) / 12);
      toothLines
        ..moveTo(x, 69 + bow)
        ..lineTo(x, 73.6 + bow)
        ..moveTo(x, 76 + bow)
        ..lineTo(x, 80.5 + bow * 0.8);
    }
    // The coronal suture, wandering across the crown.
    final suture = Path()..moveTo(24, 26);
    for (var i = 1; i <= 12; i++) {
      final x = 24 + i * 52 / 12;
      final y = 26 - 9 * math.sin(math.pi * i / 12) + (i.isOdd ? 1.6 : -1.6);
      suture.lineTo(x, y);
    }
    return _Symbol(
      skull,
      accents: [(_Tint.bone, skull)],
      shade: [
        // Temples, the hollows under the cheekbones and round the orbits.
        Path.combine(
          PathOperation.difference,
          Path.combine(
            PathOperation.intersect,
            outline,
            both(Path()
              ..addOval(Rect.fromCenter(center: const Offset(23, 50), width: 13, height: 22))
              ..addOval(Rect.fromCenter(center: const Offset(33, 63.5), width: 9, height: 5))),
          ),
          holes,
        ),
        Path.combine(
          PathOperation.difference,
          both(Path()..addOval(Rect.fromCenter(center: const Offset(38.5, 45.5), width: 21, height: 19))),
          holes,
        ),
        Path.combine(PathOperation.intersect, skull, Path()..addRect(const Rect.fromLTRB(52, 0, 100, 100))),
      ],
      lights: [
        Path()..addOval(Rect.fromCenter(center: const Offset(40, 21), width: 18, height: 9)),
        teeth,
      ],
      lines: toothLines
        ..addPath(suture, Offset.zero)
        // A crack from the crown down to the left orbit.
        ..moveTo(42, 9)
        ..lineTo(39, 17)
        ..lineTo(43, 23)
        ..lineTo(38.5, 31)
        ..lineTo(40, 37)
        // The nasal septum and where the jaw meets the skull.
        ..moveTo(50, 58)
        ..lineTo(50, 65)
        ..moveTo(31.5, 74)
        ..quadraticBezierTo(33, 80, 37, 82)
        ..moveTo(68.5, 74)
        ..quadraticBezierTo(67, 80, 63, 82),
      glints: Path()
        ..moveTo(31, 39)
        ..quadraticBezierTo(38, 33.5, 46, 37.5)
        ..moveTo(24, 57)
        ..lineTo(28.5, 55.5),
    );
  }

  /// Warrior: two double-bitted battle axes, crossed.
  static _Symbol _crossedAxes() {
    final head = Path()
      ..moveTo(47.5, 25)
      ..lineTo(36, 18)
      ..quadraticBezierTo(25, 31, 34, 46)
      ..lineTo(47.5, 39)
      ..close()
      ..moveTo(52.5, 25)
      ..lineTo(64, 18)
      ..quadraticBezierTo(75, 31, 66, 46)
      ..lineTo(52.5, 39)
      ..close();
    final axe = Path.combine(
      PathOperation.union,
      Path.combine(
        PathOperation.union,
        head,
        Path()..addRRect(RRect.fromLTRBR(47.5, 20, 52.5, 90, const Radius.circular(2))),
      ),
      _poly(const [Offset(47.5, 21), Offset(50, 10), Offset(52.5, 21)]),
    );
    final details = _Symbol(
      axe,
      shade: [
        _poly(const [Offset(52.5, 25), Offset(64, 18), Offset(70, 32), Offset(66, 46), Offset(52.5, 39)]),
      ],
      lines: Path()
        ..moveTo(36, 18)
        ..quadraticBezierTo(29, 31, 34, 46)
        ..moveTo(64, 18)
        ..quadraticBezierTo(71, 31, 66, 46)
        ..moveTo(47.5, 70)
        ..lineTo(52.5, 68)
        ..moveTo(47.5, 75)
        ..lineTo(52.5, 73)
        ..moveTo(47.5, 80)
        ..lineTo(52.5, 78),
      glints: Path()
        ..moveTo(31.5, 26)
        ..quadraticBezierTo(29, 33, 33, 41),
    );
    const c = Offset(50, 52);
    Matrix4 turn(double a) => Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(a)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    return _Symbol.union(details.transformed(turn(-0.62)), details.transformed(turn(0.62)));
  }

  /// Hero: a handsome Greek hero in profile, like the head on an old coin --
  /// straight nose, strong jaw, golden curls bound by a glowing fillet whose
  /// ribbons stream behind, and a cloak pinned at the shoulder.
  static _Symbol _hero() {
    final skin = Path()
      ..moveTo(38, 28)
      ..quadraticBezierTo(33, 32, 32.5, 40)
      ..quadraticBezierTo(32, 43, 30.5, 45)
      ..lineTo(24, 57.5)
      ..quadraticBezierTo(23.5, 59, 26, 59.5)
      ..lineTo(29, 60)
      ..quadraticBezierTo(27.5, 61.5, 27.5, 63)
      ..quadraticBezierTo(29, 64, 30.5, 64.2)
      ..quadraticBezierTo(28.5, 65, 28.5, 66.5)
      ..quadraticBezierTo(31, 68.5, 30.5, 70)
      ..quadraticBezierTo(28.5, 74, 31, 77.5)
      ..quadraticBezierTo(36, 80, 42, 79)
      ..quadraticBezierTo(42, 85, 40, 89)
      ..quadraticBezierTo(34, 92, 30, 97)
      ..quadraticBezierTo(52, 101, 80, 96)
      ..quadraticBezierTo(76, 88, 68, 84)
      ..lineTo(68, 70)
      ..lineTo(72, 40)
      ..quadraticBezierTo(60, 22, 38, 28)
      ..close();

    // Curls round the edge of the hair, and a spiral in each.
    const curls = [
      Offset(38, 31),
      Offset(42, 25.5),
      Offset(49, 22.5),
      Offset(57, 21.5),
      Offset(65, 23),
      Offset(71, 27),
      Offset(75.5, 33),
      Offset(77.5, 40),
      Offset(77.5, 47),
      Offset(75.5, 54),
      Offset(72.5, 60.5),
      Offset(68.5, 66.5),
    ];
    final spirals = Path();
    final hairParts = <Path>[
      Path()
        ..moveTo(37, 36)
        ..quadraticBezierTo(36, 26, 48, 23)
        ..quadraticBezierTo(66, 19, 75, 32)
        ..quadraticBezierTo(80, 46, 74, 58)
        ..quadraticBezierTo(71, 66, 66, 71)
        ..lineTo(61, 68)
        ..quadraticBezierTo(60, 58, 58, 52)
        ..lineTo(50, 50)
        ..quadraticBezierTo(46, 44, 42, 42)
        ..quadraticBezierTo(38, 40, 37, 36)
        ..close(),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(36.5, 35.5), radius: 3))
        ..addOval(Rect.fromCircle(center: const Offset(40, 40), radius: 3)),
    ];
    for (final (i, at) in curls.indexed) {
      hairParts.add(Path()..addOval(Rect.fromCircle(center: at, radius: 5)));
      spirals.addArc(Rect.fromCircle(center: at, radius: 2.6), i * 0.9, math.pi * 1.3);
    }
    for (final at in const [
      Offset(50, 31),
      Offset(58, 30),
      Offset(66, 33),
      Offset(57, 41),
      Offset(66, 43),
      Offset(68, 52)
    ]) {
      spirals.addArc(Rect.fromCircle(center: at, radius: 3), at.dx * 0.2, math.pi * 1.4);
    }
    final hair = _unionAll(hairParts);

    final fillet = _unionAll([
      Path()
        ..moveTo(37.5, 30)
        ..quadraticBezierTo(57, 23.5, 77, 36)
        ..lineTo(76.5, 39.8)
        ..quadraticBezierTo(57, 27.8, 38.5, 33.8)
        ..close(),
      // The ribbons streaming from the knot behind.
      Path()
        ..moveTo(75, 37)
        ..cubicTo(82, 39, 84, 46, 90, 50)
        ..lineTo(87, 54.5)
        ..cubicTo(82, 50, 79, 44, 73.5, 41.5)
        ..close(),
      Path()
        ..moveTo(75, 40)
        ..cubicTo(80, 46, 77, 54, 84, 61)
        ..lineTo(80, 64)
        ..cubicTo(74, 57, 76, 49, 73, 44)
        ..close(),
    ]);
    final cloak = Path()
      ..moveTo(28, 98)
      ..quadraticBezierTo(44, 86, 62, 88)
      ..quadraticBezierTo(74, 88, 82, 96)
      ..quadraticBezierTo(54, 102, 28, 98)
      ..close();
    final brooch = Path()..addOval(Rect.fromCircle(center: const Offset(61, 91), radius: 3.2));
    return _Symbol(
      _unionAll([skin, hair, fillet, cloak]),
      accents: [
        (_Tint.metal, hair),
        (_Tint.metal, cloak),
        (_Tint.ink, Path.combine(PathOperation.union, fillet, brooch))
      ],
      shade: [
        // The neck in the jaw's shadow, and the back of the hair.
        Path.combine(
          PathOperation.difference,
          Path.combine(
            PathOperation.intersect,
            skin,
            _poly(const [Offset(33, 80), Offset(53, 72.5), Offset(68, 70), Offset(68, 88), Offset(40, 88)]),
          ),
          Path.combine(PathOperation.union, hair, cloak),
        ),
        Path.combine(PathOperation.intersect, hair, Path()..addRect(const Rect.fromLTRB(66, 0, 100, 100))),
      ],
      lines: spirals
        // Eyebrow, eye, nostril, the ear and the line of the jaw.
        ..moveTo(31.5, 44.5)
        ..quadraticBezierTo(36, 42.5, 41, 43.5)
        ..moveTo(32.5, 47.5)
        ..quadraticBezierTo(35.5, 46, 38.5, 47)
        ..moveTo(33.5, 49.5)
        ..lineTo(37.5, 48.6)
        ..moveTo(26.5, 56.5)
        ..quadraticBezierTo(28.5, 56, 29, 58)
        ..moveTo(55, 54)
        ..quadraticBezierTo(59, 56.5, 57.5, 61.5)
        ..quadraticBezierTo(56, 64, 53.5, 63)
        ..moveTo(37, 77.8)
        ..quadraticBezierTo(45, 75.8, 52.5, 71.5)
        ..lineTo(55.5, 64.5)
        ..moveTo(40, 89)
        ..quadraticBezierTo(44, 84, 44.5, 79.5),
      glints: Path()
        ..moveTo(31, 46.5)
        ..lineTo(25.5, 56)
        ..moveTo(40, 31)
        ..quadraticBezierTo(56, 26.5, 72, 33),
    );
  }

  /// Demigod: Hermes' winged helmet -- a domed cap on a jewelled brim with
  /// a broad, three-feathered wing at each temple.
  static _Symbol _wingedHelmet() {
    final helmet = _unionAll([
      Path()
        ..moveTo(31, 64)
        ..cubicTo(31, 40, 40, 27, 50, 27)
        ..cubicTo(60, 27, 69, 40, 69, 64)
        ..close(),
      Path()..addRRect(RRect.fromLTRBR(25, 59, 75, 70, const Radius.circular(5))),
    ]);
    final wing = Path()
      ..moveTo(34, 44)
      ..quadraticBezierTo(22, 24, 6, 9)
      ..lineTo(14, 24)
      ..lineTo(1, 25)
      ..lineTo(15, 33)
      ..lineTo(4, 40)
      ..lineTo(18, 42)
      ..lineTo(11, 51)
      ..quadraticBezierTo(26, 53, 34, 57)
      ..close();
    final mirror = Matrix4.identity()
      ..translateByDouble(100, 0, 0, 1)
      ..scaleByDouble(-1, 1, 1, 1);
    final feathers = Path()
      ..moveTo(32, 48)
      ..lineTo(14, 24)
      ..moveTo(32, 50)
      ..lineTo(15, 33)
      ..moveTo(32, 52)
      ..lineTo(18, 42);
    return _Symbol(
      _unionAll([helmet, wing, wing.transform(mirror.storage)]),
      shade: [Path.combine(PathOperation.intersect, helmet, Path()..addRect(const Rect.fromLTRB(50, 0, 100, 100)))],
      lights: [Path()..addOval(Rect.fromCenter(center: const Offset(50, 64.5), width: 7, height: 6))],
      lines: feathers
        ..addPath(feathers.transform(mirror.storage), Offset.zero)
        // The brim's upper edge and the ridge over the dome.
        ..moveTo(26, 60)
        ..lineTo(74, 60)
        ..moveTo(50, 28)
        ..lineTo(50, 59),
      glints: Path()
        ..moveTo(36, 50)
        ..quadraticBezierTo(37, 36, 46, 30),
    );
  }

  /// Titan: Atlas as a marble statue, seen from the side -- down on one
  /// knee, back bent and bearded head bowed, the glowing sphere of the
  /// heavens on his shoulders, steadied by both hands.
  static _Symbol _atlas() {
    const g = Offset(55, 26);
    const gr = 24.0;
    // Neck, shoulders, back, buttock and the near thigh out to the knee.
    final trunk = Path()
      ..moveTo(47, 63)
      ..cubicTo(47, 58, 50, 53, 57, 51.5)
      ..cubicTo(65, 50, 74, 52, 78, 59)
      ..cubicTo(81, 65, 81, 74, 78, 79)
      ..cubicTo(82, 82, 81, 88, 75, 90)
      ..cubicTo(66, 92, 54, 91, 47, 90.5)
      ..cubicTo(42, 90.5, 39, 88, 39, 85)
      ..cubicTo(39, 81, 42, 79.5, 46, 79.5)
      ..cubicTo(53, 77.5, 60, 78, 64, 80)
      ..cubicTo(60, 79, 56, 77, 54, 74)
      ..cubicTo(52, 71, 50, 68, 47, 63)
      ..close();
    // The near arm, raised: triceps out to the elbow, forearm up to the
    // hand spread on the sphere, back down the forearm, biceps, deltoid.
    final arm = Path()
      ..moveTo(61, 61)
      ..cubicTo(56, 64, 50, 62, 46, 57)
      ..cubicTo(41, 52, 35, 51, 31.5, 47)
      ..cubicTo(29, 44.5, 29, 41, 30.5, 38)
      ..cubicTo(31, 34, 31.5, 30, 32, 27.5)
      ..cubicTo(31.5, 24, 32.5, 20, 35.5, 17.5)
      ..cubicTo(37, 16.5, 38.5, 17.5, 38, 19)
      ..cubicTo(37.5, 21, 37.5, 24, 37.8, 27)
      ..cubicTo(38, 31, 38.5, 35, 38.5, 38.5)
      ..cubicTo(41, 42, 46, 45, 50, 47.5)
      ..cubicTo(53, 49, 57, 49.5, 60, 50.5)
      ..cubicTo(64, 52, 65, 58, 61, 61)
      ..close();
    // Bowed under the arm: crown, brow, nose, then the beard.
    final head = Path()
      ..moveTo(49, 62)
      ..cubicTo(48.5, 56.5, 43, 53.5, 38.5, 54.5)
      ..cubicTo(35, 55.5, 33, 58, 32.5, 61)
      ..lineTo(31, 64.5)
      ..lineTo(29, 68.5)
      ..lineTo(31.6, 68.8)
      ..cubicTo(30.8, 71.5, 31.5, 75, 34.5, 77)
      ..cubicTo(38, 78, 42, 76.5, 44.5, 73.5)
      ..cubicTo(46.5, 70.5, 48, 66.5, 49, 62)
      ..close();
    // The near shin down to a foot planted flat.
    final shin = Path()
      ..moveTo(41, 87)
      ..cubicTo(41, 94, 42, 100, 43, 104)
      ..cubicTo(41, 105, 36, 105.5, 33, 106.5)
      ..cubicTo(32, 107.5, 33, 108.5, 35, 108.5)
      ..lineTo(49, 108.5)
      ..cubicTo(51, 108.5, 51.5, 106, 50, 104)
      ..cubicTo(52, 99, 54, 93, 50, 88)
      ..close();
    final near = _unionAll([trunk, arm, head, shin]);
    // The far side, in shadow: the knee on the ground and a hand on the
    // sphere's far side.
    final farLeg = Path.combine(
      PathOperation.difference,
      _unionAll([
        _muscle(const Offset(70, 88), const Offset(63, 103.5), 7, 5.5, 0),
        _muscle(const Offset(63, 104), const Offset(86, 105), 4.8, 3, -1.6),
        _muscle(const Offset(86, 105), const Offset(91, 101), 3, 2, 0),
      ]),
      near,
    );
    final farArm = Path.combine(
      PathOperation.difference,
      _unionAll([
        _muscle(const Offset(75, 53), const Offset(79, 37), 4.2, 3.2, 1),
        Path()..addOval(Rect.fromCenter(center: const Offset(79.5, 32), width: 6, height: 8.5)),
      ]),
      trunk,
    );
    final body = _unionAll([near, farLeg, farArm]);
    final sphere = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: g, radius: gr)),
      _unionAll([arm, farArm, trunk, head].map((p) => _grown(p, 1.4)).toList()),
    );
    Path star(Offset at, double r) => _poly([
          at + Offset(0, -r),
          at + Offset(r * 0.3, -r * 0.3),
          at + Offset(r, 0),
          at + Offset(r * 0.3, r * 0.3),
          at + Offset(0, r),
          at + Offset(-r * 0.3, r * 0.3),
          at + Offset(-r, 0),
          at + Offset(-r * 0.3, -r * 0.3),
        ]);
    // The zodiac band, tilted across the sphere.
    final band = Path()
      ..addOval(Rect.fromCenter(center: Offset.zero, width: 44, height: 13))
      ..addOval(Rect.fromCenter(center: Offset.zero, width: 44, height: 7.5));
    final tilt = Matrix4.identity()
      ..translateByDouble(g.dx, g.dy, 0, 1)
      ..rotateZ(-0.38);
    Path within(Path part, Rect oval) => Path.combine(PathOperation.intersect, part, Path()..addOval(oval));
    return _Symbol(
      Path.combine(PathOperation.union, sphere, body),
      accents: [(_Tint.glow, sphere), (_Tint.bone, body)],
      shade: [
        Path.combine(
          PathOperation.difference,
          sphere,
          Path()..addOval(Rect.fromCircle(center: const Offset(49, 20), radius: gr)),
        ),
        farLeg,
        farArm,
        // The back, under the thigh and the chest, the calf and triceps.
        within(trunk, Rect.fromCenter(center: const Offset(80, 70), width: 10, height: 34)),
        within(trunk, Rect.fromCenter(center: const Offset(60, 91), width: 30, height: 6)),
        within(trunk, Rect.fromCenter(center: const Offset(50, 70), width: 7, height: 16)),
        within(shin, Rect.fromCenter(center: const Offset(52, 96), width: 6, height: 16)),
        within(arm, Rect.fromCenter(center: const Offset(47, 60), width: 22, height: 7)),
        within(head, Rect.fromCenter(center: const Offset(44, 74), width: 10, height: 8)),
      ],
      lights: [
        Path()..addOval(Rect.fromCenter(center: const Offset(45, 13), width: 13, height: 7)),
        _unionAll([
          star(const Offset(66, 11), 3.2),
          star(const Offset(47, 27), 2.2),
          star(const Offset(67, 35), 2.4),
          star(const Offset(56, 5), 1.8),
        ]),
      ],
      lines: band.transform(tilt.storage)
        ..addArc(Rect.fromCenter(center: g, width: 17, height: gr * 2), math.pi * 0.74, math.pi * 1.52)
        // The outlines of the near limbs and head over what lies behind.
        ..addPath(arm, Offset.zero)
        ..addPath(head, Offset.zero)
        ..addPath(shin, Offset.zero)
        // Hair, the closed eye, the ear and the beard.
        ..moveTo(37.5, 56.5)
        ..quadraticBezierTo(41.5, 55.8, 44.5, 58.5)
        ..moveTo(32.5, 64.6)
        ..lineTo(35, 65.3)
        ..addArc(Rect.fromCircle(center: const Offset(42, 62.5), radius: 2.2), -math.pi * 0.4, math.pi * 1.2)
        ..moveTo(32.5, 71)
        ..quadraticBezierTo(34, 74.5, 39.5, 75)
        ..moveTo(36, 69.5)
        ..quadraticBezierTo(38.5, 72.5, 42.5, 72)
        // Deltoid, shoulder blade, spine, belly, quad and kneecap.
        ..moveTo(52, 50)
        ..quadraticBezierTo(57, 55, 56, 61)
        ..moveTo(64, 53)
        ..quadraticBezierTo(70, 58, 69, 65)
        ..moveTo(76, 57)
        ..cubicTo(79, 64, 79, 72, 77, 78)
        ..moveTo(51, 71)
        ..quadraticBezierTo(54, 74, 57, 75.5)
        ..moveTo(62, 82)
        ..quadraticBezierTo(53, 82, 46, 84)
        ..addArc(Rect.fromCircle(center: const Offset(42.5, 84.5), radius: 3), math.pi * 0.55, math.pi * 0.9),
    );
  }

  /// [path] scaled up about its centre so that it reaches about [by] grid
  /// units further out -- for cutting a gap round a shape.
  static Path _grown(Path path, double by) {
    final b = path.getBounds();
    final m = Matrix4.identity()
      ..translateByDouble(b.center.dx, b.center.dy, 0, 1)
      ..scaleByDouble((b.width + by * 2) / b.width, (b.height + by * 2) / b.height, 1, 1)
      ..translateByDouble(-b.center.dx, -b.center.dy, 0, 1);
    return path.transform(m.storage);
  }

  /// A muscled limb from [a] to [b], [wa] and [wb] thick at either end,
  /// one side swelling out by [bulge] (the other side for a negative one).
  static Path _muscle(Offset a, Offset b, double wa, double wb, double bulge) {
    final v = b - a;
    final n = Offset(-v.dy, v.dx) / v.distance;
    final mid = (a + b) / 2;
    final w = (wa + wb) / 2;
    final out = mid + n * (w + math.max(0, bulge) * 2);
    final back = mid - n * (w + math.max(0, -bulge) * 2);
    return _unionAll([
      Path()
        ..moveTo((a + n * wa).dx, (a + n * wa).dy)
        ..quadraticBezierTo(out.dx, out.dy, (b + n * wb).dx, (b + n * wb).dy)
        ..lineTo((b - n * wb).dx, (b - n * wb).dy)
        ..quadraticBezierTo(back.dx, back.dy, (a - n * wa).dx, (a - n * wa).dy)
        ..close(),
      Path()..addOval(Rect.fromCircle(center: a, radius: wa)),
      Path()..addOval(Rect.fromCircle(center: b, radius: wb)),
    ]);
  }

  /// Olympian: Zeus himself in profile, gold and ivory like his statue at
  /// Olympia -- ivory face, golden hair, curled beard and robe, a shining
  /// laurel crown, and a forked bolt of lightning crackling behind him.
  static _Symbol _zeus() {
    Path curls(List<Offset> centres, double r) =>
        _unionAll([for (final c in centres) Path()..addOval(Rect.fromCircle(center: c, radius: r))]);
    // A jagged channel of lightning through [points], [w] wide at the
    // first one and thinning towards the last.
    Path channel(List<Offset> points, double w) {
      final left = <Offset>[];
      final right = <Offset>[];
      for (var i = 0; i < points.length; i++) {
        final d = points[math.min(points.length - 1, i + 1)] - points[math.max(0, i - 1)];
        final n = Offset(-d.dy, d.dx) / d.distance;
        final width = w * (1 - 0.55 * i / (points.length - 1));
        left.add(points[i] + n * width);
        right.add(points[i] - n * width);
      }
      return _poly([...left, ...right.reversed]);
    }

    final bolt = _unionAll([
      channel(const [
        Offset(89, 1),
        Offset(85, 9),
        Offset(90, 16),
        Offset(83, 25),
        Offset(88, 32),
        Offset(81, 42),
        Offset(87, 49),
        Offset(80, 59),
        Offset(85, 66),
        Offset(79, 76),
        Offset(84, 84),
        Offset(78, 94),
      ], 3),
      channel(const [Offset(83, 25), Offset(90, 30), Offset(93, 38), Offset(99, 42)], 1.6),
      channel(const [Offset(87, 49), Offset(94, 55), Offset(96, 63)], 1.5),
      channel(const [Offset(80, 59), Offset(90, 67), Offset(92, 75), Offset(98, 80)], 1.4),
    ]);

    final face = Path()
      ..moveTo(40, 25)
      ..quadraticBezierTo(35, 28, 34, 35)
      ..quadraticBezierTo(33.5, 38.5, 31.5, 40.5)
      ..lineTo(26, 51.5)
      ..quadraticBezierTo(24.8, 53.8, 27.5, 54.3)
      ..lineTo(31, 55)
      ..quadraticBezierTo(40, 57, 48, 54)
      ..lineTo(54, 48)
      ..lineTo(48, 32)
      ..close();
    final hair = _unionAll([
      Path()
        ..moveTo(39, 26.5)
        ..cubicTo(40, 17, 50, 12, 59, 14)
        ..cubicTo(67, 16, 72, 24, 71, 33)
        ..cubicTo(74, 41, 73, 52, 69, 60)
        ..cubicTo(67, 66, 64, 70, 60, 72)
        ..lineTo(57, 69)
        ..cubicTo(58, 62, 57, 55, 55, 50)
        ..lineTo(49, 43)
        ..cubicTo(45, 37, 42, 31, 39, 26.5)
        ..close(),
      curls(const [
        Offset(40, 21),
        Offset(45.5, 15.5),
        Offset(52, 13),
        Offset(59, 13.5),
        Offset(65, 16.5),
        Offset(69.5, 22),
        Offset(71.5, 29),
        Offset(72.5, 36),
        Offset(73, 43),
        Offset(72.5, 50),
        Offset(71, 56),
        Offset(68.5, 62),
        Offset(65, 67),
        Offset(61, 70.5),
      ], 4),
    ]);
    final beard = _unionAll([
      Path()
        ..moveTo(30.5, 54.5)
        ..cubicTo(27, 56, 26.5, 59, 28.5, 61)
        ..cubicTo(25, 66, 27, 72, 26, 76)
        ..cubicTo(25, 82, 29, 87, 33, 91)
        ..quadraticBezierTo(37, 94, 41, 91)
        ..cubicTo(46, 86, 50, 80, 54, 74)
        ..lineTo(57, 62)
        ..lineTo(55, 49)
        ..lineTo(48, 54)
        ..quadraticBezierTo(40, 57, 31, 55)
        ..close(),
      curls(const [
        Offset(28, 62),
        Offset(26.5, 68),
        Offset(27, 74.5),
        Offset(28.5, 80.5),
        Offset(31.5, 86),
        Offset(36, 90),
        Offset(41, 89.5),
      ], 3.8),
    ]);
    final bust = Path()
      ..moveTo(38, 89)
      ..lineTo(58, 72)
      ..quadraticBezierTo(68, 73, 75, 82)
      ..quadraticBezierTo(79, 89, 79, 98)
      ..quadraticBezierTo(54, 103, 28, 99)
      ..quadraticBezierTo(30, 93, 38, 89)
      ..close();
    // The robe slung over the far shoulder and across the chest.
    final robe = Path()
      ..moveTo(60, 73)
      ..quadraticBezierTo(70, 74, 75.5, 83)
      ..quadraticBezierTo(79, 89, 79, 98)
      ..quadraticBezierTo(64, 101, 47, 100.6)
      ..quadraticBezierTo(57, 92, 63, 80)
      ..close();
    // Cheek, ear and neck under the hair and beard, closing the gaps.
    final under =
        _poly(const [Offset(46, 50), Offset(52, 43), Offset(58, 46), Offset(60, 60), Offset(59, 72), Offset(53, 75)]);
    final skin = _unionAll([bust, face, under]);
    final gold = _unionAll([hair, beard, robe]);

    // The laurel crown: two rows of leaves along the brow of the hair,
    // all pointing forward.
    Offset along(double t) {
      const p = [Offset(36.5, 30), Offset(42, 17), Offset(66, 13), Offset(77, 28)];
      final u = 1 - t;
      return p[0] * (u * u * u) + p[1] * (3 * u * u * t) + p[2] * (3 * u * t * t) + p[3] * (t * t * t);
    }

    final leaves = <Path>[];
    for (var k = 0; k < 10; k++) {
      final t = 0.04 + k * 0.1;
      final at = along(t);
      final ahead = along(t - 0.03);
      final d = (ahead - at) / (ahead - at).distance;
      final up = Offset(d.dy, -d.dx);
      final a = math.atan2(d.dy, d.dx);
      for (final side in const [1.0, -1.0]) {
        final c = at + up * (2.3 * side) + d * 3;
        leaves.add((Path()
              ..moveTo(-4.8, 0)
              ..quadraticBezierTo(0, -2.4, 4.8, 0)
              ..quadraticBezierTo(0, 2.4, -4.8, 0)
              ..close())
            .transform((Matrix4.identity()
                  ..translateByDouble(c.dx, c.dy, 0, 1)
                  ..rotateZ(a - 0.45 * side))
                .storage));
      }
    }
    final wreath = _unionAll(leaves);

    return _Symbol(
      _unionAll([bolt, skin, gold, wreath]),
      accents: [(_Tint.ink, bolt), (_Tint.bone, skin), (_Tint.metal, gold), (_Tint.paleGlow, wreath)],
      shade: [
        // The back of the hair, and the robe's folds.
        Path.combine(
          PathOperation.difference,
          Path.combine(PathOperation.intersect, hair, Path()..addRect(const Rect.fromLTRB(64, 0, 100, 100))),
          wreath,
        ),
        Path.combine(
          PathOperation.intersect,
          robe,
          Path()
            ..addOval(Rect.fromCenter(center: const Offset(70, 92), width: 18, height: 5))
            ..addOval(Rect.fromCenter(center: const Offset(74, 84), width: 8, height: 4)),
        ),
        // The eye under the brow, the cheek, the neck and the far shoulder.
        Path.combine(
          PathOperation.intersect,
          face,
          Path()
            ..addOval(Rect.fromCenter(center: const Offset(35.5, 44), width: 7, height: 3.6))
            ..addOval(Rect.fromCenter(center: const Offset(43, 52), width: 9, height: 4)),
        ),
        Path.combine(
          PathOperation.difference,
          Path.combine(
            PathOperation.intersect,
            bust,
            Path()..addOval(Rect.fromCenter(center: const Offset(52, 85), width: 22, height: 12)),
          ),
          gold,
        ),
      ],
      lines: Path()
        // Strands of the beard flowing down, waves of hair flowing back.
        ..moveTo(31, 62)
        ..quadraticBezierTo(29, 68, 31, 74)
        ..moveTo(36.5, 60)
        ..cubicTo(33.5, 67, 37.5, 73, 34.5, 81)
        ..moveTo(42, 58)
        ..cubicTo(39, 66, 44, 74, 40, 85)
        ..moveTo(48, 57)
        ..cubicTo(46, 65, 50, 71, 46.5, 80)
        ..moveTo(47, 30)
        ..cubicTo(56, 28, 63, 33, 67, 42)
        ..moveTo(52, 38)
        ..cubicTo(59, 39, 65, 47, 66, 56)
        ..moveTo(56, 47)
        ..cubicTo(61, 51, 63, 58, 62, 66)
        // Brow, eye, nostril and moustache.
        ..moveTo(31.5, 40.8)
        ..quadraticBezierTo(36, 38.5, 42, 39.5)
        ..moveTo(32.5, 43.5)
        ..quadraticBezierTo(35, 42.4, 37.5, 43)
        ..moveTo(33, 45.3)
        ..lineTo(37, 45)
        ..moveTo(27.5, 51)
        ..quadraticBezierTo(29.5, 51, 29.8, 52.8)
        ..moveTo(29, 56.5)
        ..quadraticBezierTo(33, 58.5, 38, 57)
        // The robe's folds.
        ..moveTo(72, 80)
        ..quadraticBezierTo(65, 90, 56, 99)
        ..moveTo(77, 89)
        ..quadraticBezierTo(70, 95, 64, 100),
    );
  }

  static Path _unionAll(List<Path> paths) =>
      paths.skip(1).fold(paths.first, (sum, p) => Path.combine(PathOperation.union, sum, p));

  /// Draws [symbol] fitted into [target].
  void _paintSymbol(Canvas canvas, _Symbol symbol, Rect target, double breathe) {
    final b = symbol.fill.getBounds();
    final s = math.min(target.width / b.width, target.height / b.height);
    canvas.save();
    canvas.translate(target.center.dx, target.center.dy);
    canvas.scale(s);
    canvas.translate(-b.center.dx, -b.center.dy);
    final unit = 1 / s; // one grid unit, in symbol coordinates

    const top = Colors.white;
    final bottom = Color.lerp(p.ink, p.glow, 0.5)!;
    // Halos round the glowing accents, then round the whole symbol.
    for (final (tint, accent) in symbol.accents) {
      if (tint == _Tint.metal || tint == _Tint.bone) continue;
      canvas.drawPath(
        accent,
        Paint()
          ..color = (tint == _Tint.ink ? p.ink : p.glow).withValues(alpha: 0.9 * breathe)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * unit),
      );
    }
    canvas.drawPath(
      symbol.fill,
      Paint()
        ..color = p.glow.withValues(alpha: 0.9 * breathe)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * unit),
    );
    canvas.drawPath(
      symbol.fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(b),
    );
    for (final (tint, accent) in symbol.accents) {
      final colors = switch (tint) {
        _Tint.metal => [Color.lerp(p.light, p.base, 0.6)!, p.base, Color.lerp(p.base, p.dark, 0.5)!],
        _Tint.glow => [Color.lerp(p.glow, Colors.white, 0.45)!, p.glow, Color.lerp(p.glow, Colors.black, 0.4)!],
        _Tint.paleGlow => [
            Color.lerp(p.glow, Colors.white, 0.85)!,
            Color.lerp(p.glow, Colors.white, 0.55)!,
            Color.lerp(p.glow, Colors.white, 0.2)!
          ],
        _Tint.ink => [Colors.white, Colors.white, p.ink],
        _Tint.bone => const [Color(0xFFFFF9EC), Color(0xFFEADFC6), Color(0xFFB4A07C)],
      };
      canvas.drawPath(
        accent,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(accent.getBounds()),
      );
      _stroke(canvas, accent, Colors.black.withValues(alpha: 0.45), 0.7 * unit);
    }
    for (final shade in symbol.shade) {
      canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.22));
    }
    for (final (i, light) in symbol.lights.indexed) {
      canvas.drawPath(
          light, Paint()..color = Colors.white.withValues(alpha: i == 0 && symbol.lights.length > 1 ? 0.4 : 0.9));
    }
    final lines = symbol.lines;
    if (lines != null) {
      // Bone and marble are drawn in warm umber rather than the palette.
      final lineColor = symbol.accents.any((a) => a.$1 == _Tint.bone)
          ? const Color(0xFF5A4A33)
          : Color.lerp(bottom, Colors.black, 0.55)!;
      _stroke(canvas, lines, lineColor.withValues(alpha: 0.75), 1.1 * unit);
    }
    final glints = symbol.glints;
    if (glints != null) _stroke(canvas, glints, Colors.white.withValues(alpha: 0.9), 1.1 * unit);
    _stroke(canvas, symbol.fill, Colors.black.withValues(alpha: 0.45), 0.7 * unit);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) =>
      old.tier != tier || old.division != division || old.clock != clock;
}
