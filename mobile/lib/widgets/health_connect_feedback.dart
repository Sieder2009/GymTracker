import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/health_provider.dart';
import '../state/toast_provider.dart';

/// Shared by the dashboard's connect card (training_screen.dart) and the
/// Settings connection switch (settings_screen.dart) — both trigger the
/// same OS permission round-trip and want the same pass/fail toast
/// afterwards, since [HealthProvider.connect] otherwise finishes silently
/// and the only visible sign of success is the dashboard card vanishing
/// (easy to miss) or, on failure, nothing changing at all.
Future<void> connectHealthWithFeedback(BuildContext context, HealthProvider health, AppLocalizations t) async {
  final toast = context.read<ToastProvider>();
  await health.connect();
  toast.show(health.isConnected ? t.toastHealthConnected : t.toastHealthConnectFailed);
}
