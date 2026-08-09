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

/// Local persistence backed by a single-table SQLite database (via sqflite)
/// stored on-device — mirrors the original `persisted.js`: every key/value
/// row loaded once into an in-memory cache at startup so reads stay
/// synchronous, JSON write-through on every mutation, fail-soft (never
/// throw) if storage access fails.
class StorageService {
  StorageService._(this._db, Map<String, String> cache) : _cache = cache;

  final Database? _db;
  final Map<String, String> _cache;

  static Future<StorageService> create({Database? database}) async {
    try {
      final db = database ?? await _openDefault();
      final rows = await db.query('kv');
      final cache = <String, String>{
        for (final row in rows) row['key'] as String: row['value'] as String,
      };
      return StorageService._(db, cache);
    } catch (_) {
      return StorageService._(null, {});
    }
  }

  static Future<Database> _openDefault() async {
    _ensureDesktopSqliteFactory();
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ironpeak.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      ),
    );
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

  /// Every `ironpeak:*` key/value currently cached — the full backup
  /// payload for [BackupSheet]'s export.
  Map<String, String> exportAll() {
    return {
      for (final entry in _cache.entries)
        if (entry.key.startsWith('ironpeak:')) entry.key: entry.value,
    };
  }

  /// Writes every key/value from a previously-exported [exportAll] map
  /// back through to storage. Callers are responsible for telling the user
  /// to restart the app afterwards — providers cache their state in memory
  /// at construction time and won't pick this up on their own.
  Future<void> importAll(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      if (!entry.key.startsWith('ironpeak:')) continue;
      await writeString(entry.key, entry.value as String);
    }
  }
}
