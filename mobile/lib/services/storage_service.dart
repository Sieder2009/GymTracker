import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiInitialized = false;

/// Plain `sqflite` only has a real platform-channel implementation on
/// Android/iOS/macOS — on Windows and Linux it silently has no backing
/// implementation, so every open/read/write throws and [StorageService]'s
/// fail-soft `catch` would swallow it into permanent in-memory-only storage
/// (data that looks saved but vanishes on every restart). Desktop needs
/// `sqflite_common_ffi`'s FFI-based factory instead — this swaps it in
/// once, before the first [openDatabase] call, so the rest of the app never
/// has to know which backend it's running on.
void _ensureDesktopSqliteFactory() {
  if (_ffiInitialized || kIsWeb) return;
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  _ffiInitialized = true;
}

/// Real, indexed tables for the four collections that grow without bound
/// over the life of the app — one row added per finished workout / logged
/// lift entry / weigh-in / gym photo, forever. Everything else in
/// [StorageService] (settings, the handful of saved plans, athlete
/// settings, …) is small, bounded, document-shaped data that a single JSON
/// blob per key genuinely fits fine; these four don't, because a blob
/// means "rewrite every entry ever logged" on every single new entry.
const String tWorkoutSessions = 'workout_sessions';
const String tBigLiftHistory = 'big_lift_history';
const String tBodyWeightEntries = 'body_weight_entries';
const String tGymPhotos = 'gym_photos';
const String tBodyMeasurementEntries = 'body_measurement_entries';

// The pre-2.8 kv keys these tables replace. Kept as constants because
// they're still meaningful in two places: [exportAll]/[importAll] use the
// exact same names as the backup format's key names (so a backup stays
// portable and human-readable), and the one-time migration in [create]
// looks for these same keys on disk to move their data into the tables
// above.
const String _kWorkoutHistoryKey = 'ironpeak:workoutHistory';
const String _kBigLiftHistoryKey = 'ironpeak:bigLiftHistory';
const String _kBigLiftsKey = 'ironpeak:bigLifts';
const String _kBodyWeightKey = 'ironpeak:bodyWeight';
const String _kGymPhotosKey = 'ironpeak:gymPhotos';
// Not a pre-2.8 legacy blob (this table is new) -- kept as a constant only
// so exportAll/importAll/_absorbList can share the exact same plumbing the
// four legacy-migrated collections already use.
const String _kBodyMeasurementsKey = 'ironpeak:bodyMeasurements';

/// Local persistence backed by SQLite (via sqflite) stored on-device:
/// small/bounded data as JSON-per-key in a `kv` table (loaded once into an
/// in-memory cache at startup so reads stay synchronous, same as before),
/// the four ever-growing collections above as real rows in their own
/// tables. Every write is fail-soft (never throws) if storage access
/// fails — the in-memory copy still updates so the running session behaves
/// normally even if nothing lands on disk.
class StorageService {
  StorageService._(
    this._db,
    Map<String, String> cache, {
    required List<Map<String, Object?>> workoutSessions,
    required List<Map<String, Object?>> bigLiftHistory,
    required List<Map<String, Object?>> bodyWeightEntries,
    required List<Map<String, Object?>> gymPhotos,
    required List<Map<String, Object?>> bodyMeasurementEntries,
  })  : _cache = cache,
        _workoutSessions = workoutSessions,
        _bigLiftHistory = bigLiftHistory,
        _bodyWeightEntries = bodyWeightEntries,
        _gymPhotos = gymPhotos,
        _bodyMeasurementEntries = bodyMeasurementEntries;

  final Database? _db;
  final Map<String, String> _cache;
  final List<Map<String, Object?>> _workoutSessions;
  final List<Map<String, Object?>> _bigLiftHistory;
  final List<Map<String, Object?>> _bodyWeightEntries;
  final List<Map<String, Object?>> _gymPhotos;
  final List<Map<String, Object?>> _bodyMeasurementEntries;

