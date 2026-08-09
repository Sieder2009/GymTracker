import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/exercises_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/strength_screen.dart';
import '../screens/training_screen.dart';
import '../state/active_screen_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'app_tab_bar.dart';
import 'toast_overlay.dart';

/// Root shell: the 3 tabs stay mounted simultaneously via [PageView]
/// (matches the original's always-mounted `.screen` sections, just
/// cross-faded via CSS) so switching tabs never loses scroll/local state
/// -- and, unlike the [IndexedStack] this replaced, also picks up a swipe
/// gesture for free, in addition to tapping the nav bar.
///
/// The nav bar floats over the content (margin + rounded pill + shadow)
/// rather than docking flush to the screen edge — screens add their own
/// bottom padding (see [kFloatingNavClearance]) so content never sits
/// underneath it.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: context.read<ActiveScreenProvider>().index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = context.watch<ActiveScreenProvider>().index;
    final colors = Theme.of(context).extension<AppColors>()!;

    // The nav bar (a tap) is the only other place `active` changes -- a
    // swipe instead updates it via onPageChanged below, so this only ever
    // fires for taps, never fighting the page view's own animation.
    if (_pageController.hasClients && _pageController.page?.round() != active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.animateToPage(
          active,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => context.read<ActiveScreenProvider>().set(i),
            children: const [
              TrainingScreen(),
              StrengthScreen(),
              ProgressScreen(),
              ExercisesScreen(),
            ],
          ),
          const ToastOverlay(),
          Positioned(
            left: 20,
            right: 20,
            // The pill is 10pt taller than its icon content needs (see
            // AppTabBar's height) so it can sit closer to the screen edge
            // here without raising its *top* edge -- that top edge is what
            // has to clear scrollable content underneath, so shrinking this
            // outer margin alone (without the matching height bump) would
            // risk uncovering whatever sits just above the old boundary.
            bottom: 6,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: colors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: const AppTabBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom padding every scrollable screen needs so its last item clears the
/// floating nav bar — one shared constant instead of a magic number guessed
/// independently in each screen's `ListView` padding.
const double kFloatingNavClearance = 96;
