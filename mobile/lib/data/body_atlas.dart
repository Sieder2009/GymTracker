import 'dart:typed_data';
import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../models/muscle_group.dart';
import 'body_atlas_data.dart';

/// Which body illustration to show -- the underlying asset ships both, so
/// this is effectively free and lets users pick the diagram that matches
/// them instead of forcing one default.
enum BodyGender { male, female }

/// Everything in this file is derived from the "react-native-body-highlighter"
/// SVG body illustration by Hicham ELABBASSI
/// (https://github.com/HichamELBSI/react-native-body-highlighter), MIT
/// License. The raw path data in [body_atlas_data.dart] is used verbatim
/// (converted from TypeScript to Dart data, geometry unchanged); everything
/// in this file -- the muscle-group mapping, the front/side-deltoid and
/// upper-back/lats splits, activation coloring, hit-testing and caching --
/// is original to this app.
///
/// MIT License Copyright (c) 2022 ELABBASSI Hicham. Permission is hereby
/// granted, free of charge, to any person obtaining a copy of this software
/// and associated documentation files, to deal in the software without
/// restriction, subject to including this copyright notice.

/// One named shape from the source illustration: [slug] is the upstream
/// muscle/body-part id, [side] is "left"/"right"/"common", [paths] are raw
/// SVG path-data strings (usually one, but ab/oblique blocks are several
/// separate blobs sharing one slug+side).
class AtlasPart {
  const AtlasPart(this.slug, this.side, this.paths);
  final String slug;
  final String side;
  final List<String> paths;
}

/// Source illustration canvas: front view occupies local x 0-724, back
/// view is laid out right next to it at x 724-1448 in the original asset
/// (both share one 1448x1448-tall coordinate space) -- [_xOffsetFor] below
/// undoes that offset so both views parse into the same local 0-724 box.
const double kAtlasWidth = 724;
const double kAtlasHeight = 1448;

/// Width:height every fractional coordinate in this diagram is authored
/// against. [DetailedBodyDiagram] and `MuscleActivationEditor` size their
/// [CustomPaint] to this ratio so the figure is never squashed/stretched.
const double kBodyDiagramAspect = kAtlasWidth / kAtlasHeight;

double _xOffsetFor(bool front) => front ? 0 : kAtlasWidth;

List<AtlasPart> _rawFor(BodyGender gender, bool front) {
  switch (gender) {
    case BodyGender.male:
      return front ? maleFrontRaw : maleBackRaw;
    case BodyGender.female:
      return front ? femaleFrontRaw : femaleBackRaw;
  }
}

/// Maps an upstream slug to the [MuscleGroup] it should color, per view.
/// Slugs not covered here (hands, feet, head, hair, neck, knees, ankles,
/// tibialis, adductors, and the opposite view's stray triceps/trapezius
/// sliver) are decorative only -- always drawn in the neutral body color,
/// never tappable/colorable -- which is exactly what makes the figure read
/// as a full character instead of a set of floating blobs.
///
/// 'deltoids' and 'upper-back' each cover two of this app's muscle groups
/// in the source art (it doesn't split front/side delts or lats/upper-back
/// into separate shapes), so those two are handled by geometric clipping
/// in [_ParsedAtlas.build] rather than a 1:1 slug mapping.
MuscleGroup? _directMuscleForSlug(String slug, bool front) {
  if (front) {
    switch (slug) {
      case 'chest':
        return MuscleGroup.chest;
      case 'obliques':
        return MuscleGroup.obliques;
      case 'abs':
        return MuscleGroup.abs;
      case 'biceps':
        return MuscleGroup.biceps;
      case 'quadriceps':
        return MuscleGroup.quads;
      case 'calves':
        return MuscleGroup.calves;
      case 'forearm':
        return MuscleGroup.forearms;
      default:
        return null;
    }
  }
  switch (slug) {
    case 'trapezius':
      return MuscleGroup.traps;
    case 'triceps':
      return MuscleGroup.triceps;
    case 'lower-back':
      return MuscleGroup.lowerBack;
    case 'gluteal':
      return MuscleGroup.glutes;
    case 'hamstring':
      return MuscleGroup.hamstrings;
    default:
      return null;
  }
}

const String _slugDeltoids = 'deltoids';
const String _slugUpperBack = 'upper-back';

Path _unionSubpaths(List<String> svgPaths) {
  final path = Path();
  for (final d in svgPaths) {
    path.addPath(parseSvgPathData(d), Offset.zero);
  }
  return path;
}

Path _clip(Path source, Rect rect) {
  return Path.combine(PathOperation.intersect, source, Path()..addRect(rect));
}

/// True boolean union (not just concatenation) so touching/overlapping
/// sub-shapes -- e.g. the 3 quad-head blobs, the 2 pec halves -- merge into
/// one clean outer boundary with no internal seam, while shapes that are
/// genuinely disjoint (left pec vs right pec) correctly stay separate.
Path _unionAll(List<Path> paths) {
  if (paths.isEmpty) return Path();
  return paths.skip(1).fold<Path>(paths.first, (acc, p) => Path.combine(PathOperation.union, acc, p));
}

