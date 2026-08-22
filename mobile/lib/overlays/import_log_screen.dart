import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/program.dart';
import '../services/csv_import_parser.dart';
import '../services/log_parser.dart';
import '../state/big_lifts_provider.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../state/train_state_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// "Log importieren" — paste-in log parsing, or a CSV export from FitNotes/
/// Strong/Hevy (see `services/csv_import_parser.dart`, which produces the
/// exact same [ParsedLog] shape [parseLog] does) — then the same preview +
/// save flow either way.
class ImportLogScreen extends StatefulWidget {
  const ImportLogScreen({
    super.key,
    this.initialText,
    this.initialName = 'Importierter Plan',
  });

  final String? initialText;
  final String initialName;

  @override
  State<ImportLogScreen> createState() => _ImportLogScreenState();
}

class _ImportLogScreenState extends State<ImportLogScreen> {
  late final TextEditingController _textController;
  late final TextEditingController _nameController;
  ParsedLog? _parsed;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    _nameController = TextEditingController(text: widget.initialName);
    if ((widget.initialText ?? '').trim().isNotEmpty) {
      _parsed = parseLog(widget.initialText!);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _analyze() {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      context
          .read<ToastProvider>()
          .show(AppLocalizations.of(context)!.toastLogRequired);
      return;
    }
    setState(() => _parsed = parseLog(text));
  }

