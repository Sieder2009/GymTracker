import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/big_lift.dart';
import '../models/body_weight_entry.dart';
import '../models/program.dart';
import '../services/ai_plan_import.dart';
import '../services/ai_plan_prompt.dart';
import '../services/exercise_database_service.dart';
import '../services/storage_service.dart';
import '../state/athlete_settings_provider.dart';
import '../state/bar_weight_provider.dart';
import '../state/big_lifts_provider.dart';
import '../state/body_weight_provider.dart';
import '../state/custom_exercises_provider.dart';
import '../state/effort_scale_provider.dart';
import '../state/exercise_database_provider.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../state/train_state_provider.dart';
import '../theme/app_colors.dart';

/// "Plan with AI": the user copies instructions into any AI chat, the AI
/// interviews them and answers with a plan, and the answer is pasted back
/// in as a ready plan -- nothing typed in by hand. The prompt lives in
/// `services/ai_plan_prompt.dart`, the reading in
/// `services/ai_plan_import.dart`; this file connects both to the app's
/// state. Used by Settings (one row per step), the plan list and the
/// no-plan screen (both open [showAiPlanSheet]).

const String _kIncludeMyDataKey = 'ironpeak:aiPlan:includeMyData';

/// Whether the copied instructions carry the user's own numbers (body
/// weight, PRs, latest working weights), so the AI can pick starting
/// weights. On until the user switches it off.
bool aiPromptIncludesMyData(StorageService storage) => storage.readString(_kIncludeMyDataKey) != 'false';

/// The cached value changes at once (see [StorageService.writeString]), so
/// a rebuild right after this reads the new value.
void setAiPromptIncludesMyData(StorageService storage, bool value) {
  unawaited(storage.writeString(_kIncludeMyDataKey, value ? 'true' : 'false'));
}

/// Builds the instructions from the app's current state and copies them.
Future<void> copyAiPlanPrompt(BuildContext context) async {
  final t = AppLocalizations.of(context)!;
  final toast = context.read<ToastProvider>();
  final storage = context.read<StorageService>();
  final custom = context.read<CustomExercisesProvider>().templates;
  var exercises = context.read<ExerciseDatabaseProvider>().exercises;
  final profile = aiPromptIncludesMyData(storage) ? _profile(context) : null;
  final language = aiPromptLanguageName(Localizations.localeOf(context).languageCode);
  final barWeightKg = context.read<BarWeightProvider>().barWeightKg;
  final effortScale = context.read<EffortScaleProvider>().scale;
  final pastePath = [t.titleSettings, t.headerAiPlan, t.aiPlanPaste];

  // First launch without internet, before the bundled copy loaded.
  if (exercises.isEmpty) {
    try {
      exercises = await ExerciseDatabaseService().loadBundled();
    } catch (_) {
      // Without a list the AI still writes a plan, just with its own names.
    }
  }
  final prompt = buildAiPlanPrompt(
    language: language,
    today: todayIso(),
    exercises: exercises,
    customExercises: custom,
    profile: profile,
    barWeightKg: barWeightKg,
    effortScale: effortScale,
    pastePath: pastePath,
  );
  await Clipboard.setData(ClipboardData(text: prompt));
  toast.show(t.toastAiPromptCopied);
}

AiPromptProfile _profile(BuildContext context) {
  BodyWeightEntry? latest;
  for (final e in context.read<BodyWeightProvider>().entries) {
    if (latest == null || e.date.compareTo(latest.date) >= 0) latest = e;
  }
  final lifts = context.read<BigLiftsProvider>().lifts;
  return AiPromptProfile(
    isMale: context.read<AthleteSettingsProvider>().isMale,
    bodyWeightKg: latest?.weight,
    bodyWeightDate: latest?.date,
    prs: {
      for (final key in BigLifts.keys)
        if (lifts.byKey(key).pr > 0) key: lifts.byKey(key).pr,
    },
    workingWeights: recentWorkingWeights(context.read<ProgramsProvider>().programs),
  );
}

/// Reads [text] against the app's exercise library, the user's own
/// exercises included.
Future<AiPlanImportResult> parseAiPlanForApp(BuildContext context, String text) async {
  final t = AppLocalizations.of(context)!;
  final custom = context.read<CustomExercisesProvider>();
  var exercises = context.read<ExerciseDatabaseProvider>().exercises;
  if (exercises.isEmpty && text.trim().isNotEmpty) {
    try {
      exercises = await ExerciseDatabaseService().loadBundled();
    } catch (_) {
      // Names stay as the AI wrote them; only the animations are missing.
    }
  }
  return parseAiPlan(
    text,
    library: [...exercises, ...custom.templates],
    customActivation: {
      for (final c in custom.items)
        if (c.activation case final activation?) c.template.id: activation,
    },
    fallbackName: t.actionPlanWithAi,
  );
}

String aiPlanErrorMessage(AppLocalizations t, AiPlanImportError error) => switch (error) {
      AiPlanImportError.empty => t.aiPlanErrorEmpty,
      AiPlanImportError.noPlan => t.aiPlanErrorNoPlan,
      AiPlanImportError.tooManyDays => t.aiPlanErrorTooManyDays,
      AiPlanImportError.noExercises => t.aiPlanErrorNoExercises,
      AiPlanImportError.promptNotAnswer => t.aiPlanErrorPromptNotAnswer,
    };

