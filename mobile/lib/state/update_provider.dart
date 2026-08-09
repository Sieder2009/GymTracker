import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
    if (AppConfig.updateCheckEnabled) {
      unawaited(checkNow());
      _timer = Timer.periodic(Duration(hours: AppConfig.updateCheckIntervalHours), (_) => checkNow());
    }
  }

  Timer? _timer;
  UpdateStatus status = UpdateStatus.idle;
  UpdateCheckResult? result;
  double downloadProgress = 0;
  String? downloadedFilePath;

  Future<void> checkNow() async {
    status = UpdateStatus.checking;
    notifyListeners();

    final r = await UpdateService.checkForUpdate();
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
