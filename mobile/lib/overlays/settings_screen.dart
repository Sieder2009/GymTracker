import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import '../state/appearance_provider.dart';
import '../state/reminder_provider.dart';
import '../state/theme_provider.dart';
import '../state/update_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
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

/// Modeled on iOS Settings' own "Allgemein > Info" row: a plain version
/// line up top (with a quiet manual-refresh affordance, not a permanent
/// button demanding attention) and one status area below that cross-fades
/// between states instead of the layout jumping around as text/buttons
/// appear and disappear.
class _UpdateSection extends StatelessWidget {
  const _UpdateSection();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final update = context.watch<UpdateProvider>();
    final version = update.installedVersion;

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        version == null ? '…' : t.labelInstalledVersion(version),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    _RefreshButton(
                      spinning: update.status == UpdateStatus.checking,
                      onPressed: update.status == UpdateStatus.checking ? null : () => update.checkNow(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(update.status),
                      child: _buildStatusBody(context, t, colors, update),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBody(BuildContext context, AppLocalizations t, AppColors colors, UpdateProvider update) {
    switch (update.status) {
      case UpdateStatus.idle:
      case UpdateStatus.checking:
        return _StatusRow(spinner: true, color: colors.mut, text: t.actionChecking);
      case UpdateStatus.upToDate:
        return _StatusRow(icon: Icons.check_circle_rounded, color: colors.green, text: t.labelUpToDate);
      case UpdateStatus.error:
        return _StatusRow(
          icon: Icons.info_outline_rounded,
          color: colors.mut,
          text: _updateErrorMessage(t, update.result?.error ?? UpdateCheckError.networkFailure),
        );
      case UpdateStatus.updateAvailable:
        // Reached as a steady state (not just a flash before auto-download
        // kicks in) only when this platform has no matching release asset
        // (UpdateProvider.checkNow auto-downloads whenever one exists) --
        // so the button sends the user to the release page instead of
        // re-checking, which would just land back here.
        final version = update.result?.latestVersion ?? '';
        final releaseUrl = update.result?.releaseUrl;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusRow(icon: Icons.arrow_circle_up_rounded, color: colors.accent, text: t.labelUpdateAvailable(version)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: releaseUrl == null ? null : () => launchUrl(Uri.parse(releaseUrl)),
                child: Text(t.actionDownloadUpdate),
              ),
            ),
          ],
        );
      case UpdateStatus.downloading:
        final percent = (update.downloadProgress * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.labelDownloadingUpdate(percent), style: TextStyle(color: colors.mut)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 250),
                tween: Tween(begin: 0, end: update.downloadProgress),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: colors.card2,
                  valueColor: AlwaysStoppedAnimation(colors.accent),
                ),
              ),
            ),
          ],
        );
      case UpdateStatus.downloaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusRow(icon: Icons.check_circle_rounded, color: colors.green, text: t.labelUpdateReady),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => update.openDownloadedUpdate(),
                child: Text(t.actionInstallUpdate),
              ),
            ),
          ],
        );
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.color, required this.text, this.icon, this.spinner = false});

  final IconData? icon;
  final bool spinner;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spinner)
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
        else if (icon != null)
          Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// Small rotating icon-button rather than a permanent "Nach Updates
/// suchen" outline button competing for attention on a screen you open
/// far more often than you manually re-check for an update.
class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.spinning, required this.onPressed});

  final bool spinning;
  final VoidCallback? onPressed;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _RefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: widget.onPressed,
      icon: RotationTransition(turns: _controller, child: const Icon(Icons.refresh_rounded, size: 20)),
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
