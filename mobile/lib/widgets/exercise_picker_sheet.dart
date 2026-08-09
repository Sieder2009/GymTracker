import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/exercise_template.dart';
import 'exercise_list_view.dart';

/// Opens the shared exercise list as a full-height picker — used by the
/// plan editor's "pick from list" action. Returns the chosen
/// [ExerciseTemplate], or null if dismissed without picking one.
Future<ExerciseTemplate?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<ExerciseTemplate>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              AppLocalizations.of(context)!.titleExercisePicker,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Expanded(
            child: ExerciseListView(
              onTap: (ex) => Navigator.of(context).pop(ex),
            ),
          ),
        ],
      ),
    ),
  );
}
