import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Single, typed read-through for every `.env` value — nothing in the rest
/// of the app calls `dotenv.get(...)` directly or hardcodes a GitHub
/// URL/owner/repo, so the whole app's "where does this come from" story
/// lives in one file (and one `.env`).
class AppConfig {
  const AppConfig._();

  static String get githubOwner => dotenv.get('GITHUB_OWNER', fallback: 'Sieder2009');
  static String get githubRepo => dotenv.get('GITHUB_REPO', fallback: 'GymTraker');
  static String get githubBranch => dotenv.get('GITHUB_BRANCH', fallback: 'master');

  static String get exerciseDatabasePath =>
      dotenv.get('EXERCISE_DATABASE_PATH', fallback: 'mobile/assets/exercises.json');

  static bool get updateCheckEnabled =>
      dotenv.get('UPDATE_CHECK_ENABLED', fallback: 'true').toLowerCase() == 'true';
  static int get updateCheckIntervalHours =>
      int.tryParse(dotenv.get('UPDATE_CHECK_INTERVAL_HOURS', fallback: '6')) ?? 6;

  static String get supportEmail => dotenv.get('SUPPORT_EMAIL', fallback: '');
  static String get supportPhone => dotenv.get('SUPPORT_PHONE', fallback: '');

  static String get githubRepoUrl => 'https://github.com/$githubOwner/$githubRepo';
  static String get githubApiBase => 'https://api.github.com/repos/$githubOwner/$githubRepo';
  static String get githubRawBase => 'https://raw.githubusercontent.com/$githubOwner/$githubRepo/$githubBranch';

  static String get exerciseDatabaseUrl => '$githubRawBase/$exerciseDatabasePath';
  static String get latestReleaseApiUrl => '$githubApiBase/releases/latest';
}