  static Future<StorageService> create({Database? database}) async {
    try {
      final db = database ?? await _openDefault();
      // Idempotent regardless of how `db` was opened (fresh via
      // [_openDefault]'s onCreate/onUpgrade, an older on-disk file, or a
      // hand-built test database that only has `kv`) — every path ends up
      // with the same guaranteed schema before anything queries it.
      await _ensureSchema(db);

      final kvRows = await db.query('kv');
      final cache = <String, String>{
        for (final row in kvRows) row['key'] as String: row['value'] as String,
      };
      final workoutSessions =
          (await db.query(tWorkoutSessions, orderBy: 'id ASC')).map(Map<String, Object?>.from).toList();
      final bigLiftHistory =
          (await db.query(tBigLiftHistory, orderBy: 'id ASC')).map(Map<String, Object?>.from).toList();
      final bodyWeightEntries =
          (await db.query(tBodyWeightEntries, orderBy: 'id ASC')).map(Map<String, Object?>.from).toList();
      final gymPhotos = (await db.query(tGymPhotos, orderBy: 'id ASC')).map(Map<String, Object?>.from).toList();
      final bodyMeasurementEntries =
          (await db.query(tBodyMeasurementEntries, orderBy: 'id ASC')).map(Map<String, Object?>.from).toList();

      final service = StorageService._(
        db,
        cache,
        workoutSessions: workoutSessions,
        bigLiftHistory: bigLiftHistory,
        bodyWeightEntries: bodyWeightEntries,
        gymPhotos: gymPhotos,
        bodyMeasurementEntries: bodyMeasurementEntries,
      );

      // One-time migration from the old single-blob-per-key storage. Only
      // ever does anything on the first launch after this update (the
      // legacy keys are gone from `cache` once absorbed) — every launch
      // after that, each check below is a single map lookup that finds
      // nothing and returns immediately.
      await service._absorbLegacyCollections(cache, forceReplace: false);

      return service;
    } catch (_) {
      return StorageService._(
        null,
        {},
        workoutSessions: [],
        bigLiftHistory: [],
        bodyWeightEntries: [],
        gymPhotos: [],
        bodyMeasurementEntries: [],
      );
    }
  }

