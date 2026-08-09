import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/locale_provider.dart';
import '../theme/app_colors.dart';

/// Native-name label for each supported language — shown in its own
/// language (not translated) so it stays legible no matter which language
/// is currently active, matching how OS language pickers behave.
const Map<String, String> _nativeNames = {
  'de': 'Deutsch',
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'it': 'Italiano',
  'pt': 'Português',
  'nl': 'Nederlands',
  'tr': 'Türkçe',
  'pl': 'Polski',
  'ru': 'Русский',
};

Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LanguagePickerSheet(),
  );
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final current = context.watch<LocaleProvider>().languageCode;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.settingsLanguage, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            ListTile(
              title: Text(t.languageSystem),
              trailing: current == null ? Icon(Icons.check_circle, color: colors.accent) : null,
              onTap: () {
                context.read<LocaleProvider>().setLanguageCode(null);
                Navigator.of(context).pop();
              },
            ),
            for (final code in kSupportedLocales)
              ListTile(
                title: Text(_nativeNames[code] ?? code),
                trailing: current == code ? Icon(Icons.check_circle, color: colors.accent) : null,
                onTap: () {
                  context.read<LocaleProvider>().setLanguageCode(code);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
