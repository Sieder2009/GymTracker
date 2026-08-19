import 'package:flutter/widgets.dart';

import '../services/storage_service.dart';

const String _kThemeKey = 'ironpeak:theme';
const String _kCustomBaseKey = 'ironpeak:theme:customBase';

/// 'light' | 'dark' | 'custom'. Defaults to the OS preference on first
/// launch only — after that, whatever the user picked via [toggle]/
/// [setMode] persists.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._storage)
      : _mode = _initial(_storage),
        _customBase = _initialCustomBase(_storage);

  final StorageService _storage;
  String _mode;
  // Which brightness ('light'/'dark') the user was in right before
  // switching to Custom -- AppColors' un-overridden tokens (line/mut/teal/
  // purple/yellow/green) are tuned for one brightness, so a dark custom
  // background paired with light-tuned dividers/muted text would go nearly
  // invisible without remembering which base to keep using them from.
  String _customBase;

  String get mode => _mode;
  bool get isDark => _mode == 'dark';
  bool get isCustom => _mode == 'custom';
  String get customBase => _customBase;

  static String _initial(StorageService storage) {
    final saved = storage.readString(_kThemeKey);
    if (saved == 'light' || saved == 'dark' || saved == 'custom') return saved!;
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark ? 'dark' : 'light';
  }

  static String _initialCustomBase(StorageService storage) {
    final saved = storage.readString(_kCustomBaseKey);
    return saved == 'dark' ? 'dark' : 'light';
  }

  /// Quick single-action toggle (settings quick-switch, overflow menu) --
  /// treats anything that isn't already 'dark' as "go dark," so this
  /// degrades out of Custom mode for free without needing its own case.
  void toggle() {
    _mode = _mode == 'dark' ? 'light' : 'dark';
    _storage.writeString(_kThemeKey, _mode);
    notifyListeners();
  }

  void setMode(String mode) {
    if (mode != 'light' && mode != 'dark' && mode != 'custom') return;
    if (mode == 'custom' && _mode != 'custom') {
      _customBase = _mode == 'dark' ? 'dark' : 'light';
      _storage.writeString(_kCustomBaseKey, _customBase);
    }
    _mode = mode;
    _storage.writeString(_kThemeKey, _mode);
    notifyListeners();
  }
}
