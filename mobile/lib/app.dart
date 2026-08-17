import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'services/exercise_database_service.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/active_screen_provider.dart';
import 'state/appearance_provider.dart';
import 'state/athlete_settings_provider.dart';
import 'state/bar_weight_provider.dart';
import 'state/big_lifts_provider.dart';
import 'state/body_weight_provider.dart';
import 'state/custom_exercises_provider.dart';
import 'state/exercise_database_provider.dart';
import 'state/gym_photos_provider.dart';
import 'state/health_provider.dart';
import 'state/locale_provider.dart';
import 'state/programs_provider.dart';
import 'state/reminder_provider.dart';
import 'state/theme_provider.dart';
import 'state/toast_provider.dart';
import 'state/train_state_provider.dart';
import 'state/update_provider.dart';
import 'state/workout_history_provider.dart';
import 'overlays/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';
import 'widgets/toast_overlay.dart';

/// Root widget: one [MultiProvider] above one [MaterialApp]/[Navigator] —
/// every pushed overlay route stays a descendant of this provider tree, so
/// it can read/watch the same app-wide state as the 3 tab screens.
class IronpeakApp extends StatelessWidget {
  const IronpeakApp(
      {super.key, required this.storage, required this.photosDir});

  final StorageService storage;
  final Directory photosDir;

  @override
  Widget build(BuildContext context) {
    // One shared instance -- ReminderProvider and the guided workout's rest
    // timer notification both go through the same plugin, no reason for
    // each to init its own.
    final notificationService = NotificationService();
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider(create: (_) => ThemeProvider(storage)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(storage)),
        ChangeNotifierProvider(create: (_) => ProgramsProvider(storage)),
        ChangeNotifierProvider(create: (_) => TrainStateProvider(storage)),
        ChangeNotifierProvider(create: (_) => BigLiftsProvider(storage)),
        ChangeNotifierProvider(create: (_) => BodyWeightProvider(storage)),
        ChangeNotifierProvider(create: (_) => AthleteSettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => BarWeightProvider(storage)),
        ChangeNotifierProvider(create: (_) => WorkoutHistoryProvider(storage)),
        ChangeNotifierProvider(
            create: (_) => GymPhotosProvider(storage, photosDir)),
        ChangeNotifierProvider(create: (_) => HealthProvider(HealthService(), storage)),
        ChangeNotifierProvider(
            create: (_) =>
                ExerciseDatabaseProvider(storage, ExerciseDatabaseService())),
        ChangeNotifierProvider(create: (_) => CustomExercisesProvider(storage)),
        ChangeNotifierProvider(create: (_) => ActiveScreenProvider()),
        ChangeNotifierProvider(create: (_) => ToastProvider()),
        ChangeNotifierProvider(create: (_) => AppearanceProvider(storage)),
        ChangeNotifierProvider(
            create: (context) =>
                UpdateProvider(storage, notificationService, context.read<LocaleProvider>())),
        ChangeNotifierProvider(
            create: (_) => ReminderProvider(storage, notificationService)),
      ],
      child: Consumer3<ThemeProvider, AppearanceProvider, LocaleProvider>(
        builder: (context, theme, appearance, localeProvider, _) {
          return MaterialApp(
            title: 'Ironpeak Fitness',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(
              accentOverride: appearance.accent,
              secondaryOverride: appearance.secondary,
            ),
            darkTheme: AppTheme.dark(
              accentOverride: appearance.accent,
              secondaryOverride: appearance.secondary,
            ),
            themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
            locale: localeProvider.locale,
            supportedLocales: kSupportedLocales.map(Locale.new),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const _Root(),
            // Above the whole Navigator, not just AppShell -- a toast
            // triggered from a pushed screen (Settings, plan editor, ...)
            // needs to render there too, not sit invisible behind it until
            // the user happens to navigate back to the shell.
            builder: (context, child) => Stack(
              children: [
                if (child != null) child,
                const ToastOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Decides once, at construction, whether this launch should see
/// [OnboardingScreen] or go straight to [AppShell] -- a `late` field read
/// from [StorageService]'s synchronous in-memory cache rather than
/// recomputed on every rebuild, so a theme/appearance/locale change
/// mid-onboarding (all of which live above this in the tree, via
/// [Consumer3] in [IronpeakApp]) can't accidentally flip it back.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late bool _showOnboarding =
      context.read<StorageService>().readString(kOnboardingCompleteKey) != 'true';

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(onFinished: () => setState(() => _showOnboarding = false));
    }
    return const AppShell();
  }
}
