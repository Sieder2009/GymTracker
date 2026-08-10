import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/update_service.dart';

enum UpdateStatus { idle, checking, upToDate, updateAvailable, downloading, downloaded, error }

/// Periodically polls GitHub Releases (interval from `.env`'s
/// `UPDATE_CHECK_INTERVAL_HOURS`) and, once a newer version is found,
/// downloads the matching platform asset automatically so it's ready the
/// moment the user wants it — but never silently replaces the running app.
/// Installing/opening the downloaded file is always one explicit tap (see
/// [SettingsScreen]), since overwriting a running executable or triggering
/// a package installer is exactly the kind of action a user should confirm.
class UpdateProvider extends ChangeNotifier {
  UpdateProvider() {
    unawaited(_bootstrap());
  }

  Timer? _timer;
  UpdateStatus status = UpdateStatus.idle;
  UpdateCheckResult? result;
  double downloadProgress = 0;
  String? downloadedFilePath;

  /// The version actually running right now, read from the platform build's
  /// own metadata (Info.plist / the Android manifest) at startup -- Flutter
  /// stamps this from pubspec.yaml's `version:` field at build time, so it
  /// can never drift out of sync the way a separately hand-maintained
  /// constant could. Null only for the brief moment before the first read
  /// resolves.
  String? installedVersion;

  Future<void> _bootstrap() async {
    installedVersion = (await PackageInfo.fromPlatform()).version;
    notifyListeners();
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
    } else if (!r.hasUpdate) {
      status = UpdateStatus.upToDate;
    } else {
      status = UpdateStatus.updateAvailable;
    }
    notifyListeners();

    if (status == UpdateStatus.updateAvailable && r.assetForThisPlatform != null) {
      unawaited(_downloadUpdate(r.assetForThisPlatform!));
    }
  }

  Future<void> _downloadUpdate(ReleaseAsset asset) async {
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
      status = UpdateStatus.downloaded;
    } catch (_) {
      status = UpdateStatus.updateAvailable; // still available — just retry the download
    }
    notifyListeners();
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
