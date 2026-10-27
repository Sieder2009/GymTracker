import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'calorie_calculator_sheet.dart';
import 'one_rep_max_sheet.dart';
import 'plate_calculator_sheet.dart';

/// The three scratchpad calculators (plate, 1RM, calorie & macro) that every
/// tab's ⋮ menu offers: on Strength and Exercises they are the whole menu
/// ([CalculatorsMenuButton]), Training lists them among its own items.
enum Calculator { plate, oneRepMax, calories }

/// Opens [calculator]'s sheet.
Future<void> showCalculator(BuildContext context, Calculator calculator) => switch (calculator) {
      Calculator.plate => showPlateCalculator(context),
      Calculator.oneRepMax => showOneRepMaxCalculator(context),
      Calculator.calories => showCalorieCalculator(context),
    };

/// The calculators as ⋮-menu items, styled like every other item there.
List<PopupMenuItem<Calculator>> calculatorMenuItems(AppLocalizations t) => [
      for (final (calculator, icon, label) in [
        (Calculator.plate, Icons.fitness_center_outlined, t.titlePlateCalculator),
        (Calculator.oneRepMax, Icons.calculate_outlined, t.title1rmCalculator),
        (Calculator.calories, Icons.local_fire_department_outlined, t.titleCalorieCalculator),
      ])
        PopupMenuItem(
          value: calculator,
          child: ListTile(leading: Icon(icon), title: Text(label), contentPadding: EdgeInsets.zero),
        ),
    ];

/// The ⋮ button of the Strength and Exercises headers: just the calculators,
/// none of Training's plan, calendar or settings items. Opens the sheet in
/// [PopupMenuButton.onSelected], after the menu has closed, for the same
/// reason Training's menu does.
class CalculatorsMenuButton extends StatelessWidget {
  const CalculatorsMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return PopupMenuButton<Calculator>(
      icon: const Icon(Icons.more_vert),
      onSelected: (calculator) => showCalculator(context, calculator),
      itemBuilder: (context) => calculatorMenuItems(t),
    );
  }
}
