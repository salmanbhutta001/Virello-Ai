/// Professional app tour (onboarding walkthrough) for Virello.
///
/// Shows on first launch after login: a guided tour of all 6 tabs +
/// Ask Virello FAB, with coach-mark highlights, smooth animations,
/// progress dots, and Skip support. Replayable from Profile > Take Tour.
///
/// Design: dark scrim with a cutout highlight over the target, an elegant
/// info card (title + description + Next/Back/Skip), progress dots.
/// Fully theme-aware, EN/UR/AR via strings.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../main.dart';

/// One step of the app tour.
class TourStep {
  /// Tab index to switch to for this step (-1 = keep current).
  final int tabIndex;

  /// Title shown in the info card.
  final String Function(AppStrings s) title;

  /// Description shown in the info card.
  final String Function(AppStrings s) description;

  /// Icon shown in the info card.
  final IconData icon;

  /// Whether this step highlights the Ask Virello FAB.
  final bool highlightFab;

  const TourStep({
    required this.tabIndex,
    required this.title,
    required this.description,
    required this.icon,
    this.highlightFab = false,
  });
}

/// All tour steps in order.
List<TourStep> buildTourSteps(AppStrings s) => [
      TourStep(
        tabIndex: -1,
        title: (s) => s.tourWelcomeTitle,
        description: (s) => s.tourWelcomeDesc,
        icon: Icons.waving_hand,
      ),
      TourStep(
        tabIndex: 0,
        title: (s) => s.tourHomeTitle,
        description: (s) => s.tourHomeDesc,
        icon: Icons.home,
      ),
      TourStep(
        tabIndex: 1,
        title: (s) => s.tourDiscoverTitle,
        description: (s) => s.tourDiscoverDesc,
        icon: Icons.explore,
      ),
      TourStep(
        tabIndex: 2,
        title: (s) => s.tourCreateTitle,
        description: (s) => s.tourCreateDesc,
        icon: Icons.add_circle,
      ),
      TourStep(
        tabIndex: 3,
        title: (s) => s.tourGrowTitle,
        description: (s) => s.tourGrowDesc,
        icon: Icons.trending_up,
      ),
      TourStep(
        tabIndex: 4,
        title: (s) => s.tourShopTitle,
        description: (s) => s.tourShopDesc,
        icon: Icons.shopping_bag,
      ),
      TourStep(
        tabIndex: 5,
        title: (s) => s.tourProfileTitle,
        description: (s) => s.tourProfileDesc,
        icon: Icons.person,
      ),
      TourStep(
        tabIndex: 0,
        title: (s) => s.tourAskTitle,
        description: (s) => s.tourAskDesc,
        icon: Icons.smart_toy,
        highlightFab: true,
      ),
      TourStep(
        tabIndex: -1,
        title: (s) => s.tourDoneTitle,
        description: (s) => s.tourDoneDesc,
        icon: Icons.celebration,
      ),
    ];

/// Persistent flag: has the user seen the tour?
class AppTourService {
  static const _key = 'virello_tour_seen_v1';

  static Future<bool> hasSeenTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}

/// Full-screen tour overlay with coach marks.
class AppTourOverlay extends StatefulWidget {
  /// Called when the tour finishes or is skipped.
  final VoidCallback onComplete;

  /// Called when a step wants to switch tabs.
  final void Function(int tabIndex) onTabSwitch;

  const AppTourOverlay({
    super.key,
    required this.onComplete,
    required this.onTabSwitch,
  });

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _pulse;
  late List<TourStep> _steps;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Steps built lazily in didChangeDependencies (needs AppStrings).
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _steps = buildTourSteps(AppStrings.of(context));
    final tab = _steps[_step].tabIndex;
    if (tab >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTabSwitch(tab);
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _goTo(int next) {
    if (next >= _steps.length) {
      _finish();
      return;
    }
    setState(() => _step = next);
    final tab = _steps[next].tabIndex;
    if (tab >= 0) widget.onTabSwitch(tab);
  }

  Future<void> _finish() async {
    await AppTourService.markTourSeen();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final step = _steps[_step];
    final isFirst = _step == 0;
    final isLast = _step == _steps.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Scrim.
          GestureDetector(
            onTap: () {}, // Block touches to the app below.
            child: Container(
              color: Colors.black.withValues(alpha: 0.72),
            ),
          ),

          // FAB highlight ring (pulsing) when this step targets the FAB.
          if (step.highlightFab)
            Positioned(
              right: 16,
              bottom: 96,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final scale = 1.0 + (_pulse.value * 0.08);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: VirelloColors.pink,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: VirelloColors.pink
                                .withValues(alpha: 0.5 + _pulse.value * 0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Bottom nav highlight hint.
          if (step.tabIndex >= 0 && !step.highlightFab)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return Container(
                    height: 84,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: VirelloColors.pink
                            .withValues(alpha: 0.6 + _pulse.value * 0.4),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: VirelloColors.pink.withValues(alpha: 0.25),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Info card.
          Positioned(
            left: 20,
            right: 20,
            bottom: step.highlightFab || step.tabIndex >= 0 ? 200 : 120,
            child: _TourCard(
              step: step,
              stepIndex: _step,
              totalSteps: _steps.length,
              isFirst: isFirst,
              isLast: isLast,
              isDark: isDark,
              onNext: () => _goTo(_step + 1),
              onBack: () => _goTo(_step - 1),
              onSkip: _finish,
            ),
          ),
        ],
      ),
    );
  }
}

/// The elegant info card shown for each tour step.
class _TourCard extends StatelessWidget {
  final TourStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isFirst;
  final bool isLast;
  final bool isDark;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _TourCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [VirelloColors.pink, Color(0xFFC2274E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(step.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title(s),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              // Skip button.
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  s.tourSkip,
                  style: TextStyle(
                    color: VirelloColors.pink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            step.description(s),
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : const Color(0xFF4A4A5E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Progress dots.
              Expanded(
                child: Row(
                  children: List.generate(
                    totalSteps,
                    (i) => Container(
                      width: i == stepIndex ? 22 : 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == stepIndex
                            ? VirelloColors.pink
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.12)),
                      ),
                    ),
                  ),
                ),
              ),
              // Back button.
              if (!isFirst)
                TextButton(
                  onPressed: onBack,
                  child: Text(
                    s.tourBack,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF6A6A7E),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Next / Done button.
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VirelloColors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isLast ? s.tourDone : s.tourNext,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
