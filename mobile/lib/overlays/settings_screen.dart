import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../data/app_version.dart';
import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import '../state/appearance_provider.dart';
import '../state/reminder_provider.dart';
import '../state/theme_provider.dart';
import '../state/update_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/backup_sheet.dart';
import '../widgets/language_picker_sheet.dart';

const List<Color> _kColorPresets = [
  Color(0xFF2F6FEB),
  Color(0xFF5588FF),
  Color(0xFF0EA884),
  Color(0xFF1FD6A8),
  Color(0xFF6D5CE8),
  Color(0xFF9585FF),
  Color(0xFFC98A10),
  Color(0xFFE0A83A),
  Color(0xFF1FA76A),
  Color(0xFF35C98A),
  Color(0xFFE24B4A),
  Color(0xFFD4537E),
];

String _updateErrorMessage(AppLocalizations t, UpdateCheckError error) {
  switch (error) {
    case UpdateCheckError.noReleaseYet:
      return t.updateErrorNoRelease;
    case UpdateCheckError.badResponse:
      return t.updateErrorBadResponse;
    case UpdateCheckError.networkFailure:
      return t.updateErrorNetwork;
    case UpdateCheckError.noVersionInResponse:
      return t.updateErrorNoVersion;
    case UpdateCheckError.none:
      return '';
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t.titleSettings),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _UpdateSection(),
            SizedBox(height: 24),
            _AppearanceSection(),
            SizedBox(height: 24),
            _ReminderSection(),
            SizedBox(height: 24),
            _GeneralSection(),
            SizedBox(height: 24),
            _HelpSection(),
          ],
        ),
      ),
    );
  }
}

class _UpdateSection extends StatelessWidget {
  const _UpdateSection();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final update = context.watch<UpdateProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.headerAppVersion, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.labelInstalledVersion(kAppVersion)),
                const SizedBox(height: 10),
                _buildStatus(context, t, colors, update),
                const SizedBox(height: 14),
                _buildActions(context, t, update),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context, AppLocalizations t, AppColors colors, UpdateProvider update) {
    switch (update.status) {
      case UpdateStatus.updateAvailable:
      case UpdateStatus.downloading:
      case UpdateStatus.downloaded:
        final version = update.result?.latestVersion ?? '';
        return Text(
          t.labelUpdateAvailable(version),
          style: TextStyle(color: colors.green, fontWeight: FontWeight.w700),
        );
      case UpdateStatus.upToDate:
        return Text(t.labelUpToDate, style: TextStyle(color: colors.mut));
      case UpdateStatus.error:
        return Text(
          _updateErrorMessage(t, update.result?.error ?? UpdateCheckError.networkFailure),
          style: TextStyle(color: colors.mut),
        );
      case UpdateStatus.idle:
      case UpdateStatus.checking:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActions(BuildContext context, AppLocalizations t, UpdateProvider update) {
    if (update.status == UpdateStatus.downloading) {
      return LinearProgressIndicator(value: update.downloadProgress > 0 ? update.downloadProgress : null);
    }
    // Wrap, not Row -- with both buttons showing at once (downloaded state)
    // long translations of either label can exceed the available width;
    // a Row would overflow instead of dropping to a second line.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton(
          onPressed: update.status == UpdateStatus.checking ? null : () => update.checkNow(),
          child: Text(update.status == UpdateStatus.checking ? t.actionChecking : t.actionCheckForUpdates),
        ),
        if (update.status == UpdateStatus.downloaded)
          ElevatedButton(
            onPressed: () => update.openDownloadedUpdate(),
            child: Text(t.actionInstallUpdate),
          ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final appearance = context.watch<AppearanceProvider>();
    final theme = context.watch<ThemeProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.headerAppearance, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(t.labelDarkMode, style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    Switch(
                      value: theme.isDark,
                      onChanged: (_) => context.read<ThemeProvider>().toggle(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(t.labelPrimaryColor, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                _ColorSwatchRow(
                  selected: appearance.accent ?? colors.accent,
                  onSelect: (c) => context.read<AppearanceProvider>().setAccent(c),
                ),
                const SizedBox(height: 20),
                Text(t.labelSecondaryColor, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                _ColorSwatchRow(
                  selected: appearance.secondary ?? colors.secondary,
                  onSelect: (c) => context.read<AppearanceProvider>().setSecondary(c),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.read<AppearanceProvider>().reset(),
                  child: Text(t.actionResetColors),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({required this.selected, required this.onSelect});

  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in _kColorPresets)
          GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: selected.toARGB32() == c.toARGB32() ? Border.all(color: colors.txt, width: 3) : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection();

  Future<void> _pickTime(BuildContext context, ReminderProvider reminder, AppLocalizations t) async {
    final picked = await showTimePicker(context: context, initialTime: reminder.time);
    if (picked == null || !context.mounted) return;
    await reminder.setTime(picked, title: t.notificationTitle, body: t.notificationBody);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final reminder = context.watch<ReminderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.headerReminders, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(t.labelDailyReminder, style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    Switch(
                      value: reminder.enabled,
                      onChanged: reminder.isSupportedPlatform
                          ? (v) => reminder.setEnabled(v, title: t.notificationTitle, body: t.notificationBody)
                          : null,
                    ),
                  ],
                ),
                if (!reminder.isSupportedPlatform)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(t.reminderNotSupported, style: TextStyle(color: colors.mut, fontSize: 12.5)),
                  ),
                if (reminder.enabled && reminder.isSupportedPlatform) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.labelReminderTime, style: TextStyle(color: colors.mut)),
                      TextButton(
                        onPressed: () => _pickTime(context, reminder, t),
                        child: Text(reminder.time.format(context)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GeneralSection extends StatelessWidget {
  const _GeneralSection();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.headerGeneral, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(t.settingsLanguage),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLanguagePicker(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.import_export),
                title: Text(t.titleBackup),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showBackupSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection();

  Future<void> _sendEmail() => launchUrl(Uri(scheme: 'mailto', path: AppConfig.supportEmail));
  Future<void> _call() => launchUrl(Uri(scheme: 'tel', path: AppConfig.supportPhone));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasEmail = AppConfig.supportEmail.isNotEmpty;
    final hasPhone = AppConfig.supportPhone.isNotEmpty;
    if (!hasEmail && !hasPhone) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.headerHelp, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              if (hasEmail)
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(t.actionEmail),
                  subtitle: Text(AppConfig.supportEmail),
                  onTap: _sendEmail,
                ),
              if (hasEmail && hasPhone) const Divider(height: 1),
              if (hasPhone)
                ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: Text(t.actionCall),
                  subtitle: Text(AppConfig.supportPhone),
                  onTap: _call,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
