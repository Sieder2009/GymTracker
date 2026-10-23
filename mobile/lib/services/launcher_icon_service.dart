import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../state/appearance_provider.dart';
import '../state/theme_provider.dart';
import '../theme/launcher_icons.dart';
import 'storage_service.dart';

const String _kAdaptiveKey = 'ironpeak:launcherIcon:adaptive';
const String _kChosenKey = 'ironpeak:launcherIcon:variant';

/// Keeps the Android home-screen icon in step with the app's appearance:
/// light or dark backdrop like the theme, glyph in the accent color (see
/// [LauncherIcons.forAppearance]) -- or, with [adaptive] off, the icon the
/// user picked themselves ([choose]; the default icon until they do).
///
/// Android can only switch between launcher entries declared ahead of time
/// (one `<activity-alias>` per [LauncherIcons.all] variant, release builds
/// only), and disabling the entry the app was launched from closes the app.
/// So this never switches anything itself: it tells IronpeakActivity which
/// alias it wants ([LauncherIconVariant.androidAlias]) and the activity
/// applies it once the user has left the app (Home or the app switcher).
/// Debug builds declare no aliases and every other platform has no channel,
/// so there [supported] stays false and everything here is a no-op.
///
/// `platformSupported` overrides the Android check, for tests.
class LauncherIconService extends ChangeNotifier with WidgetsBindingObserver {
  LauncherIconService(
    this._storage,
    this._theme,
    this._appearance, {
    bool? platformSupported,
  })  : _platformSupported = platformSupported ?? (!kIsWeb && Platform.isAndroid),
        _adaptive = _storage.readString(_kAdaptiveKey) != 'false',
        _chosen = LauncherIcons.byId(_storage.readString(_kChosenKey) ?? '') {
    _desired = _computeDesired();
    _theme.addListener(_onAppearanceChanged);
    _appearance.addListener(_onAppearanceChanged);
    _holds.addListener(_onHoldsChanged);
    if (_platformSupported) WidgetsBinding.instance.addObserver(this);
    ready = _platformSupported ? _readState() : Future<void>.value();
  }

  /// Implemented by IronpeakActivity.kt.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('ironpeak/launcher_icon');

  // Sent with every call, so the activity never needs its own copy of the
  // list -- the release manifest's aliases are generated from the same one.
  static final List<String> _aliases = [
    for (final variant in LauncherIcons.all) variant.androidAlias,
  ];

  // Screens on display that hold a switch back. Static so such a screen
  // only needs a one-line hook, not a reference to this provider.
  static final ValueNotifier<int> _holds = ValueNotifier<int>(0);

  /// For a screen whose state lives only in memory: call this in initState
  /// and [releaseSwitch] in dispose. While any such screen is open no icon
  /// switch is armed, because switching closes the app and the user would
  /// lose that state just by checking another app. The guided workout
  /// (WorkoutOverlayScreen) is one: its position -- current set, rest
  /// timer -- is not persisted.
  static void holdSwitch() => _holds.value++;

  static void releaseSwitch() {
    if (_holds.value > 0) _holds.value--;
  }

  @visibleForTesting
  static void debugResetHolds() => _holds.value = 0;

  final StorageService _storage;
  final ThemeProvider _theme;
  final AppearanceProvider _appearance;
  final bool _platformSupported;

  bool _adaptive;
  // The user's own pick, used while [_adaptive] is off (null: the default).
  LauncherIconVariant? _chosen;
  late LauncherIconVariant _desired;
  bool _supported = false;
  // Aliases Android reported as enabled at the last getState.
  List<String> _enabled = const [];
  // What the activity was last told to switch to (null: nothing).
  String? _sentTarget;
  bool _targetSentOnce = false;
  bool _reading = false;
  bool _disposed = false;

  /// Completes once the startup handshake with Android is done (at once
  /// where unsupported). Never completes with an error.
  late final Future<void> ready;

  /// Whether this build can switch its launcher icon at all: an Android
  /// release build whose manifest declares the aliases.
  bool get supported => _supported;

  /// Whether the icon follows the appearance (default) or stays the one
  /// the user picked.
  bool get adaptive => _adaptive;

  /// The user's own pick (kept while [adaptive] is on, so switching it off
  /// again returns to it), or null for none yet.
  LauncherIconVariant? get chosen => _chosen;

