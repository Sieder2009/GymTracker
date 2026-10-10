import 'package:flutter/foundation.dart';

import '../data/exercise_gifs.dart';
import '../services/exercise_media_service.dart';
import '../services/storage_service.dart';

const String _kEnabledKey = 'ironpeak:exerciseMediaEnabled';

/// Average size of one dataset animation -- only used for the "about N MB"
/// estimate shown before a bulk download.
const int kApproxExerciseGifBytes = 95 * 1024;

/// App-wide switch for the exercise demo animations, plus Settings'
/// "download all for offline use" run and the size of what's on disk.
///
/// The switch defaults to on and is persisted like every other preference
/// (see `AppearanceProvider`); off means no widget even asks
/// [ExerciseMediaService] for an animation, so nothing is downloaded. The
/// download state is session-only: what's actually on disk is re-read via
/// [refreshCacheInfo] whenever Settings shows it, rather than trusting a
/// stored flag that a cleared app cache would make stale.
class ExerciseMediaProvider extends ChangeNotifier {
  ExerciseMediaProvider(this._storage, this.service)
      : _enabled = _storage.readString(_kEnabledKey) != 'false';

  final StorageService _storage;
  final ExerciseMediaService service;

  /// Every distinct animation the mapping references (several exercises
  /// can share one) -- exactly what [startDownloadAll] fetches.
  static final Set<String> allGifs = kExerciseGifs.values.toSet();

  bool _enabled;
  bool _disposed = false;

  bool _downloading = false;
  bool _cancelRequested = false;
  Future<void>? _downloadRun;
  int _done = 0;
  int _total = 0;
  int _failed = 0;
  bool _finished = false;

  int _cacheBytes = 0;
  int _cachedCount = 0;

  bool get enabled => _enabled;

  bool get isDownloading => _downloading;
  bool get isCancelling => _downloading && _cancelRequested;
  int get downloadDone => _done;
  int get downloadTotal => _total;

  /// How many animations the last finished run couldn't fetch.
  int get downloadFailed => _failed;

  /// True once a run went through every animation (wasn't cancelled) in
  /// this session -- see [downloadFailed] for how that went.
  bool get downloadFinished => _finished;

  int get gifCount => allGifs.length;

  /// Bytes of animations on disk, as of the last [refreshCacheInfo].
  int get cacheBytes => _cacheBytes;

  /// How many of [allGifs] are not on disk yet, as of the last
  /// [refreshCacheInfo].
  int get missingCount => gifCount - _cachedCount;

  void setEnabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    _storage.writeString(_kEnabledKey, value ? 'true' : 'false');
    _notify();
  }

  Future<void> refreshCacheInfo() async {
    final bytes = await service.cacheSizeBytes();
    final onDisk = await service.cachedBasenames();
    _cacheBytes = bytes;
    _cachedCount = onDisk.intersection(allGifs).length;
    _notify();
  }

  /// Starts fetching every animation that isn't on disk yet (no-op while a
  /// run is already going, and on web, which has no disk to put them on).
  Future<void> startDownloadAll() {
    if (_downloading || kIsWeb) return _downloadRun ?? Future.value();
    _downloading = true;
    _cancelRequested = false;
    _finished = false;
    _failed = 0;
    _done = 0;
    _total = gifCount;
    _notify();
    return _downloadRun = _runDownload();
  }

  Future<void> _runDownload() async {
    try {
      final result = await service.downloadAll(
        allGifs,
        onProgress: (done, total) {
          _done = done;
          _total = total;
          _notify();
        },
        isCancelled: () => _cancelRequested || _disposed,
      );
      _failed = result.failed;
      _finished = !result.cancelled;
    } catch (_) {
      // downloadAll counts per-file failures itself; anything escaping it
      // just ends the run as unfinished.
      _finished = false;
    } finally {
      _downloading = false;
      _cancelRequested = false;
      _downloadRun = null;
    }
    if (!_disposed) await refreshCacheInfo();
  }

  /// Stops after the files currently in flight; what's already on disk
  /// stays there.
  void cancelDownload() {
    if (!_downloading || _cancelRequested) return;
    _cancelRequested = true;
    _notify();
  }

  /// Deletes every downloaded animation. A running bulk download is
  /// cancelled and waited out first -- otherwise its last in-flight files
  /// would land on disk right after the delete.
  Future<void> clearCache() async {
    cancelDownload();
    final run = _downloadRun;
    if (run != null) await run;
    await service.clearCache();
    _finished = false;
    _failed = 0;
    if (!_disposed) await refreshCacheInfo();
  }

  // The download loop and the cache refresh both outlive any one screen;
  // a notification after dispose would throw.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    service.close();
    super.dispose();
  }
}