/// Shows what came in and, once confirmed, adds the plan and makes it the
/// active one (like saving a new plan in the editor). Returns the plan, or
/// null when cancelled.
Future<Program?> confirmAndAddAiPlan(BuildContext context, AiPlanImportResult result) async {
  final program = result.program!;
  final t = AppLocalizations.of(context)!;
  final colors = Theme.of(context).extension<AppColors>()!;
  final unknown = result.unknownExercises;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.importPlanConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.aiPlanConfirmBody(program.name)),
            const SizedBox(height: 10),
            Text(
              '${t.aiPlanTrainingDays(result.trainingDays)} · ${t.aiPlanExerciseCount(result.exerciseCount)}',
              style: TextStyle(color: colors.txt, fontWeight: FontWeight.w600),
            ),
            if (result.cutOff) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: colors.yellow),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(t.aiPlanCutOff, style: TextStyle(color: colors.txt, fontSize: 13)),
                  ),
                ],
              ),
            ],
            if (unknown.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                t.aiPlanUnknownExercises(unknown.length),
                style: TextStyle(color: colors.mut, fontSize: 12.5),
              ),
              const SizedBox(height: 2),
              Text(
                [...unknown.take(6), if (unknown.length > 6) '…'].join(', '),
                style: TextStyle(color: colors.mut, fontSize: 12.5, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.actionCancel)),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.actionImportPlan)),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return null;
  context.read<ProgramsProvider>().addProgram(program);
  context.read<TrainStateProvider>().selectPlan(
        program.id,
        viewedDayIdx: todayIndexForProgram(mode: program.mode, currentDayIdx: program.currentDayIdx),
      );
  context.read<ToastProvider>().show(t.toastAiPlanImported);
  return program;
}

/// One tap from Settings: imports the AI's answer straight from the
/// clipboard. When the clipboard holds no plan, the sheet opens instead,
/// saying why and offering a field to paste into by hand.
Future<Program?> importAiPlanFromClipboard(BuildContext context) async {
  final clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return null;
  final text = clip?.text ?? '';
  final result = await parseAiPlanForApp(context, text);
  if (!context.mounted) return null;
  if (result.program != null) return confirmAndAddAiPlan(context, result);
  return showAiPlanSheet(
    context,
    error: result.error,
    // Only an attempt at a plan is worth showing back; a stray link or the
    // instructions themselves aren't.
    initialText: text.contains('{') && result.error != AiPlanImportError.promptNotAnswer ? text : null,
  );
}

/// All three steps in one sheet. Returns the imported plan (already added
/// and active) or null.
Future<Program?> showAiPlanSheet(BuildContext context, {AiPlanImportError? error, String? initialText}) {
  return showModalBottomSheet<Program>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AiPlanSheet(initialError: error, initialText: initialText),
  );
}

class _AiPlanSheet extends StatefulWidget {
  const _AiPlanSheet({this.initialError, this.initialText});

  final AiPlanImportError? initialError;
  final String? initialText;

  @override
  State<_AiPlanSheet> createState() => _AiPlanSheetState();
}

class _AiPlanSheetState extends State<_AiPlanSheet> {
  late final TextEditingController _answer = TextEditingController(text: widget.initialText);
  late AiPlanImportError? _error = widget.initialError;
  bool _busy = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _pasteIntoField() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() {
      _answer.text = clip?.text ?? '';
      _error = null;
    });
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // An empty field means "use what I copied".
      if (_answer.text.trim().isEmpty) await _pasteIntoField();
      if (!mounted) return;
      final result = await parseAiPlanForApp(context, _answer.text);
      if (!mounted) return;
      if (result.program == null) {
        setState(() => _error = result.error);
        return;
      }
      setState(() => _error = null);
      final program = await confirmAndAddAiPlan(context, result);
      if (program != null && mounted) Navigator.of(context).pop(program);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final storage = context.read<StorageService>();
    final includeData = aiPromptIncludesMyData(storage);
    final error = _error;
    final stepStyle = TextStyle(color: colors.txt, fontSize: 15, fontWeight: FontWeight.w700);
    final hintStyle = TextStyle(color: colors.mut, fontSize: 12.5);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.titleAiPlan, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 18),
              Text(t.aiPlanStepCopy, style: stepStyle),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.aiPlanIncludeData, style: TextStyle(color: colors.txt, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(t.aiPlanIncludeDataHint, style: hintStyle),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: includeData,
                    onChanged: (v) => setState(() => setAiPromptIncludesMyData(storage, v)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => copyAiPlanPrompt(context),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(t.aiPlanCopyPrompt),
                ),
              ),
              const SizedBox(height: 22),
              Text(t.aiPlanStepChat, style: stepStyle),
              const SizedBox(height: 2),
              Text(t.aiPlanCopyPromptHint, style: hintStyle),
              const SizedBox(height: 22),
              Text(t.aiPlanStepPaste, style: stepStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _answer,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: t.hintAiPlanPaste,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded),
                    tooltip: t.actionPaste,
                    onPressed: _pasteIntoField,
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: colors.yellow),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        aiPlanErrorMessage(t, error),
                        style: TextStyle(color: colors.txt, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _import,
                  child: Text(t.actionImportPlan),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