  Future<void> _pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    final String content;
    try {
      content = await File(path).readAsString();
    } catch (_) {
      if (!mounted) return;
      context
          .read<ToastProvider>()
          .show(AppLocalizations.of(context)!.toastFileReadFailed);
      return;
    }
    if (!mounted) return;
    setState(() => _parsed = parseImportedWorkoutCsv(content));
  }

  void _back() => setState(() => _parsed = null);

  void _savePlan() {
    final parsed = _parsed;
    if (parsed == null || (parsed.days.isEmpty && parsed.dailyExercises.isEmpty)) return;

    final program = Program(
      id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? widget.initialName
          : _nameController.text.trim(),
      mode: 'weekday',
      startDate: todayIso(),
      days: toWeekdayPlan(parsed.days),
      dailyExercises: toDailyExercises(parsed.dailyExercises),
    );

    context.read<ProgramsProvider>().addProgram(program);
    final idx = todayIndexForProgram(
        mode: program.mode, currentDayIdx: program.currentDayIdx);
    context
        .read<TrainStateProvider>()
        .selectPlan(program.id, viewedDayIdx: idx);

    if (parsed.pr.bench != null ||
        parsed.pr.deadlift != null ||
        parsed.pr.squat != null) {
      context.read<BigLiftsProvider>().mergeParsedPr(
            bench: parsed.pr.bench,
            deadlift: parsed.pr.deadlift,
            squat: parsed.pr.squat,
            date: parsed.pr.date,
          );
    }

    context
        .read<ToastProvider>()
        .show(AppLocalizations.of(context)!.toastLogImported);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t.titleImportLog),
      ),
      body: SafeArea(
          child: parsed == null
              ? _buildInputView(t)
              : _buildPreviewView(parsed, t)),
    );
  }

  Widget _buildInputView(AppLocalizations t) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: colors.mut),
            const SizedBox(width: 8),
            Expanded(
                child: Text(t.infoImportLogHelp,
                    style: TextStyle(color: colors.mut))),
          ],
        ),
        const SizedBox(height: 12),
        // A concrete example is worth more than another sentence of prose —
        // this is literal syntax the parser expects (see log_parser.dart),
        // not app copy, so it isn't translated: the same three lines work
        // no matter which UI language is selected.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.card2,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: '${t.hintExampleFormat}\n',
                    style: TextStyle(color: colors.mut, fontSize: 12)),
                const TextSpan(
                  text: '1. Wochentag\nBankdrücken\n80kg 3x8',
                  style: TextStyle(fontFamily: 'monospace', height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          maxLines: 16,
          decoration: InputDecoration(hintText: t.hintLogPaste),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child:
              ElevatedButton(onPressed: _analyze, child: Text(t.actionAnalyze)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickCsvFile,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: Text(t.actionImportCsvFile),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView(ParsedLog parsed, AppLocalizations t) {
    // A CSV import never populates `days` (see csv_import_parser.dart --
    // everything goes into dailyExercises), so "nothing was found" has to
    // check both, not just days -- days-only also missed a hand-typed log
    // that's nothing but preamble exercises with no day headers at all.
    if (parsed.days.isEmpty && parsed.dailyExercises.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final w in parsed.warnings) _WarningCard(text: w),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _back, child: Text(t.actionBack)),
        ],
      );
    }

    final hasPr = parsed.pr.bench != null ||
        parsed.pr.deadlift != null ||
        parsed.pr.squat != null;
    final totalExercises = parsed.dailyExercises.length +
        parsed.days.fold<int>(0, (sum, d) => sum + d.exercises.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SummaryBanner(
            dayCount: parsed.days.length, exerciseCount: totalExercises, t: t),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: t.labelPlanName),
        ),
        const SizedBox(height: 12),
        for (final w in parsed.warnings) _WarningCard(text: w),
        if (hasPr)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.headerDetectedPrs}${parsed.pr.date != null ? ' (${fmtDate(parsed.pr.date!)})' : ''}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (parsed.pr.bench != null)
                    Text('${t.labelBenchPress}: ${fmt(parsed.pr.bench!)} kg'),
                  if (parsed.pr.deadlift != null)
                    Text('${t.labelDeadlift}: ${fmt(parsed.pr.deadlift!)} kg'),
                  if (parsed.pr.squat != null)
                    Text('${t.labelSquat}: ${fmt(parsed.pr.squat!)} kg'),
                ],
              ),
            ),
          ),
        if (parsed.dailyExercises.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t.headerEveryTrainingDay,
              style: Theme.of(context).textTheme.labelSmall),
          for (final ex in parsed.dailyExercises)
            _ExercisePreviewTile(exercise: ex, t: t),
        ],
        const SizedBox(height: 8),
        Text(t.headerDays, style: Theme.of(context).textTheme.labelSmall),
        for (final day in parsed.days)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DayBadge(number: day.num),
                      const SizedBox(width: 10),
                      Text(t.dayNumber(day.num),
                          style: Theme.of(context).textTheme.headlineMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final ex in day.exercises)
                    _ExercisePreviewTile(exercise: ex, t: t),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _back, child: Text(t.actionBack))),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                  onPressed: _savePlan, child: Text(t.actionSavePlan)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t.infoImportCreatesNewPlan,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).extension<AppColors>()!.mut,
              fontSize: 12),
        ),
      ],
    );
  }
}

/// Front-and-center confirmation that parsing found *something* real
/// before the user scrolls past a wall of cards — the single biggest gap
/// in the old flow, where you had to visually tally days/exercises
/// yourself to know whether the paste actually worked.
class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner(
      {required this.dayCount, required this.exerciseCount, required this.t});

  final int dayCount;
  final int exerciseCount;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.infoImportSummary(dayCount, exerciseCount),
              style:
                  TextStyle(color: colors.green, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  const _DayBadge({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: colors.accentSoft, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: TextStyle(
            color: colors.accent, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.yellow),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colors.yellow),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: colors.yellow))),
        ],
      ),
    );
  }
}

class _ExercisePreviewTile extends StatelessWidget {
  const _ExercisePreviewTile({required this.exercise, required this.t});
  final ParsedExercise exercise;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final weightLabel = exercise.weight > 0
        ? '${fmt1(exercise.weight)} kg'
        : t.labelBodyweightAbbr;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.fitness_center, size: 14, color: colors.mut),
          const SizedBox(width: 8),
          Expanded(
            child: Text(exercise.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            '$weightLabel · ${exercise.setCount}x${exercise.reps}',
            style: TextStyle(color: colors.mut),
          ),
        ],
      ),
    );
  }
}
