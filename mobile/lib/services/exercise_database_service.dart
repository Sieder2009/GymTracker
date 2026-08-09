import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/exercise_template.dart';

/// Loads the shared exercise picker list. Always *tries* GitHub first (the
/// repo is the source of truth, per the app's "everything the repo has,
/// the app uses" rule) so editing `assets/exercises.json` in the repo
/// updates every install without an app release. Falls back to the last
/// successful download (cached as plain JSON text by the caller — see
/// [ExerciseDatabaseProvider]) and, if there's no cache yet either (first
/// run, no internet), to the copy bundled into the app itself — so the
/// picker always has *something* to show, online or not.
class ExerciseDatabaseService {
  Future<List<ExerciseTemplate>> fetchFromGitHub({Duration timeout = const Duration(seconds: 8)}) async {
    final response = await http.get(Uri.parse(AppConfig.exerciseDatabaseUrl)).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('GitHub returned ${response.statusCode}');
    }
    return _parse(response.body);
  }

  Future<List<ExerciseTemplate>> loadBundled() async {
    final raw = await rootBundle.loadString('assets/exercises.json');
    return _parse(raw);
  }

  List<ExerciseTemplate> _parse(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['exercises'] as List;
    return list.map((e) => ExerciseTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }
}
