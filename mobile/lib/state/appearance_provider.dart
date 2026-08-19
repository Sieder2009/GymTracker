import 'package:flutter/material.dart';

import '../services/storage_service.dart';

const String _kAccentKey = 'ironpeak:appearance:accent';
const String _kSecondaryKey = 'ironpeak:appearance:secondary';
const String _kBgKey = 'ironpeak:appearance:bg';
const String _kCardKey = 'ironpeak:appearance:card';
const String _kTxtKey = 'ironpeak:appearance:txt';

/// Custom primary (accent) / secondary color overrides, persisted as ARGB
/// ints. Null means "use the theme's default for the current light/dark
/// mode" — [AppTheme] falls back to [AppColors.light]/[AppColors.dark]'s
/// own accent/secondary whenever these are unset.
///
/// [bg]/[card]/[txt] are the same idea, only relevant once
/// [ThemeProvider.mode] is `'custom'` — a mode that always applies every
/// override here (including these three) on top of a light or dark base,
/// rather than most tokens (line/mut/teal/purple/yellow/green) which stay
/// theme-default even in custom mode.
class AppearanceProvider extends ChangeNotifier {
  AppearanceProvider(this._storage)
      : _accent = _readColor(_storage, _kAccentKey),
        _secondary = _readColor(_storage, _kSecondaryKey),
        _bg = _readColor(_storage, _kBgKey),
        _card = _readColor(_storage, _kCardKey),
        _txt = _readColor(_storage, _kTxtKey);

  final StorageService _storage;
  Color? _accent;
  Color? _secondary;
  Color? _bg;
  Color? _card;
  Color? _txt;

  Color? get accent => _accent;
  Color? get secondary => _secondary;
  Color? get bg => _bg;
  Color? get card => _card;
  Color? get txt => _txt;

  static Color? _readColor(StorageService storage, String key) {
    final raw = storage.readString(key);
    if (raw == null || raw.isEmpty) return null;
    final value = int.tryParse(raw);
    return value == null ? null : Color(value);
  }

  void setAccent(Color color) {
    _accent = color;
    _storage.writeString(_kAccentKey, color.toARGB32().toString());
    notifyListeners();
  }

  void setSecondary(Color color) {
    _secondary = color;
    _storage.writeString(_kSecondaryKey, color.toARGB32().toString());
    notifyListeners();
  }

  void setBg(Color color) {
    _bg = color;
    _storage.writeString(_kBgKey, color.toARGB32().toString());
    notifyListeners();
  }

  void setCard(Color color) {
    _card = color;
    _storage.writeString(_kCardKey, color.toARGB32().toString());
    notifyListeners();
  }

  void setTxt(Color color) {
    _txt = color;
    _storage.writeString(_kTxtKey, color.toARGB32().toString());
    notifyListeners();
  }

  void reset() {
    _accent = null;
    _secondary = null;
    _bg = null;
    _card = null;
    _txt = null;
    _storage.writeString(_kAccentKey, '');
    _storage.writeString(_kSecondaryKey, '');
    _storage.writeString(_kBgKey, '');
    _storage.writeString(_kCardKey, '');
    _storage.writeString(_kTxtKey, '');
    notifyListeners();
  }
}
