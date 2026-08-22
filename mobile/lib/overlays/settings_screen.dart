import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../data/constants.dart';
import '../data/health_brand.dart';
import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import '../state/appearance_provider.dart';
import '../state/athlete_settings_provider.dart';
import '../state/bar_weight_provider.dart';
import '../state/health_provider.dart';
import '../state/reminder_provider.dart';
import '../state/theme_provider.dart';
import '../state/toast_provider.dart';
import '../state/update_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/backup_sheet.dart';
import '../widgets/health_connect_feedback.dart';
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

// Surface/text tones for Custom theme's bg/card/txt pickers -- muted and
// neutral by design, unlike the vivid brand-accent presets above, since
// these are meant to sit *behind* content, not draw attention to themselves.
const List<Color> _kSurfaceColorPresets = [
  Color(0xFFFFFFFF), // white
  Color(0xFFF5F5F7), // off-white
  Color(0xFFEEEEF1), // light grey
  Color(0xFFE3E3E8), // pale grey
  Color(0xFF84848C), // mid grey
  Color(0xFF44444A), // charcoal
  Color(0xFF16171B), // near-black
  Color(0xFF101114), // ink
  Color(0xFF1A1B1F), // dark card
  Color(0xFF232428), // dark card 2
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
            _AthleteProfileSection(),
            SizedBox(height: 24),
            _EquipmentSection(),
            SizedBox(height: 24),
            _ReminderSection(),
            SizedBox(height: 24),
            _HealthSection(),
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

/// One native-style settings row: a solid-colored icon badge (the same
/// language iOS Settings uses -- the green Phone square, the blue Safari
/// square) plus a label and a trailing control. The shared building block
/// every grouped list in this screen is made of, so the whole screen reads
/// as one consistent list instead of a stack of differently-shaped cards.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: subtitleColor ?? colors.mut,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (trailing == null && onTap != null && showChevron)
            Icon(Icons.chevron_right_rounded, color: colors.mut),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 30});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadii.sm)),
      child: Icon(icon, color: Colors.white, size: size * 0.58),
    );
  }
}

/// Hairline divider inset to align under the row label rather than running
/// full-width under the icon too -- the detail that makes a grouped list
/// read as one continuous list instead of stacked rows (iOS Settings does
/// the same: 16 padding + 30 icon + 12 gap).
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 58),
        child: Divider(height: 1),
      );
}

/// A group of [_SettingsRow]s in one rounded, bordered container -- the
/// grouped-list pattern from iOS Settings, in place of one shadowed [Card]
/// per individual setting.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.header, required this.children});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(header, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// A pill-shaped label for [CupertinoSlidingSegmentedControl] children --
/// explicit colors rather than relying on Cupertino's platform-brightness
/// default, since this app's theme mode (light/dark/custom) can differ from
/// the OS's own brightness.
Widget _segmentLabel(BuildContext context, String text) {
  final colors = Theme.of(context).extension<AppColors>()!;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.txt),
    ),
  );
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
                    _IconBadge(icon: Icons.arrow_circle_up_rounded, color: colors.accent, size: 36),
                    const SizedBox(width: 12),
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
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.labelAutoInstallUpdates, style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 2),
                          Text(t.hintAutoInstallUpdates, style: TextStyle(color: colors.mut, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: update.autoInstall,
                      onChanged: (v) => update.setAutoInstall(v),
                    ),
                  ],
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
        final downloadedVersion = update.downloadedVersion ?? update.result?.latestVersion ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusRow(
              icon: Icons.check_circle_rounded,
              color: colors.green,
              text: t.labelUpdateReady(downloadedVersion),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => update.openDownloadedUpdate(),
                // macOS can't silently install an unsigned build (see
                // UpdateProvider.openDownloadedUpdate) -- say what the tap
                // actually does there instead of overpromising "Install".
                child: Text(Platform.isMacOS ? t.actionShowInFinder : t.actionInstallUpdate),
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
                Text(t.labelThemeMode, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                CupertinoSlidingSegmentedControl<String>(
                  backgroundColor: colors.card2,
                  thumbColor: colors.card,
                  groupValue: theme.mode,
                  children: {
                    'light': _segmentLabel(context, t.themeModeLight),
                    'dark': _segmentLabel(context, t.themeModeDark),
                    'custom': _segmentLabel(context, t.themeModeCustom),
                  },
                  onValueChanged: (v) {
                    if (v != null) context.read<ThemeProvider>().setMode(v);
                  },
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
                if (theme.isCustom) ...[
                  const SizedBox(height: 20),
                  Text(t.labelBackground, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  _ColorSwatchRow(
                    selected: appearance.bg ?? colors.bg,
                    presets: _kSurfaceColorPresets,
                    onSelect: (c) => context.read<AppearanceProvider>().setBg(c),
                  ),
                  const SizedBox(height: 20),
                  Text(t.labelCardColor, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  _ColorSwatchRow(
                    selected: appearance.card ?? colors.card,
                    presets: _kSurfaceColorPresets,
                    onSelect: (c) => context.read<AppearanceProvider>().setCard(c),
                  ),
                  const SizedBox(height: 20),
                  Text(t.labelTextColor, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  _ColorSwatchRow(
                    selected: appearance.txt ?? colors.txt,
                    presets: _kSurfaceColorPresets,
                    onSelect: (c) => context.read<AppearanceProvider>().setTxt(c),
                  ),
                ],
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
  const _ColorSwatchRow({
    required this.selected,
    required this.onSelect,
    this.presets = _kColorPresets,
  });

  final Color selected;
  final ValueChanged<Color> onSelect;
  final List<Color> presets;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isPreset = presets.any((c) => c.toARGB32() == selected.toARGB32());
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in presets)
          _Swatch(color: c, selected: selected.toARGB32() == c.toARGB32(), onTap: () => onSelect(c)),
        // The currently-active color, when it's a custom pick rather than
        // one of the fixed presets -- otherwise picking a custom color
        // would leave every swatch above looking unselected even though
        // one very much is active.
        if (!isPreset) _Swatch(color: selected, selected: true, onTap: () => _openPicker(context)),
        GestureDetector(
          onTap: () => _openPicker(context),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.card2,
              border: Border.all(color: colors.line, width: 1.5),
            ),
            child: Icon(Icons.add, size: 18, color: colors.mut),
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showCustomColorPicker(context, initial: selected);
    if (picked != null) onSelect(picked);
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: colors.txt, width: 3) : null,
        ),
      ),
    );
  }
}

