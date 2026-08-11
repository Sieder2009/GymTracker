import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_provider.dart';

/// Icon shows the TARGET state: sun when currently dark (tap for light),
/// moon when currently light (tap for dark).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return IconButton(
      onPressed: () => context.read<ThemeProvider>().toggle(),
      icon: Icon(theme.isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
    );
  }
}