/// Splits one combined deltoid shape into a medial (front) and lateral
/// (side) half. Which physical side of the canvas centerline the shape
/// sits on is detected from its own bounding box rather than from the
/// upstream "left"/"right" label, so this works unmodified for either
/// side and either gender's proportions.
(Path front, Path side) _splitDeltoid(Path raw, double centerlineX) {
  final b = raw.getBounds().inflate(12);
  final isLeftOfCenter = raw.getBounds().center.dx < centerlineX;
  final splitX = raw.getBounds().left +
      raw.getBounds().width * (isLeftOfCenter ? 0.56 : 0.44);
  final lateralRect = isLeftOfCenter
      ? Rect.fromLTRB(b.left, b.top, splitX, b.bottom)
      : Rect.fromLTRB(splitX, b.top, b.right, b.bottom);
  final medialRect = isLeftOfCenter
      ? Rect.fromLTRB(splitX, b.top, b.right, b.bottom)
      : Rect.fromLTRB(b.left, b.top, splitX, b.bottom);
  return (_clip(raw, medialRect), _clip(raw, lateralRect));
}

/// Splits the combined "upper-back" shape (which in the source art spans
/// the full shoulder-to-waist lateral back mass) into an upper rhomboid
/// strip ([MuscleGroup.upperBack]) and the wider lower/lateral taper
/// ([MuscleGroup.lats]) -- there's no separate lats shape upstream, so
/// this is this app's own approximation of where one would sit.
(Path upperBack, Path lats) _splitUpperBack(Path raw) {
  final b = raw.getBounds().inflate(12);
  // Real lats dominate the lateral back (armpit to waist); rhomboids/traps
  // only cover a narrow strip near the spine -- 30/70 reflects that better
  // than an even split.
  final splitY = raw.getBounds().top + raw.getBounds().height * 0.30;
  return (
    _clip(raw, Rect.fromLTRB(b.left, b.top, b.right, splitY)),
    _clip(raw, Rect.fromLTRB(b.left, splitY, b.right, b.bottom)),
  );
}

/// Every shape for one (gender, view) combination, already parsed and
/// scaled to a concrete pixel [Size] -- built once per size via
/// [ParsedBodyAtlas.get] and reused across paints/hit-tests instead of
/// re-parsing SVG path strings every frame.
class ParsedBodyAtlas {
  ParsedBodyAtlas._(this.silhouette, this.muscles, this.musclesOutline);

  /// Every part of the illustration, in its neutral (skin) color -- drawn
  /// first so the figure always reads as a complete body.
  final List<Path> silhouette;

  /// Colorable overlays, keyed by the muscle group they represent. Only
  /// muscle groups actually present in the current view are keys here.
  final Map<MuscleGroup, List<Path>> muscles;

  /// Same shapes as [muscles], but unioned into one path per muscle group
  /// -- stroking this instead of every individual sub-shape draws one bold
  /// outer outline per muscle (matching how dedicated muscle-map apps read
  /// as clean solid regions) instead of a seam between every ab block/pec
  /// half that happens to share a color.
  final Map<MuscleGroup, Path> musclesOutline;

  static final Map<String, ParsedBodyAtlas> _cache = {};

  static ParsedBodyAtlas get(BodyGender gender, bool front, Size size) {
    final key =
        '${gender.name}_${front}_${size.width.toStringAsFixed(1)}_${size.height.toStringAsFixed(1)}';
    return _cache.putIfAbsent(key, () => _build(gender, front, size));
  }

  static ParsedBodyAtlas _build(BodyGender gender, bool front, Size size) {
    final sx = size.width / kAtlasWidth;
    final sy = size.height / kAtlasHeight;
    // Column-major 4x4 scale matrix, as Path.transform expects -- avoids
    // pulling in the vector_math package for one diagonal matrix.
    final scale = Float64List.fromList([sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
    final xOffset = _xOffsetFor(front);
    final centerlineX = xOffset + kAtlasWidth / 2;

    Path scaled(Path raw) => raw.shift(Offset(-xOffset, 0)).transform(scale);

    final silhouette = <Path>[];
    final muscles = <MuscleGroup, List<Path>>{};
    void add(MuscleGroup m, Path p) => muscles.putIfAbsent(m, () => []).add(p);

    for (final part in _rawFor(gender, front)) {
      for (final d in part.paths) {
        silhouette.add(scaled(parseSvgPathData(d)));
      }

      if (part.slug == _slugDeltoids) {
        if (front) {
          final (frontDelt, sideDelt) =
              _splitDeltoid(_unionSubpaths(part.paths), centerlineX);
          add(MuscleGroup.frontDelts, scaled(frontDelt));
          add(MuscleGroup.sideDelts, scaled(sideDelt));
        } else {
          // Back view shows one deltoid head: rear delts, no split needed.
          add(MuscleGroup.rearDelts, scaled(_unionSubpaths(part.paths)));
        }
        continue;
      }
      if (part.slug == _slugUpperBack) {
        final (upperBack, lats) = _splitUpperBack(_unionSubpaths(part.paths));
        add(MuscleGroup.upperBack, scaled(upperBack));
        add(MuscleGroup.lats, scaled(lats));
        continue;
      }

      final direct = _directMuscleForSlug(part.slug, front);
      if (direct != null) {
        for (final d in part.paths) {
          add(direct, scaled(parseSvgPathData(d)));
        }
      }
    }

    final musclesOutline = <MuscleGroup, Path>{
      for (final entry in muscles.entries) entry.key: _unionAll(entry.value),
    };

    return ParsedBodyAtlas._(silhouette, muscles, musclesOutline);
  }

  /// Which muscle (if any) contains [point] -- exact hit-testing against
  /// the real illustrated shape instead of a loose bounding box, used by
  /// the tappable `MuscleActivationEditor`.
  MuscleGroup? hitTest(Offset point) {
    for (final entry in muscles.entries) {
      for (final path in entry.value) {
        if (path.contains(point)) return entry.key;
      }
    }
    return null;
  }
}
