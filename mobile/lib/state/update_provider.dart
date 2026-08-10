import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';

const String _kAutoInstallKey = 'ironpeak:autoInstallUpdates';
const String _kDownloadedPathKey = 'ironpeak:downloadedUpdatePath';
const String _kDownloadedVersionKey = 'ironpeak:downloadedUpdateVersion';

enum UpdateStatus { idle, checking, upToDate, updateAvailable, downloading, downloaded, error }

/// Periodically polls GitHub Releases (interval from `.env`'s
/// `UPDATE_CHECK_INTERVAL_HOURS`) and, once a newer version is found,
/// downloads the matching platform asset automatically so it's ready the
/// moment the user wants it. Which download belongs to which version is
/// persisted (see [_kDownloadedPathKey]/[_kDownloadedVersionKey]) so a
/// download that finished in a previous session — one the user closed the
/// app on before tapping "Installieren" — is picked up immediately on the
/// next launch instead of silently forgotten and re-downloaded from
/// scratch.
///
/// Installing/opening the downloaded file is one explicit tap by default
/// (see [SettingsScreen]), since overwriting a running executable or
/// triggering a package installer is exactly the kind of action a user
/// should confirm — [autoInstall] is the opt-in (default off, see
/// [setAutoInstall]) escape hatch for anyone who'd rather it just happen
/// the moment a ready update is detected on app open.
class UpdateProvider extends ChangeNotifier {
  UpdateProvider(this._storage) : _autoInstall = _storage.readString(_kAutoInstallKey) == 'true' {
    unawaited(_bootstrap());
  }

  final StorageService _storage;
  Timer? _timer;
  UpdateStatus status = UpdateStatus.idle;
  UpdateCheckResult? result;
  double downloadProgress = 0;
  String? downloadedFilePath;
  String? _downloadedVersion;
  bool _autoInstall;

  bool get autoInstall => _autoInstall;

  /// The version actually running right now, read from the platform build's
  /// own metadata (Info.plist / the Android manifest) at startup -- Flutter
  /// stamps this from pubspec.yaml's `version:` field at build time (or, for
  /// a tagged release build, from the `--build-name` the release workflow
  /// derives straight from the `vX.Y.Z` tag — see android.yml/ios.yml/
  /// windows.yml/macos.yml), so it can never drift out of sync the way a
  /// separately hand-maintained constant could. Null only for the brief
  /// moment before the first read resolves.
  String? installedVersion;

  void setAutoInstall(bool value) {
    _autoInstall = value;
    unawaited(_storage.writeString(_kAutoInstallKey, value.toString()));
    notifyListeners();
    if (value && status == UpdateStatus.downloaded) {
      unawaited(openDownloadedUpdate());
    }
  }

  Future<void> _bootstrap() async {
    installedVersion = (await PackageInfo.fromPlatform()).version;

    final savedPath = _storage.readString(_kDownloadedPathKey);
    final savedVersion = _storage.readString(_kDownloadedVersionKey);
    if (savedPath != null && savedPath.isNotEmpty && savedVersion != null && savedVersion.isNotEmpty) {
      final stillAhead = UpdateService.isNewer(savedVersion, installedVersion!);
      final fileStillThere = stillAhead && await File(savedPath).exists();
      if (fileStillThere) {
        downloadedFilePath = savedPath;
        _downloadedVersion = savedVersion;
        status = UpdateStatus.downloaded;
        notifyListeners();
        if (_autoInstall) unawaited(openDownloadedUpdate());
      } else {
        // Either already installed (installedVersion caught up) or the
        // file vanished from disk some other way -- don't keep offering an
        // install that no longer makes sense.
        await _forgetDownloadedUpdate();
      }
    }

    if (AppConfig.updateCheckEnabled) {
      unawaited(checkNow());
      _timer = Timer.periodic(Duration(hours: AppConfig.updateCheckIntervalHours), (_) => checkNow());
    }
  }

  Future<void> checkNow() async {
    installedVersion ??= (await PackageInfo.fromPlatform()).version;
    status = UpdateStatus.checking;
    notifyListeners();

    final r = await UpdateService.checkForUpdate(installedVersion!);
    result = r;

    if (r.error != UpdateCheckError.none) {
      status = UpdateStatus.error;
      notifyListeners();
      return;
    }

    if (!r.hasUpdate) {
      status = UpdateStatus.upToDate;
      if (downloadedFilePath != null) await _forgetDownloadedUpdate();
      notifyListeners();
      return;
    }

    // Already holding exactly this version's download from an earlier
    // check this session (or restored at bootstrap) -- it's still good,
    // no need to fetch it all over again.
    if (downloadedFilePath != null && _downloadedVersion == r.latestVersion) {
      status = UpdateStatus.downloaded;
      notifyListeners();
      if (_autoInstall) unawaited(openDownloadedUpdate());
      return;
    }

    status = UpdateStatus.updateAvailable;
    notifyListeners();

    final asset = r.assetForThisPlatform;
    if (asset != null) {
      unawaited(_downloadUpdate(asset, r.latestVersion!));
    }
  }

  Future<void> _downloadUpdate(ReleaseAsset asset, String version) async {
    status = UpdateStatus.downloading;
    downloadProgress = 0;
    notifyListeners();

    try {
      final dir = await getApplicationSupportDirectory();
      final updatesDir = Directory(p.join(dir.path, 'updates'));
      await updatesDir.create(recursive: true);
      final filePath = p.join(updatesDir.path, asset.name);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(asset.downloadUrl));
      final response = await client.send(request);
      final total = response.contentLength ?? 0;
      var received = 0;

      final sink = File(filePath).openWrite();
      await response.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) {
          downloadProgress = received / total;
          notifyListeners();
        }
        return chunk;
      }).pipe(sink);
      client.close();

      downloadedFilePath = filePath;
      _downloadedVersion = version;
      unawaited(_storage.writeString(_kDownloadedPathKey, filePath));
      unawaited(_storage.writeString(_kDownloadedVersionKey, version));
      status = UpdateStatus.downloaded;
    } catch (_) {
      status = UpdateStatus.updateAvailable; // still available — just retry the download
    }
    notifyListeners();

    if (status == UpdateStatus.downloaded && _autoInstall) {
      unawaited(openDownloadedUpdate());
    }
  }

  Future<void> _forgetDownloadedUpdate() async {
    final path = downloadedFilePath;
    downloadedFilePath = null;
    _downloadedVersion = null;
    unawaited(_storage.writeString(_kDownloadedPathKey, ''));
    unawaited(_storage.writeString(_kDownloadedVersionKey, ''));
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // fail-soft: a leftover file in the app's own support directory is
      // harmless, just wasted disk space.
    }
  }

  /// Opens the downloaded update file with the OS's own handler — the
  /// installer on Windows, the package installer prompt on Android/iOS.
  /// Nothing here replaces the running app itself.
  Future<void> openDownloadedUpdate() async {
    final path = downloadedFilePath;
    if (path == null) return;
    await launchUrl(Uri.file(path));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
