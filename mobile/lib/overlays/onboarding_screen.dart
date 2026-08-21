import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/constants.dart';
import '../data/example_ppl_plan.dart';
import '../data/health_brand.dart';
import '../data/plan_templates.dart';
import '../l10n/app_localizations.dart';
import '../models/program.dart';
import '../services/storage_service.dart';
import '../state/athlete_settings_provider.dart';
import '../state/health_provider.dart';
import '../state/programs_provider.dart';
import '../state/toast_provider.dart';
import '../state/train_state_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../widgets/backup_sheet.dart';
import '../widgets/health_connect_feedback.dart';
import 'plan_editor_screen.dart';

const String kOnboardingCompleteKey = 'ironpeak:onboardingComplete';

String _templateDisplayName(AppLocalizations t, String id) {
  switch (id) {
    case 'upper_lower':
      return t.templateUpperLowerName;
    case 'arnold_split':
      return t.templateArnoldSplitName;
    case 'full_body':
      return t.templateFullBodyName;
    case 'bro_split':
      return t.templateBroSplitName;
    case 'ppl_upper_lower':
      return t.templatePplUpperLowerName;
    case 'powerlifting':
      return t.templatePowerliftingName;
    case 'bodyweight':
      return t.templateBodyweightName;
    default:
      return id;
  }
}

/// First-launch setup: pick (or skip) a plan, optionally connect Health,
/// and a pointer to the existing backup/export feature -- shown once,
/// gated by [kOnboardingCompleteKey] (see [IronpeakApp]'s root widget).
/// Every step can be skipped individually, and the top-right link skips
/// the whole thing outright; nothing here is a one-way door.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _finishing = false;

  static const _stepCount = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_step >= _stepCount - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await context.read<StorageService>().writeString(kOnboardingCompleteKey, 'true');
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < _stepCount; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= _step ? colors.accent : colors.card2,
                                borderRadius: BorderRadius.circular(AppRadii.pill),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(onPressed: _finish, child: Text(t.actionSkip)),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                // Steps only advance via their own buttons -- a stray swipe
                // shouldn't be able to skip past the plan/health steps
                // without the user meaning to.
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _WelcomeStep(onNext: _goNext),
                  _ProfileStep(onNext: _goNext),
                  _PlanStep(onNext: _goNext),
                  _FinishStep(onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
            child: Icon(Icons.fitness_center_rounded, color: colors.onAccent, size: 40),
          ),
          const SizedBox(height: 28),
          Text(
            t.titleOnboardingWelcome,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            t.bodyOnboardingWelcome,
            style: TextStyle(color: colors.mut, fontSize: 15, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: Text(t.actionGetStarted)),
          ),
        ],
      ),
    );
  }
}

/// Captures the app's one athlete-specific setting (see
/// AthleteSettingsProvider) up front instead of leaving the DOTS score and
/// Strength-tab strength levels running off a default nobody explicitly
/// chose until they happen to notice the toggle in Settings later.
/// Answering here writes through immediately, same as every other
/// onboarding choice — "Continue" doesn't gate on having picked one.
class _ProfileStep extends StatelessWidget {
  const _ProfileStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final athlete = context.watch<AthleteSettingsProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.titleOnboardingProfile, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(t.bodyOnboardingProfile, style: TextStyle(color: colors.mut, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _GenderOptionTile(
                  label: 'M',
                  selected: athlete.isMale,
                  onTap: () => athlete.setIsMale(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderOptionTile(
                  label: 'F',
                  selected: !athlete.isMale,
                  onTap: () => athlete.setIsMale(false),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: Text(t.actionContinue)),
          ),
        ],
      ),
    );
  }
}

class _GenderOptionTile extends StatelessWidget {
  const _GenderOptionTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Material(
      color: selected ? colors.accentSoft : colors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: selected ? colors.accent : colors.line, width: selected ? 2 : 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: selected ? colors.accent : colors.txt,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanStep extends StatefulWidget {
  const _PlanStep({required this.onNext});
  final VoidCallback onNext;

  @override
  State<_PlanStep> createState() => _PlanStepState();
}

class _PlanStepState extends State<_PlanStep> {
  late final Future<List<PlanTemplate>> _templatesFuture = loadPlanTemplates();
  bool _busy = false;

  void _applyProgram(Program program) {
    if (_busy) return;
    setState(() => _busy = true);
    context.read<ProgramsProvider>().addProgram(program);
    final idx = todayIndexForProgram(mode: program.mode, currentDayIdx: program.currentDayIdx);
    context.read<TrainStateProvider>().selectPlan(program.id, viewedDayIdx: idx);
    context.read<ToastProvider>().show(AppLocalizations.of(context)!.toastPlanTemplateAdded(program.name));
    widget.onNext();
  }

  Future<void> _createOwn() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Navigator.of(context)
        .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PlanEditorScreen()));
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.titleOnboardingPlan, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(t.bodyOnboardingPlan, style: TextStyle(color: colors.mut, fontSize: 14)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _PlanOptionTile(
                  name: t.examplePplPlanName,
                  daysPerWeek: 6,
                  busy: _busy,
                  onTap: () => _applyProgram(buildExamplePplProgram(name: t.examplePplPlanName)),
                ),
                FutureBuilder<List<PlanTemplate>>(
                  future: _templatesFuture,
                  builder: (context, snapshot) {
                    final templates = snapshot.data;
                    if (templates == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Column(
                      children: [
                        for (final template in templates)
                          _PlanOptionTile(
                            name: _templateDisplayName(t, template.id),
                            daysPerWeek: template.days.where((d) => !d.rest).length,
                            busy: _busy,
                            onTap: () => _applyProgram(
                              buildProgramFromTemplate(template, name: _templateDisplayName(t, template.id)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _createOwn,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(t.actionCreateOwnPlan),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy ? null : widget.onNext,
              child: Text(t.actionSkipForNow),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanOptionTile extends StatelessWidget {
  const _PlanOptionTile({
    required this.name,
    required this.daysPerWeek,
    required this.busy,
    required this.onTap,
  });

  final String name;
  final int daysPerWeek;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: busy ? null : onTap,
        title: Text(name, style: Theme.of(context).textTheme.headlineMedium),
        subtitle: Text(t.labelTrainingDaysPerWeek(daysPerWeek), style: TextStyle(color: colors.mut)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _FinishStep extends StatelessWidget {
  const _FinishStep({required this.onFinish});
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).extension<AppColors>()!;
    final health = context.watch<HealthProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.titleOnboardingFinish, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(t.bodyOnboardingFinish, style: TextStyle(color: colors.mut, fontSize: 14)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                if (health.isSupportedPlatform && !health.isConnected) ...[
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: health.isLoading ? null : () => connectHealthWithFeedback(context, health, t),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: healthBrandColor(),
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    healthBrandName(),
                                    style: Theme.of(context).textTheme.headlineMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.titleHealthSync,
                                    style: TextStyle(color: colors.mut, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (health.isLoading)
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              Icon(Icons.chevron_right_rounded, color: colors.mut),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.titleBackup, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text(t.bodyOnboardingBackup, style: TextStyle(color: colors.mut, fontSize: 13)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => showBackupSheet(context),
                          child: Text(t.actionOpenBackup),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onFinish, child: Text(t.actionFinishSetup)),
          ),
        ],
      ),
    );
  }
}
