import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';

/// Why a check produced no actionable result — kept as a typed reason
/// rather than a baked-in string so the UI can localize it (see
/// [SettingsScreen]'s `_updateErrorMessage`).
enum UpdateCheckError { none, noReleaseYet, badResponse, networkFailure, noVersionInResponse }

class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.downloadUrl});
  final String name;
  final String downloadUrl;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    this.releaseUrl,
    this.assets = const [],
    this.error = UpdateCheckError.none,
  });

  final bool hasUpdate;
  final String? latestVersion;
  final String? releaseUrl;
  final List<ReleaseAsset> assets;
  final UpdateCheckError error;

  /// The asset matching the OS this build is running on — "windows"/"macos"
  /// in the filename on Windows/macOS, `.apk` on Android, `.ipa` on iOS —
  /// null when nothing published yet matches (or on a platform with no CI
  /// build, e.g. desktop Linux).
  ReleaseAsset? get assetForThisPlatform {
    for (final asset in assets) {
      final name = asset.name.toLowerCase();
      if (Platform.isWindows && name.contains('windows')) return asset;
      if (Platform.isMacOS && name.contains('macos')) return asset;
      if (Platform.isAndroid && name.endsWith('.apk')) return asset;
      if (Platform.isIOS && name.endsWith('.ipa')) return asset;
    }
    return null;
  }
}

/// Checks GitHub's "latest release" API against the version the caller is
/// actually running (see [UpdateProvider.installedVersion], read from the
/// platform build's own metadata rather than a hand-maintained constant).
/// Only finds anything once a real version-tagged release exists (the CI
/// workflow only creates a GitHub Release — not just a build artifact —
/// when triggered by a `vX.Y.Z` tag push).
class UpdateService {
  static Future<UpdateCheckResult> checkForUpdate(String localVersion) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse(AppConfig.latestReleaseApiUrl))
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'ironpeak-fitness-app');
      final response = await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        return const UpdateCheckResult(hasUpdate: false, error: UpdateCheckError.noReleaseYet);
      }
      if (response.statusCode != 200) {
        return const UpdateCheckResult(hasUpdate: false, error: UpdateCheckError.badResponse);
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final releaseUrl = json['html_url'] as String?;
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      final assets = (json['assets'] as List? ?? [])
          .map((a) => ReleaseAsset(
                name: a['name'] as String,
                downloadUrl: a['browser_download_url'] as String,
              ))
          .toList();

      if (latest.isEmpty) {
        return const UpdateCheckResult(hasUpdate: false, error: UpdateCheckError.noVersionInResponse);
      }

      return UpdateCheckResult(
        hasUpdate: isNewer(latest, localVersion),
        latestVersion: latest,
        releaseUrl: releaseUrl,
        assets: assets,
      );
    } catch (_) {
      return const UpdateCheckResult(hasUpdate: false, error: UpdateCheckError.networkFailure);
    } finally {
      client.close();
    }
  }

  /// Public so [UpdateProvider] can reuse the exact same comparison to tell
  /// whether a previously-downloaded update is still ahead of whatever is
  /// actually installed now, without duplicating the parsing logic.
  static bool isNewer(String remote, String local) {
    final r = _parseVersion(remote);
    final l = _parseVersion(local);
    for (var i = 0; i < 3; i++) {
      if (r[i] != l[i]) return r[i] > l[i];
    }
    return false;
  }

  static List<int> _parseVersion(String v) {
    final parts = v.split('.');
    return List.generate(3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }
}
