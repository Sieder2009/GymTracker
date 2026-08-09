import 'package:flutter/material.dart';

/// Bottom-nav glyphs — plain, recognizable Material icons rather than
/// hand-drawn shapes, so every tab reads instantly at a glance: a barbell
/// for today's workout, a bolt for strength/power tracking, a chart for
/// progress, a checklist for browsing the exercise library. Each maps to a
/// visually distinct icon family so no two tabs are ever confusable.
class NavIcon extends StatelessWidget {
  const NavIcon(this.type, {super.key, this.size = 26, this.color});

  final NavIconType type;
  final double size;

  /// Falls back to the ambient [IconTheme] color — [BottomNavigationBar]
  /// already wraps each item in the right selected/unselected [IconTheme],
  /// so this matches how a plain [Icon] picks up its color for free.
  final Color? color;

  static const Map<NavIconType, IconData> _icons = {
    NavIconType.training: Icons.fitness_center_rounded,
    NavIconType.strength: Icons.bolt_rounded,
    NavIconType.progress: Icons.insights_rounded,
    NavIconType.exercises: Icons.checklist_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Icon(
      _icons[type],
      size: size,
      color: color ?? IconTheme.of(context).color,
    );
  }
}

enum NavIconType { training, strength, progress, exercises }