/// Hex input + a visual picker, for anyone who wants a shade the 12 fixed
/// presets don't cover -- reached via the "+" swatch in [_ColorSwatchRow].
/// Bottom sheet, not a centered dialog, to match every other picker in
/// this app (language, filters, plan picker, ...).
Future<Color?> showCustomColorPicker(BuildContext context, {required Color initial}) {
  final t = AppLocalizations.of(context)!;
  var picked = initial;
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.titleCustomColor, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),
              ColorPicker(
                pickerColor: initial,
                onColorChanged: (c) => picked = c,
                // No alpha: accent/secondary render as solid button/icon/
                // border fills all over the app, never composited over a
                // known background, so a translucent value would just look
                // broken depending on what happens to sit behind it.
                enableAlpha: false,
                displayThumbColor: true,
                labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb, ColorLabelType.hsv],
                pickerAreaHeightPercent: 0.6,
                pickerAreaBorderRadius: BorderRadius.circular(AppRadii.md),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(picked),
                  child: Text(t.actionApply),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The one athlete-specific setting the app has (see
/// AthleteSettingsProvider) — used to live as an inline ChoiceChip right
/// on the Strength tab's Powerlifting-Score card, editable from two
/// different places. Centralized here instead: Settings is the single
/// place to change it, and the Strength tab now just shows the current
/// value with a link back to this section (see
/// StrengthScreen's `_PowerliftingScoreCard`).
class _AthleteProfileSection extends StatelessWidget {
  const _AthleteProfileSection();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final athlete = context.watch<AthleteSettingsProvider>();

    return _SettingsGroup(
      header: t.headerAthleteProfile,
      children: [
        _SettingsRow(
          icon: Icons.accessibility_new_rounded,
          iconColor: colors.secondary,
          label: t.labelGenderForFormulas,
          trailing: SizedBox(
            width: 96,
            child: CupertinoSlidingSegmentedControl<bool>(
              backgroundColor: colors.card2,
              thumbColor: colors.card,
              groupValue: athlete.isMale,
              children: {
                true: _segmentLabel(context, 'M'),
                false: _segmentLabel(context, 'F'),
              },
              onValueChanged: (v) {
                if (v != null) athlete.setIsMale(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The default barbell weight used to convert a "per side" weight entry
/// into the total stored for a set (see `data/weight_conversion.dart` and
/// `ExerciseDetailScreen`'s weight-entry dialog).
class _EquipmentSection extends StatefulWidget {
  const _EquipmentSection();

  @override
  State<_EquipmentSection> createState() => _EquipmentSectionState();
}

class _EquipmentSectionState extends State<_EquipmentSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BarWeightProvider provider) {
    final value = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (value != null && value > 0) provider.setBarWeightKg(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final barWeight = context.watch<BarWeightProvider>();
    if (_controller.text.isEmpty) {
      _controller.text = fmt1(barWeight.barWeightKg);
    }

    return _SettingsGroup(
      header: t.headerEquipment,
      children: [
        _SettingsRow(
          icon: Icons.fitness_center_rounded,
          iconColor: colors.yellow,
          label: t.labelBarWeight,
          trailing: SizedBox(
            width: 90,
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'kg', isDense: true),
              onEditingComplete: () => _submit(barWeight),
              onTapOutside: (_) => _submit(barWeight),
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

    return _SettingsGroup(
      header: t.headerReminders,
      children: [
        _SettingsRow(
          icon: Icons.notifications_rounded,
          iconColor: colors.green,
          label: t.labelDailyReminder,
          trailing: Switch.adaptive(
            value: reminder.enabled,
            onChanged: reminder.isSupportedPlatform
                ? (v) => reminder.setEnabled(v, title: t.notificationTitle, body: t.notificationBody)
                : null,
          ),
        ),
        if (!reminder.isSupportedPlatform)
          Padding(
            padding: const EdgeInsets.fromLTRB(58, 0, 16, 12),
            child: Text(t.reminderNotSupported, style: TextStyle(color: colors.mut, fontSize: 12.5)),
          ),
        if (reminder.enabled && reminder.isSupportedPlatform) ...[
          const _RowDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(58, 10, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.labelReminderTime, style: TextStyle(color: colors.mut, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => _pickTime(context, reminder, t),
                  child: Text(reminder.time.format(context)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Apps can't revoke their own HealthKit/Health Connect grant -- only the
/// OS's own Health/Health Connect settings can -- so [HealthProvider
/// .disconnect] is app-side only: it stops this app from reading/writing
/// and brings the dashboard's one-time connect card back (see
/// [_HealthCard] in training_screen.dart), without touching the real OS
/// permission. Re-enabling here just flips that back, or runs the actual
/// OS connect flow if it was never granted in the first place.
class _HealthSection extends StatelessWidget {
  const _HealthSection();

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    if (!health.isSupportedPlatform) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final brandColor = healthBrandColor();
    final brandName = healthBrandName();

    return _SettingsGroup(
      header: t.titleHealthSync,
      children: [
        _SettingsRow(
          icon: Icons.favorite_rounded,
          iconColor: brandColor,
          label: brandName,
          subtitle: health.isConnected ? t.labelHealthConnected : t.labelHealthNotConnected,
          subtitleColor: health.isConnected ? colors.green : colors.mut,
          trailing: health.isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch.adaptive(
                  value: health.isConnected,
                  onChanged: (v) {
                    if (v) {
                      unawaited(connectHealthWithFeedback(context, health, t));
                    } else {
                      health.disconnect();
                      context.read<ToastProvider>().show(t.toastHealthDisconnected);
                    }
                  },
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
    final colors = Theme.of(context).extension<AppColors>()!;
    return _SettingsGroup(
      header: t.headerGeneral,
      children: [
        _SettingsRow(
          icon: Icons.language_rounded,
          iconColor: colors.accent,
          label: t.settingsLanguage,
          onTap: () => showLanguagePicker(context),
        ),
        const _RowDivider(),
        _SettingsRow(
          icon: Icons.import_export_rounded,
          iconColor: colors.purple,
          label: t.titleBackup,
          onTap: () => showBackupSheet(context),
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
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasEmail = AppConfig.supportEmail.isNotEmpty;
    final hasPhone = AppConfig.supportPhone.isNotEmpty;
    if (!hasEmail && !hasPhone) return const SizedBox.shrink();

    return _SettingsGroup(
      header: t.headerHelp,
      children: [
        if (hasEmail)
          _SettingsRow(
            icon: Icons.mail_outline_rounded,
            iconColor: colors.accent,
            label: t.actionEmail,
            subtitle: AppConfig.supportEmail,
            showChevron: false,
            onTap: _sendEmail,
          ),
        if (hasEmail && hasPhone) const _RowDivider(),
        if (hasPhone)
          _SettingsRow(
            icon: Icons.call_rounded,
            iconColor: colors.green,
            label: t.actionCall,
            subtitle: AppConfig.supportPhone,
            showChevron: false,
            onTap: _call,
          ),
      ],
    );
  }
}
