import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Horizontal Mo–So day-pill row for weekday-mode plans. Today gets an
/// outline, the viewed day gets a filled accent background.
class DayPillSelector extends StatelessWidget {
  const DayPillSelector({
    super.key,
    required this.todayIdx,
    required this.selectedIdx,
    required this.onSelect,
  });

  final int todayIdx;
  final int selectedIdx;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final t = AppLocalizations.of(context)!;
    final weekdaysShort = [
      t.weekdayMonShort, t.weekdayTueShort, t.weekdayWedShort, t.weekdayThuShort,
      t.weekdayFriShort, t.weekdaySatShort, t.weekdaySunShort,
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weekdaysShort.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isToday = i == todayIdx;
          final isSelected = i == selectedIdx;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colors.accent : colors.card2,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: isToday && !isSelected
                    ? Border.all(color: colors.accent, width: 1.5)
                    : null,
              ),
              child: Text(
                weekdaysShort[i],
                style: TextStyle(
                  color: isSelected ? colors.onAccent : colors.txt,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
