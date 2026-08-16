import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/active_screen_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'nav_icons.dart';

/// Bottom nav for the 4 tabs (Training/Kraft/Fortschritt/Übungen), using the same
/// hand-drawn barbell/plates/bar-chart glyphs as the web app's tab bar.
/// Built from plain [InkWell]s rather than [BottomNavigationBar] — the
/// latter assumes it owns the full screen-edge-to-edge Material surface,
/// which fights with [AppShell]'s floating rounded-pill container (double
/// background/shadow). This gives the exact same tap targets without that.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final active = context.watch<ActiveScreenProvider>();
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final tabs = [
      (icon: NavIconType.training, label: t.tabTraining),
      (icon: NavIconType.strength, label: t.tabStrength),
      (icon: NavIconType.progress, label: t.tabProgress),
      (icon: NavIconType.exercises, label: t.tabExercises),
    ];

    return SizedBox(
      height: 86,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => context.read<ActiveScreenProvider>().set(i),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: active.index == i ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: NavIcon(
                        tabs[i].icon,
                        color: active.index == i ? colors.accent : colors.mut,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tabs[i].label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: active.index == i
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color:
                                active.index == i ? colors.accent : colors.mut,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
