import 'package:flutter/widgets.dart';

import '../services/storage_service.dart';

const String _kLocaleKey = 'ironpeak:locale';

/// The 10 languages Ironpeak Fitness ships with. `null` selection means
/// "follow the system language" (falling back to English if the system
/// language isn't one of these).
const List<String> kSupportedLocales = [
  'de', 'en', 'es', 'fr', 'it', 'pt', 'nl', 'tr', 'pl', 'ru',
];

/// UI language, independent of the device's locale. `null` = follow system.
/// Persisted like [ThemeProvider] does for light/dark.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._storage) : _languageCode = _initial(_storage);

  final StorageService _storage;
  String? _languageCode;

  String? get languageCode => _languageCode;
  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);

  static String? _initial(StorageService storage) {
    final saved = storage.readString(_kLocaleKey);
    return kSupportedLocales.contains(saved) ? saved : null;
  }

  void setLanguageCode(String? code) {
    _languageCode = code;
    _storage.writeString(_kLocaleKey, code ?? '');
    notifyListeners();
  }
}
