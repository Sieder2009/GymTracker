import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/exercise_gif_lookup.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise_template.dart';
import '../state/exercise_database_provider.dart';
import '../state/exercise_media_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// The demo animation for a plan exercise named [exerciseName], or null
/// when animations are switched off in Settings or the name doesn't match
/// the shared database (see `exerciseGifForName`) -- so a caller can skip
/// its whole surrounding layout instead of leaving an empty slot. Call it
/// from `build`: it subscribes to the on/off switch (and nothing else on
/// [ExerciseMediaProvider], so a bulk download's per-file progress doesn't
/// rebuild every screen showing an animation) and to the database, so an
/// animation appears as soon as the first database load lands.
String? resolveExerciseGif(BuildContext context, String exerciseName) {
  if (!context.select<ExerciseMediaProvider, bool>((m) => m.enabled)) return null;
  final templates = context.watch<ExerciseDatabaseProvider>().exercises;
  return exerciseGifForName(exerciseName, templates);
}

/// [resolveExerciseGif] for an entry of the shared database itself.
String? resolveTemplateGif(BuildContext context, ExerciseTemplate template) {
  if (!context.select<ExerciseMediaProvider, bool>((m) => m.enabled)) return null;
  return exerciseGifForTemplate(template);
}

// The card behind an animation is always white (the dataset's GIFs have
// white backgrounds baked in), so everything drawn ON it uses the light
// palette's ink in both themes -- dark mode's near-white text tokens would
// vanish on it.
final Color _kCardInk = AppColors.light.txt;
final Color _kCardInkMuted = AppColors.light.txt.withValues(alpha: 0.65);

/// One exercise demo animation (third-party, © Gym visual -- see
/// `data/exercise_gifs.dart`) in a white rounded card with its credit line,
/// [size] logical pixels square. Tapping opens [showExerciseDemoDialog]
/// unless [onTap] says otherwise. Renders nothing while animations are
/// switched off.
///
/// Built for screens that rebuild constantly (the guided workout ticks
/// every second): the load is started once per [gif] -- in [State.initState]
/// and again only when [didUpdateWidget] sees a different basename -- and
/// the bytes are held here, tied to that basename. A memory-cache hit is
/// read synchronously, so remounting (rest view -> next set) paints the
/// animation on the first frame with no spinner flash, and the cache hands
/// back the same [Uint8List] each time, which keeps the [MemoryImage] key
/// (and so the running animation) stable across rebuilds.
class ExerciseDemoGif extends StatefulWidget {
  const ExerciseDemoGif({
    super.key,
    required this.gif,
    required this.size,
    this.exerciseName,
    this.onTap,
    this.showCredit = true,
  }) : assert(size > 0);

  /// Media basename, e.g. `0025-EIeI8Vf`.
  final String gif;
  final double size;

  /// Heading of the enlarge dialog and part of the semantics label.
  final String? exerciseName;
  final VoidCallback? onTap;
  final bool showCredit;

  @override
  State<ExerciseDemoGif> createState() => _ExerciseDemoGifState();
}