  static Future<Database> _openDefault() async {
    _ensureDesktopSqliteFactory();
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ironpeak.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await _ensureSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _ensureSchema(db);
      },
    );
  }

  /// `IF NOT EXISTS` everywhere so this can safely run on every [create]
  /// call, not just a freshly-created database — see the comment there.
  static Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tWorkoutSessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        planName TEXT NOT NULL,
        totalVolumeKg REAL NOT NULL DEFAULT 0,
        totalSets INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_workout_sessions_date ON $tWorkoutSessions(date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tBigLiftHistory(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        liftKey TEXT NOT NULL,
        label TEXT NOT NULL,
        isoDate TEXT,
        value REAL NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_big_lift_history_key ON $tBigLiftHistory(liftKey)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tBodyWeightEntries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_body_weight_date ON $tBodyWeightEntries(date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tGymPhotos(
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_gym_photos_date ON $tGymPhotos(date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tBodyMeasurementEntries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        chestCm REAL,
        waistCm REAL,
        hipsCm REAL,
        armCm REAL,
        thighCm REAL,
        calfCm REAL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_body_measurement_date ON $tBodyMeasurementEntries(date)');
  }

  String? readString(String key) => _cache[key];

  Future<void> writeString(String key, String value) async {
    _cache[key] = value;
    final db = _db;
    if (db == null) return;
    try {
      await db.insert(
        'kv',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // fail-soft: in-memory cache still updates even if the write itself
      // didn't land on disk.
    }
  }

  T? readJson<T>(String key, T Function(dynamic decoded) fromJson) {
    final raw = readString(key);
    if (raw == null) return null;
    try {
      return fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object? Function() toJson) {
    return writeString(key, jsonEncode(toJson()));
  }

  // --- Ever-growing collections -------------------------------------
  //
  // Exposed as plain row maps (matching each model's own toJson() shape —
  // see the providers) rather than typed model lists, the same way
  // [readJson] hands callers a decoded `dynamic` and lets them do the
  // mapping: StorageService itself stays generic, it doesn't need to know
  // what a BigLiftPoint is.

  List<Map<String, Object?>> get workoutSessions => List.unmodifiable(_workoutSessions);
  List<Map<String, Object?>> get bigLiftHistory => List.unmodifiable(_bigLiftHistory);
  List<Map<String, Object?>> get bodyWeightEntries => List.unmodifiable(_bodyWeightEntries);
  List<Map<String, Object?>> get gymPhotos => List.unmodifiable(_gymPhotos);
  List<Map<String, Object?>> get bodyMeasurementEntries => List.unmodifiable(_bodyMeasurementEntries);

  Future<void> insertWorkoutSession(Map<String, Object?> values) => _insertRow(tWorkoutSessions, _workoutSessions, values);

  Future<void> insertBigLiftHistory(Map<String, Object?> values) => _insertRow(tBigLiftHistory, _bigLiftHistory, values);

  Future<void> insertBodyWeightEntry(Map<String, Object?> values) =>
      _insertRow(tBodyWeightEntries, _bodyWeightEntries, values);

  Future<void> insertGymPhoto(Map<String, Object?> values) => _insertRow(tGymPhotos, _gymPhotos, values);

  Future<void> insertBodyMeasurementEntry(Map<String, Object?> values) =>
      _insertRow(tBodyMeasurementEntries, _bodyMeasurementEntries, values);

  Future<void> deleteGymPhoto(String id) async {
    _gymPhotos.removeWhere((row) => row['id'] == id);
    final db = _db;
    if (db == null) return;
    try {
      await db.delete(tGymPhotos, where: 'id = ?', whereArgs: [id]);
    } catch (_) {
      // fail-soft
    }
  }

  Future<void> _insertRow(String table, List<Map<String, Object?>> cache, Map<String, Object?> values) async {
    cache.add(values);
    final db = _db;
    if (db == null) return;
    try {
      await db.insert(table, values);
    } catch (_) {
      // fail-soft: in-memory cache still updates even if the write itself
      // didn't land on disk.
    }
  }

  /// Every `ironpeak:*` key/value currently cached, plus the four table-
  /// backed collections re-encoded under their historical key names — the
  /// full backup payload for [BackupSheet]'s export. Kept as plain JSON
  /// text per key (not a dump of the SQLite file itself) so the format
  /// stays human-readable and portable across app versions the way it
  /// always has been.
  Map<String, String> exportAll() {
    final map = {
      for (final entry in _cache.entries)
        if (entry.key.startsWith('ironpeak:')) entry.key: entry.value,
    };
    map[_kWorkoutHistoryKey] = jsonEncode(_workoutSessions);
    map[_kBodyWeightKey] = jsonEncode(_bodyWeightEntries);
    map[_kGymPhotosKey] = jsonEncode(_gymPhotos);
    map[_kBodyMeasurementsKey] = jsonEncode(_bodyMeasurementEntries);
    map[_kBigLiftHistoryKey] = jsonEncode([
      for (final row in _bigLiftHistory)
        {'liftKey': row['liftKey'], 'l': row['label'], 'isoDate': row['isoDate'], 'v': row['value']},
    ]);
    return map;
  }

  /// Writes every key/value from a previously-exported [exportAll] map
  /// back through to storage — a full overwrite (see the restore
  /// confirmation dialog in [BackupSheet]), so the four table-backed
  /// collections get cleared and replaced with whatever the backup has,
  /// not merged. Callers are responsible for telling the user to restart
  /// the app afterwards — providers cache their state in memory at
  /// construction time and won't pick this up on their own.
  Future<void> importAll(Map<String, dynamic> data) async {
    const tableBackedKeys = {
      _kWorkoutHistoryKey,
      _kBodyWeightKey,
      _kGymPhotosKey,
      _kBigLiftHistoryKey,
      _kBodyMeasurementsKey,
    };
    for (final entry in data.entries) {
      if (!entry.key.startsWith('ironpeak:')) continue;
      if (tableBackedKeys.contains(entry.key)) continue;
      await writeString(entry.key, entry.value as String);
    }
    await _absorbLegacyCollections(data, forceReplace: true);
  }

  /// Shared by both the one-time on-disk migration (from [create], right
  /// after opening a pre-2.8 database) and [importAll] (restoring a backup
  /// that might itself be pre-2.8-shaped) — "given a source map of
  /// `ironpeak:*` JSON strings, pull the four growing collections' data
  /// out of it and into their tables" is the same operation either way.
  ///
  /// [forceReplace] is what tells the two calls apart: startup migration
  /// must never clobber real data a user already logged with a stale
  /// on-disk blob (so it only ever fills an *empty* table), while a
  /// user-triggered restore is explicitly a full overwrite by design.
  Future<void> _absorbLegacyCollections(Map<dynamic, dynamic> source, {required bool forceReplace}) async {
    await _absorbList(
      source: source,
      key: _kWorkoutHistoryKey,
      table: tWorkoutSessions,
      cache: _workoutSessions,
      forceReplace: forceReplace,
      toRow: (e) => {
        'date': e['date'] as String,
        'durationMinutes': (e['durationMinutes'] as num).toInt(),
        'planName': e['planName'] as String,
        'totalVolumeKg': (e['totalVolumeKg'] as num?)?.toDouble() ?? 0,
        'totalSets': (e['totalSets'] as num?)?.toInt() ?? 0,
      },
    );
    await _forgetLegacyKey(_kWorkoutHistoryKey);

    await _absorbList(
      source: source,
      key: _kBodyWeightKey,
      table: tBodyWeightEntries,
      cache: _bodyWeightEntries,
      forceReplace: forceReplace,
      toRow: (e) => {'date': e['date'] as String, 'weight': (e['weight'] as num).toDouble()},
    );
    await _forgetLegacyKey(_kBodyWeightKey);

    await _absorbList(
      source: source,
      key: _kGymPhotosKey,
      table: tGymPhotos,
      cache: _gymPhotos,
      forceReplace: forceReplace,
      toRow: (e) => {'id': e['id'] as String, 'date': e['date'] as String},
    );
    await _forgetLegacyKey(_kGymPhotosKey);

    await _absorbBigLiftHistory(source, forceReplace: forceReplace);

    // Not a pre-2.8 migration (this table is new) -- this call only ever
    // does anything from importAll (forceReplace: true, restoring a
    // previously exported backup that already has this key); the
    // forceReplace:false migration call from create() always no-ops since
    // no legacy blob ever carried this key.
    await _absorbList(
      source: source,
      key: _kBodyMeasurementsKey,
      table: tBodyMeasurementEntries,
      cache: _bodyMeasurementEntries,
      forceReplace: forceReplace,
      toRow: (e) => {
        'date': e['date'] as String,
        'chestCm': (e['chestCm'] as num?)?.toDouble(),
        'waistCm': (e['waistCm'] as num?)?.toDouble(),
        'hipsCm': (e['hipsCm'] as num?)?.toDouble(),
        'armCm': (e['armCm'] as num?)?.toDouble(),
        'thighCm': (e['thighCm'] as num?)?.toDouble(),
        'calfCm': (e['calfCm'] as num?)?.toDouble(),
      },
    );
  }

  Future<void> _absorbList({
    required Map source,
    required String key,
    required String table,
    required List<Map<String, Object?>> cache,
    required bool forceReplace,
    required Map<String, Object?> Function(Map<String, dynamic>) toRow,
  }) async {
    final raw = source[key];
    if (raw == null) return;
    if (!forceReplace && cache.isNotEmpty) return;

    final List<dynamic> list;
    try {
      list = jsonDecode(raw as String) as List;
    } catch (_) {
      return;
    }
    final rows = [for (final e in list) toRow(e as Map<String, dynamic>)];
    await _replaceTable(table, cache, rows);
  }

  /// Pre-2.8 backups/on-disk blobs nest history *inside* each lift's own
  /// object in `ironpeak:bigLifts` (`{bench: {pr, prDate, history: [...]},
  /// ...}`) rather than the flat `ironpeak:bigLiftHistory` list this app
  /// version writes — both are handled so an old backup still restores
  /// every logged lift entry instead of silently dropping them.
  Future<void> _absorbBigLiftHistory(Map source, {required bool forceReplace}) async {
    List<Map<String, Object?>>? rows;

    final flatRaw = source[_kBigLiftHistoryKey];
    if (flatRaw != null) {
      try {
        final list = jsonDecode(flatRaw as String) as List;
        rows = [
          for (final e in list)
            {
              'liftKey': (e as Map<String, dynamic>)['liftKey'] as String,
              'label': e['l'] as String,
              'isoDate': e['isoDate'] as String?,
              'value': (e['v'] as num).toDouble(),
            },
        ];
      } catch (_) {
        rows = null;
      }
    }

    if (rows == null) {
      final legacyRaw = source[_kBigLiftsKey];
      if (legacyRaw == null) return;
      try {
        final decoded = jsonDecode(legacyRaw as String) as Map<String, dynamic>;
        rows = [
          for (final liftKey in const ['bench', 'deadlift', 'squat'])
            if (decoded[liftKey] is Map)
              for (final h in (decoded[liftKey] as Map<String, dynamic>)['history'] as List? ?? [])
                {
                  'liftKey': liftKey,
                  'label': (h as Map<String, dynamic>)['l'] as String,
                  'isoDate': h['isoDate'] as String?,
                  'value': (h['v'] as num).toDouble(),
                },
        ];
      } catch (_) {
        return;
      }
    }

    if (!forceReplace && _bigLiftHistory.isNotEmpty) {
      rows = null; // already has real data -- never clobber it on a plain startup
    }
    if (rows != null) {
      await _replaceTable(tBigLiftHistory, _bigLiftHistory, rows);
    }

    // Whatever's left in the ironpeak:bigLifts kv blob after this should
    // only ever be pr/prDate going forward (see BigLiftsProvider._persist,
    // which already writes it history-free) — strip a lingering embedded
    // history from an old blob so it doesn't just sit there duplicated.
    final currentRaw = _cache[_kBigLiftsKey];
    if (currentRaw == null) return;
    try {
      final decoded = jsonDecode(currentRaw) as Map<String, dynamic>;
      final stripped = {
        for (final entry in decoded.entries)
          entry.key: entry.value is Map ? {...entry.value as Map<String, dynamic>, 'history': []} : entry.value,
      };
      await writeString(_kBigLiftsKey, jsonEncode(stripped));
    } catch (_) {
      // fail-soft
    }
  }

  Future<void> _replaceTable(String table, List<Map<String, Object?>> cache, List<Map<String, Object?>> rows) async {
    cache
      ..clear()
      ..addAll(rows);

    final db = _db;
    if (db == null) return;
    try {
      final batch = db.batch();
      batch.delete(table);
      for (final row in rows) {
        batch.insert(table, row);
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // fail-soft
    }
  }

  Future<void> _forgetLegacyKey(String key) async {
    if (!_cache.containsKey(key)) return;
    _cache.remove(key);
    final db = _db;
    if (db == null) return;
    try {
      await db.delete('kv', where: 'key = ?', whereArgs: [key]);
    } catch (_) {
      // fail-soft
    }
  }
}
