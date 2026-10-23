import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../state/appearance_provider.dart';
import '../state/theme_provider.dart';
import '../theme/launcher_icons.dart';

/// Keeps Android's launch screen in the app's own light/dark mode.
///
/// Android 12+ draws the launch screen (values*-v31/styles.xml, the animated
/// barbell) before any Dart runs, from the day or night resources -- by
/// default whichever the phone is in. The app has its own theme setting,
/// independent of the phone, so a dark app on a light phone would open on
/// the light launch screen. This tells IronpeakActivity which mode the app
/// is in (or that it follows the phone, while no theme has been picked);
/// it hands that to UiModeManager.setApplicationNightMode, which Android
/// remembers for the next launch -- so the very first launch after an
/// update still shows the phone's mode. Older Android versions show no
/// launch icon, so there it does nothing.
///
/// `platformSupported` overrides the Android check, for tests.
class LaunchScreenService {
  LaunchScreenService(this._theme, this._appearance, {bool? platformSupported})
      : _platformSupported = platformSupported ?? (!kIsWeb && Platform.isAndroid) {
    if (!_platformSupported) return;
    _theme.addListener(_sync);
    _appearance.addListener(_sync);
    _sync();
  }

  /// Implemented by IronpeakActivity.kt.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('ironpeak/launch_screen');

  final ThemeProvider _theme;
  final AppearanceProvider _appearance;
  final bool _platformSupported;

  // What Android was last told. The first call always goes out: the
  // remembered mode may stem from an older setting.
  bool _sentOnce = false;
  bool? _sentDark;

  void _sync() {
    // No theme picked yet: the app takes the phone's mode at every launch,
    // so the launch screen should keep following the phone too (null).
    final dark = _theme.followsSystem
        ? null
        : LauncherIcons.backdropFor(
              themeMode: _theme.mode,
              customBase: _theme.customBase,
              background: _appearance.bg,
            ) ==
            IconBackdrop.dark;
    if (_sentOnce && dark == _sentDark) return;
    _sentOnce = true;
    _sentDark = dark;
    unawaited(_invoke(dark));
  }

  Future<void> _invoke(bool? dark) async {
    try {
      await channel.invokeMethod<void>('setDark', {'dark': dark});
    } on PlatformException catch (e) {
      debugPrint('LaunchScreenService: setDark failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      // No IronpeakActivity on the other end (tests, a plugin-less host).
    }
  }

  void dispose() {
    if (!_platformSupported) return;
    _theme.removeListener(_sync);
    _appearance.removeListener(_sync);
  }
}
