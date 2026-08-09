import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/exercise_template.dart';
import '../services/exercise_database_service.dart';
import '../services/storage_service.dart';

const String _kCacheKey = 'ironpeak:exerciseDatabaseCache';

/// Loads with whatever was cached from the last successful GitHub fetch
/// (instant, synchronous, like every other provider's startup), then kicks
/// off a fresh [refresh] in the background — so the picker is never empty
/// while waiting on the network, but still gets the repo's current list
/// almost immediately on a normal launch.
class ExerciseDatabaseProvider extends ChangeNotifier {
  ExerciseDatabaseProvider(this._storage, this._service) : _exercises = _initialFromCache(_storage) {
    refresh();
  }

  final StorageService _storage;
  final ExerciseDatabaseService _service;
  List<ExerciseTemplate> _exercises;
  bool _loading = false;

  List<ExerciseTemplate> get exercises => List.unmodifiable(_exercises);
  bool get isLoading => _loading;

  static List<ExerciseTemplate> _initialFromCache(StorageService storage) {
    final raw = storage.readString(_kCacheKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => ExerciseTemplate.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final fromGitHub = await _service.fetchFromGitHub();
      _exercises = fromGitHub;
      await _storage.writeString(
        _kCacheKey,
        jsonEncode(fromGitHub.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Fail-soft: GitHub unreachable, offline, rate-limited, whatever —
      // keep whatever we already had cached. Only fall further back to the
      // bundled copy if there was truly nothing cached yet at all.
      if (_exercises.isEmpty) {
        try {
          _exercises = await _service.loadBundled();
        } catch (_) {
          // no bundled asset either — picker just stays empty, callers
          // already handle that as a normal empty state.
        }
      }
    }
    _loading = false;
    notifyListeners();
  }
}