  /// The icon the home screen should show.
  LauncherIconVariant get desired => _desired;

  /// [desired] is decided but Android shows another icon until the user
  /// leaves the app.
  bool get pending => _supported && !_isApplied(_desired);

  void setAdaptive(bool value) {
    if (value == _adaptive) return;
    _adaptive = value;
    _storage.writeString(_kAdaptiveKey, value ? 'true' : 'false');
    _desired = _computeDesired();
    _syncTarget();
    notifyListeners();
  }

  /// Pins [variant] as the icon, whatever the appearance: turns [adaptive]
  /// off and remembers the pick.
  void choose(LauncherIconVariant variant) {
    if (!_adaptive && _chosen == variant) return;
    _chosen = variant;
    _storage.writeString(_kChosenKey, variant.id);
    if (_adaptive) {
      _adaptive = false;
      _storage.writeString(_kAdaptiveKey, 'false');
    }
    _desired = _computeDesired();
    _syncTarget();
    notifyListeners();
  }

  LauncherIconVariant _computeDesired() => _adaptive
      ? LauncherIcons.forAppearance(
          themeMode: _theme.mode,
          customBase: _theme.customBase,
          accent: _appearance.accent,
          background: _appearance.bg,
        )
      : _chosen ?? LauncherIcons.defaultVariant;

  // Most theme/appearance changes (secondary color, card color, ...) leave
  // the icon as it is; only a different variant is worth a rebuild or a
  // channel call.
  void _onAppearanceChanged() {
    final next = _computeDesired();
    if (next == _desired) return;
    _desired = next;
    _syncTarget();
    notifyListeners();
  }

  // Channel only, no notifyListeners: this runs inside a screen's dispose,
  // where the widget tree is locked, and nothing shown in Settings depends
  // on it.
  void _onHoldsChanged() => _syncTarget();

  // A switch normally takes this whole engine down with the task, but an
  // activity whose task wasn't launched from the disabled alias survives
  // it; re-reading on every return keeps [pending] from going stale then.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_readState());
  }

  bool _isApplied(LauncherIconVariant variant) =>
      _enabled.length == 1 && _enabled.single == variant.androidAlias;

  Future<void> _readState() async {
    if (_reading || _disposed) return;
    _reading = true;
    try {
      final state = await _invoke('getState', {'aliases': _aliases});
      if (state is! Map || _disposed) return;
      final wasSupported = _supported;
      final wasPending = pending;
      _supported = state['supported'] == true;
      final enabled = state['enabled'];
      _enabled = enabled is List ? enabled.whereType<String>().toList() : const [];
      if (_supported && _enabled.isEmpty) {
        // No launcher entry at all (should never happen, but then the app
        // could only be opened from Settings > Apps): repair right away.
        // Enabling alone doesn't touch the task the app runs in, so this is
        // safe in the foreground.
        final target = _desired.androidAlias;
        final repaired =
            await _invoke('enableNow', {'target': target, 'aliases': _aliases});
        if (_disposed) return;
        if (repaired == true) _enabled = [target];
      }
      _syncTarget();
      if (_supported != wasSupported || pending != wasPending) notifyListeners();
    } finally {
      _reading = false;
    }
  }

  /// Arms the activity with the alias to switch to on the next exit, or
  /// disarms it (null) when the icon is already right or a screen holds it.
  void _syncTarget() {
    if (!_supported || _disposed) return;
    final target = _holds.value > 0 || _isApplied(_desired)
        ? null
        : _desired.androidAlias;
    // The first call always goes out: a fresh activity starts disarmed, but
    // one that outlived a Dart restart may still hold an old target.
    if (_targetSentOnce && target == _sentTarget) return;
    _targetSentOnce = true;
    _sentTarget = target;
    unawaited(_invoke('setTarget', {'target': target, 'aliases': _aliases}));
  }

  // Replies are type-checked by the callers rather than cast, so a
  // malformed one can't throw either.
  Future<Object?> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      return await channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint('LauncherIconService: $method failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      // No IronpeakActivity on the other end (tests, a plugin-less host):
      // nothing to switch.
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _theme.removeListener(_onAppearanceChanged);
    _appearance.removeListener(_onAppearanceChanged);
    _holds.removeListener(_onHoldsChanged);
    if (_platformSupported) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
