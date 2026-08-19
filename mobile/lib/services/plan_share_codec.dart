import 'dart:convert';

import '../models/program.dart';

const int _kPlanShareFormatVersion = 1;

/// Wraps one [Program] for sharing outside the app -- a `'type':'plan'`
/// marker keeps this envelope distinct from the full-database backup format
/// (`backup_sheet.dart`, no `type` key), so a shared plan can never be
/// mistaken for -- or accidentally restored as -- a full backup.
String buildPlanSharePayload(Program program) => jsonEncode({
      'app': 'ironpeak',
      'type': 'plan',
      'version': _kPlanShareFormatVersion,
      'data': program.toJson(),
    });

/// Parses a payload produced by [buildPlanSharePayload]. Returns null on any
/// malformed input rather than throwing -- the caller only ever has "show an
/// error toast" to fall back to, same as `backup_sheet.dart`'s `_restore`.
/// The imported plan is always given a **fresh id** (never the sender's),
/// using the same convention `PlanEditorScreen` uses for a brand-new plan --
/// otherwise importing a plan already present locally (e.g. shared back and
/// forth between two of a user's own devices) could collide with it.
Program? parseSharedPlanPayload(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['app'] != 'ironpeak' || decoded['type'] != 'plan') return null;
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return null;
    final program = Program.fromJson(data);
    program.id = 'plan_${DateTime.now().millisecondsSinceEpoch}';
    return program;
  } catch (_) {
    return null;
  }
}

/// Lowercase, hyphenated, filesystem-safe -- used only for the shared
/// filename (`ironpeak-plan-<slug>.json`), never shown in the UI.
String slugify(String name) {
  final lower = name.toLowerCase().trim();
  final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final trimmed = replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'plan' : trimmed;
}