class _ExerciseDemoGifState extends State<ExerciseDemoGif> {
  Uint8List? _bytes;
  bool _failed = false;
  // Bumped on every (re)load: a result that arrives for an older basename
  // (the user swiped on while it was downloading) is dropped instead of
  // briefly showing the previous exercise's animation.
  int _generation = 0;
  // Web only: bumped to rebuild Image.network after a failed attempt.
  int _webAttempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExerciseDemoGif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gif != widget.gif) _load();
  }

  void _load() {
    final generation = ++_generation;
    _bytes = null;
    _failed = false;
    if (kIsWeb) return; // Image.network does the loading there.
    final service = context.read<ExerciseMediaProvider>().service;
    final cached = service.peekMemory(widget.gif);
    if (cached != null) {
      _bytes = cached;
      return;
    }
    service.loadGif(widget.gif).then(
      (bytes) {
        if (!mounted || generation != _generation) return;
        setState(() => _bytes = bytes);
      },
      onError: (Object _) {
        if (!mounted || generation != _generation) return;
        setState(() => _failed = true);
      },
    );
  }

  /// Forgets whatever is cached for this animation first -- covers bytes
  /// that downloaded fine but won't decode, not just a failed download.
  Future<void> _retry() async {
    final service = context.read<ExerciseMediaProvider>().service;
    final gif = widget.gif;
    if (!isValidExerciseGifBasename(gif)) return; // can never load
    if (kIsWeb) {
      await NetworkImage(service.gifUri(gif).toString()).evict();
      if (!mounted || gif != widget.gif) return;
      setState(() => _webAttempt++);
      return;
    }
    await service.evict(gif);
    if (!mounted || gif != widget.gif) return;
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<ExerciseMediaProvider, bool>((m) => m.enabled);
    if (!enabled) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final size = widget.size;
    final radius = BorderRadius.circular(size >= 150 ? AppRadii.md : AppRadii.sm);
    final padding = (size * 0.04).clamp(3.0, 10.0);
    final creditFontSize = (size * 0.065).clamp(8.0, 12.0);
    // Below this the credit line would crowd out the animation itself;
    // no screen uses thumbnails that small (the workout screen hides its
    // animation before it gets there).
    final showCredit = widget.showCredit && size >= 56;
    final spinner = Center(
      child: SizedBox.square(
        dimension: (size * 0.18).clamp(14.0, 28.0),
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
      ),
    );
    final offline = _OfflineView(onRetry: _retry);

    Widget content;
    VoidCallback? onTap;
    final enlarge = widget.onTap ??
        () => showExerciseDemoDialog(context, gif: widget.gif, exerciseName: widget.exerciseName);
    if (kIsWeb && !isValidExerciseGifBasename(widget.gif)) {
      content = offline;
    } else if (kIsWeb) {
      // No disk cache on web (see ExerciseMediaService), so the browser's
      // own HTTP cache does the caching.
      final service = Provider.of<ExerciseMediaProvider>(context, listen: false).service;
      content = Image.network(
        service.gifUri(widget.gif).toString(),
        // Keyed by basename too: a reused Image with gaplessPlayback would
        // keep showing the previous exercise until the new one loaded.
        key: ValueKey((widget.gif, _webAttempt)),
        gaplessPlayback: true,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) => progress == null ? child : spinner,
        errorBuilder: (context, error, stack) => offline,
      );
      onTap = enlarge;
    } else if (_bytes != null) {
      content = Image.memory(
        _bytes!,
        gaplessPlayback: true,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => offline,
      );
      onTap = enlarge;
    } else if (_failed) {
      content = offline;
    } else {
      content = spinner;
    }

    final name = widget.exerciseName;
    return Semantics(
      image: true,
      label: name == null ? t.exerciseDemoTitle : '${t.exerciseDemoTitle}: $name',
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.line),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                children: [
                  Expanded(child: Center(child: content)),
                  if (showCredit)
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t.exerciseDemoCredit,
                          maxLines: 1,
                          style: TextStyle(
                            color: _kCardInkMuted,
                            fontSize: creditFontSize,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "can't load it right now" state, tap to retry. Laid out at the
/// space it's given and scaled down as a whole if that's still too small
/// (tiny thumbnails, large accessibility text) -- it never overflows.
class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRetry,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth ? constraints.maxWidth : 160.0;
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 22, color: _kCardInkMuted),
                  const SizedBox(height: 4),
                  Text(
                    t.exerciseDemoOffline,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _kCardInkMuted, fontSize: 11, height: 1.25),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.exerciseDemoRetry,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kCardInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Full-size view of one animation: the exercise's name, the animation as
/// big as the screen comfortably allows (up to 400 px), its credit, and a
/// close button. Tapping the animation closes it too.
Future<void> showExerciseDemoDialog(
  BuildContext context, {
  required String gif,
  String? exerciseName,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final t = AppLocalizations.of(dialogContext)!;
      final screen = MediaQuery.sizeOf(dialogContext);
      // Wide enough to see the movement clearly, but short enough for the
      // title and close button to stay on screen in landscape too (the
      // scroll view below is only the last-resort guard).
      final side = math.max(
        120.0,
        math.min(math.min(screen.width - 48, 400.0), screen.height - 200),
      );
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Mirrors the close button's width so the title stays
                  // centered over the animation.
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      exerciseName ?? t.exerciseDemoTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(dialogContext).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: MaterialLocalizations.of(dialogContext).closeButtonTooltip,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ExerciseDemoGif(
                gif: gif,
                size: side,
                exerciseName: exerciseName,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
