import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../data/exercise_gif_lookup.dart';

/// Why an animation couldn't be loaded -- a non-200 answer, or a body that
/// isn't a GIF at all (an HTML error page from a CDN/captive portal).
class ExerciseMediaException implements Exception {
  const ExerciseMediaException(this.message);

  final String message;

  @override
  String toString() => 'ExerciseMediaException: $message';
}

/// What a [ExerciseMediaService.downloadAll] run did. [total] counts every
/// distinct basename asked for; `downloaded + skipped + failed` only falls
/// short of it when the run was [cancelled].
@immutable
class ExerciseMediaDownloadResult {
  const ExerciseMediaDownloadResult({
    required this.total,
    required this.downloaded,
    required this.skipped,
    required this.failed,
    required this.cancelled,
  });

  final int total;
  final int downloaded;

  /// Already on disk before the run -- nothing fetched.
  final int skipped;
  final int failed;
  final bool cancelled;
}

/// Loads the exercise demo animations listed in `data/exercise_gifs.dart`.
///
/// They are third-party content (© Gym visual) that this app never ships:
/// each GIF is fetched from [AppConfig.exerciseMediaBaseUrl] the first time
/// it's needed and then served from, in order, a small in-memory LRU (so a
/// screen that rebuilds every second never touches the disk again), a disk
/// cache under the app-support directory (so it keeps working offline at
/// the gym), and only then the network. Concurrent requests for the same
/// basename share one download, and nothing that doesn't start with the
/// GIF magic bytes is ever cached -- a CDN error page must not get stuck on
/// disk as "the animation".
///
/// Flutter Web has no filesystem (path_provider's support directory throws
/// there, same reason `resolveGymPhotosDir` guards it): disk caching is
/// skipped entirely, the size/clear/bulk-download calls are harmless
/// no-ops, and `ExerciseDemoGif` uses `Image.network` instead.
class ExerciseMediaService {
  ExerciseMediaService({
    http.Client? client,
    Future<Directory> Function()? cacheDirectory,
    String? baseUrl,
    this.memoryCacheSize = 40,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _resolveCacheDirectory = cacheDirectory ?? _defaultCacheDirectory,
        _baseUrl = _withTrailingSlash(baseUrl ?? AppConfig.exerciseMediaBaseUrl);

  final http.Client _client;
  final bool _ownsClient;
  final Future<Directory> Function() _resolveCacheDirectory;
  final String _baseUrl;
  final int memoryCacheSize;
  final Duration timeout;

  // Insertion order == recency: a hit is moved to the end, the first key is
  // the least recently used one.
  final LinkedHashMap<String, Uint8List> _memory = LinkedHashMap();
  final Map<String, Future<Uint8List>> _inFlight = {};
  Future<Directory?>? _cacheDirectory;
  int _tempCounter = 0;
  // Bumped by [clearCache]. A load or download that started before a clear
  // still hands its bytes to whoever asked, but must not write them back
  // to disk or memory afterwards -- "deleted" has to stay deleted.
  int _cacheGeneration = 0;

  static Future<Directory> _defaultCacheDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'exercise_media'));
  }

  // Without the trailing slash `Uri.resolve` would replace the last path
  // segment (`exercises-dataset@<commit>`) instead of appending to it.
  static String _withTrailingSlash(String url) => url.endsWith('/') ? url : '$url/';

  static void _checkBasename(String basename) {
    if (!isValidExerciseGifBasename(basename)) {
      throw ArgumentError.value(basename, 'basename', 'not an exercise media basename');
    }
  }

  /// `<base>videos/<basename>.gif`. Throws [ArgumentError] for anything
  /// that isn't a dataset basename.
  Uri gifUri(String basename) {
    _checkBasename(basename);
    return Uri.parse(_baseUrl).resolve('videos/$basename.gif');
  }

  /// The bytes if [basename] is in the memory cache right now, else null --
  /// synchronous, so a freshly mounted widget can paint a cached animation
  /// on its very first frame instead of flashing a spinner. Always the same
  /// [Uint8List] instance per cache entry, which keeps `MemoryImage` keys
  /// equal across rebuilds.
  Uint8List? peekMemory(String basename) {
    final bytes = _memory.remove(basename);
    if (bytes != null) _memory[basename] = bytes;
    return bytes;
  }

  /// Memory -> disk -> network, see the class doc. Throws
  /// [ArgumentError] for an invalid basename and [ExerciseMediaException],
  /// [TimeoutException] or a socket/client exception when it can't be
  /// loaded; failures are never cached, so calling again retries.
  Future<Uint8List> loadGif(String basename) {
    if (!isValidExerciseGifBasename(basename)) {
      return Future.error(
          ArgumentError.value(basename, 'basename', 'not an exercise media basename'));
    }
    final cached = peekMemory(basename);
    if (cached != null) return Future.value(cached);
    // Remembered per caller (not inside the shared load), so joining a
    // bulk download that's already fetching this file still ends up in
    // the memory cache.
    final generation = _cacheGeneration;
    return _shared(basename,
            () async => await _readFromDisk(basename) ?? await _fetchAndStore(basename, generation))
        .then((bytes) {
      if (generation == _cacheGeneration) _remember(basename, bytes);
      return bytes;
    });
  }

  /// Runs [load] at most once at a time per [basename]: a second caller
  /// while it's running gets the same future. The entry is dropped once it
  /// settles either way, so a failure is never handed out again.
  Future<Uint8List> _shared(String basename, Future<Uint8List> Function() load) {
    final running = _inFlight[basename];
    if (running != null) return running;
    final completer = Completer<Uint8List>();
    _inFlight[basename] = completer.future;
    // Only drop our own entry: after a clearCache a newer load for the
    // same basename may already have taken the slot.
    void release() {
      if (identical(_inFlight[basename], completer.future)) _inFlight.remove(basename);
    }

    load().then(
      (bytes) {
        release();
        completer.complete(bytes);
      },
      onError: (Object error, StackTrace stack) {
        release();
        completer.completeError(error, stack);
      },
    );
    return completer.future;
  }

  void _remember(String basename, Uint8List bytes) {
    _memory.remove(basename);
    _memory[basename] = bytes;
    while (_memory.length > memoryCacheSize) {
      _memory.remove(_memory.keys.first);
    }
  }

  static bool _looksLikeGif(List<int> bytes) =>
      bytes.length >= 6 &&
      bytes[0] == 0x47 && // G
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x38; // 8

  Future<Uint8List> _fetch(String basename) async {
    final response = await _client.get(gifUri(basename)).timeout(timeout);
    if (response.statusCode != 200) {
      throw ExerciseMediaException('HTTP ${response.statusCode} for $basename');
    }
    final bytes = response.bodyBytes;
    if (!_looksLikeGif(bytes)) {
      throw ExerciseMediaException('response for $basename is not a GIF');
    }
    return bytes;
  }

  /// Network fetch plus a best-effort disk write -- a full disk or a
  /// read-only directory must not stop the animation from showing (same
  /// fail-soft stance as `StorageService`).
  Future<Uint8List> _fetchAndStore(String basename, int generation) async {
    final bytes = await _fetch(basename);
    await _writeToDisk(basename, bytes, generation);
    return bytes;
  }

  /// Null on web, or when the platform has no usable support directory --
  /// either way the disk tier is simply skipped.
  Future<Directory?> _directory() {
    if (kIsWeb) return Future.value(null);
    return _cacheDirectory ??= _resolveCacheDirectory().then<Directory?>(
      (dir) => dir,
      onError: (Object _) => null,
    );
  }

  Future<File?> _fileFor(String basename) async {
    final dir = await _directory();
    return dir == null ? null : File(p.join(dir.path, '$basename.gif'));
  }

  Future<Uint8List?> _readFromDisk(String basename) async {
    final file = await _fileFor(basename);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (_looksLikeGif(bytes)) return bytes;
      // Not a GIF (shouldn't happen with atomic writes, but a disk can
      // still corrupt a file) -- drop it and refetch instead of failing
      // on it forever.
      await file.delete();
    } catch (_) {
      // Unreadable -- fall through to the network.
    }
    return null;
  }

  /// Writes via a uniquely named temp file + rename, so a crash or a
  /// concurrent writer can never leave a half-written `<basename>.gif`
  /// behind for [_readFromDisk] to trust. Returns whether the file is on
  /// disk afterwards. Nothing is written (and a file that raced a
  /// [clearCache] is removed again) when [generation] is out of date.
  Future<bool> _writeToDisk(String basename, Uint8List bytes, int generation) async {
    final file = await _fileFor(basename);
    if (file == null || generation != _cacheGeneration) return false;
    final temp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}-${_tempCounter++}.tmp');
    try {
      await file.parent.create(recursive: true);
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      if (generation != _cacheGeneration) {
        await file.delete();
        return false;
      }
      return true;
    } catch (_) {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      // Losing a rename race to another writer of the same bytes is fine.
      try {
        return await file.exists();
      } catch (_) {
        return false;
      }
    }
  }

  /// Whether [basename] can be shown without the network: on disk, or --
  /// on web, which has no disk tier -- in memory.
  Future<bool> isCached(String basename) async {
    if (!isValidExerciseGifBasename(basename)) return false;
    if (kIsWeb) return _memory.containsKey(basename);
    final file = await _fileFor(basename);
    if (file == null) return false;
    try {
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  Future<List<File>> _cachedFiles() async {
    final dir = await _directory();
    if (dir == null) return const [];
    try {
      if (!await dir.exists()) return const [];
      return await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.gif'))
          .cast<File>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Bytes of finished animation files on disk (in-progress temp files
  /// aren't counted). Always 0 on web.
  Future<int> cacheSizeBytes() async {
    var total = 0;
    for (final file in await _cachedFiles()) {
      try {
        total += await file.length();
      } catch (_) {
        // Deleted between listing and stat -- just not counted.
      }
    }
    return total;
  }

  /// Basenames with a finished file on disk. Empty on web.
  Future<Set<String>> cachedBasenames() async {
    return {
      for (final file in await _cachedFiles())
        if (isValidExerciseGifBasename(p.basenameWithoutExtension(file.path)))
          p.basenameWithoutExtension(file.path),
    };
  }

  /// Deletes the disk cache and empties the memory cache, so the next
  /// load of anything goes back to the network.
  Future<void> clearCache() async {
    _cacheGeneration++;
    _memory.clear();
    // Running loads finish for their callers but are no longer shared:
    // the next request after a clear starts a fresh one.
    _inFlight.clear();
    final dir = await _directory();
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Fail-soft: whatever couldn't be deleted is still valid cache.
    }
  }

  /// Puts every one of [basenames] on disk for offline use, [concurrency]
  /// at a time, skipping what's already there. Downloads go straight to
  /// disk -- filling the 40-entry memory cache with hundreds of animations
  /// nobody is looking at would only evict the ones that are on screen.
  /// [onProgress] gets `(done, total)` once up front and after every item;
  /// [isCancelled] is polled before each new item starts (ones already
  /// running still finish). An invalid basename counts as failed rather
  /// than throwing. A no-op on web, which has nowhere to put them.
  Future<ExerciseMediaDownloadResult> downloadAll(
    Iterable<String> basenames, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    int concurrency = 4,
  }) async {
    if (kIsWeb || (await _directory()) == null) {
      return const ExerciseMediaDownloadResult(
          total: 0, downloaded: 0, skipped: 0, failed: 0, cancelled: false);
    }
    final queue = basenames.toSet().toList();
    final total = queue.length;
    var next = 0;
    var done = 0;
    var downloaded = 0;
    var skipped = 0;
    var failed = 0;
    bool cancelled() => isCancelled?.call() ?? false;

    onProgress?.call(0, total);
    Future<void> worker() async {
      while (next < queue.length && !cancelled()) {
        final basename = queue[next++];
        try {
          _checkBasename(basename);
          if (await isCached(basename)) {
            skipped++;
          } else if (await _downloadToDisk(basename)) {
            downloaded++;
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        }
        done++;
        onProgress?.call(done, total);
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(concurrency, total); i++) worker(),
    ]);
    return ExerciseMediaDownloadResult(
      total: total,
      downloaded: downloaded,
      skipped: skipped,
      failed: failed,
      cancelled: done < total,
    );
  }

  /// Shares [_inFlight] with [loadGif], so a bulk download and an animation
  /// opened on screen at the same moment never fetch (or write) the same
  /// file twice.
  Future<bool> _downloadToDisk(String basename) async {
    final running = _inFlight[basename];
    if (running != null) {
      await running;
      return isCached(basename);
    }
    var stored = false;
    final generation = _cacheGeneration;
    await _shared(basename, () async {
      final bytes = await _fetch(basename);
      stored = await _writeToDisk(basename, bytes, generation);
      return bytes;
    });
    return stored;
  }

  /// Forgets one animation everywhere (memory and disk), e.g. after its
  /// bytes failed to decode, so the next [loadGif] fetches it afresh.
  Future<void> evict(String basename) async {
    if (!isValidExerciseGifBasename(basename)) return;
    _memory.remove(basename);
    final file = await _fileFor(basename);
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Closes the HTTP client if this service created it.
  void close() {
    if (_ownsClient) _client.close();
  }
}
