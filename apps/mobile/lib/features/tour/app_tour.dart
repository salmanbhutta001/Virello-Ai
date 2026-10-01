/// Professional app tour (onboarding walkthrough) for Virello.
///
/// Shows on first launch after login (per account): a guided tour of all
/// 6 tabs + key in-page controls + Ask Virello FAB, with measured
/// spotlight cutouts (no hardcoded coordinates), a popup info card,
/// animated pulse ring + guidance arrow, smooth transitions, progress,
/// and Skip/Back/Next/Done. Replayable from Profile > Take App Tour.
///
/// Design: dark scrim with a real cutout over the measured target rect,
/// an elegant popup card (title + description + controls), progress dots.
/// Fully theme-aware, EN/UR/AR via strings, RTL-safe, respects safe areas,
/// text scaling and rotation.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';

/// Registry of measurable tour targets. The shell (bottom bar, FAB) and
/// individual pages attach these keys to the widgets a tour step explains,
/// so the overlay can measure their real on-screen rect — never hardcoded
/// coordinates.
class TourTargets {
  static final homeTab = GlobalKey(debugLabel: 'tour_home_tab');
  static final discoverTab = GlobalKey(debugLabel: 'tour_discover_tab');
  static final createTab = GlobalKey(debugLabel: 'tour_create_tab');
  static final growTab = GlobalKey(debugLabel: 'tour_grow_tab');
  static final shopTab = GlobalKey(debugLabel: 'tour_shop_tab');
  static final profileTab = GlobalKey(debugLabel: 'tour_profile_tab');
  static final askFab = GlobalKey(debugLabel: 'tour_ask_fab');

  // Meaningful in-page controls.
  static final homeSearch = GlobalKey(debugLabel: 'tour_home_search');
  static final discoverTrending =
      GlobalKey(debugLabel: 'tour_discover_trending');
  static final createFirstTool = GlobalKey(debugLabel: 'tour_create_tool');
  static final growNewCampaign = GlobalKey(debugLabel: 'tour_grow_new');
  static final shopSearch = GlobalKey(debugLabel: 'tour_shop_search');
  static final profileRewards = GlobalKey(debugLabel: 'tour_profile_rewards');
}

/// One step of the app tour.
class TourStep {
  /// Tab index to switch to for this step (-1 = keep current).
  final int tabIndex;

  /// Measured target to spotlight (null = centered card, no spotlight).
  final GlobalKey? target;

  /// True for circular targets (FAB, tab icons); false for rounded-rect.
  final bool circular;

  /// Title shown in the info card.
  final String Function(AppStrings s) title;

  /// Description shown in the info card.
  final String Function(AppStrings s) description;

  /// Icon shown in the info card.
  final IconData icon;

  const TourStep({
    required this.tabIndex,
    required this.title,
    required this.description,
    required this.icon,
    this.target,
    this.circular = false,
  });
}

/// All tour steps in order: welcome, each tab + one key control per page,
/// Ask Virello, done.
List<TourStep> buildTourSteps(AppStrings s) => [
      TourStep(
        tabIndex: -1,
        title: (s) => s.tourWelcomeTitle,
        description: (s) => s.tourWelcomeDesc,
        icon: Icons.waving_hand,
      ),
      TourStep(
        tabIndex: 0,
        target: TourTargets.homeTab,
        circular: true,
        title: (s) => s.tourHomeTitle,
        description: (s) => s.tourHomeDesc,
        icon: Icons.home,
      ),
      TourStep(
        tabIndex: 0,
        target: TourTargets.homeSearch,
        title: (s) => s.tourHomeSearchTitle,
        description: (s) => s.tourHomeSearchDesc,
        icon: Icons.search,
      ),
      TourStep(
        tabIndex: 1,
        target: TourTargets.discoverTab,
        circular: true,
        title: (s) => s.tourDiscoverTitle,
        description: (s) => s.tourDiscoverDesc,
        icon: Icons.explore,
      ),
      TourStep(
        tabIndex: 1,
        target: TourTargets.discoverTrending,
        title: (s) => s.tourDiscoverTrendingTitle,
        description: (s) => s.tourDiscoverTrendingDesc,
        icon: Icons.trending_up,
      ),
      TourStep(
        tabIndex: 2,
        target: TourTargets.createTab,
        circular: true,
        title: (s) => s.tourCreateTitle,
        description: (s) => s.tourCreateDesc,
        icon: Icons.add_circle,
      ),
      TourStep(
        tabIndex: 2,
        target: TourTargets.createFirstTool,
        title: (s) => s.tourCreateToolTitle,
        description: (s) => s.tourCreateToolDesc,
        icon: Icons.auto_awesome,
      ),
      TourStep(
        tabIndex: 3,
        target: TourTargets.growTab,
        circular: true,
        title: (s) => s.tourGrowTitle,
        description: (s) => s.tourGrowDesc,
        icon: Icons.trending_up,
      ),
      TourStep(
        tabIndex: 3,
        target: TourTargets.growNewCampaign,
        circular: true,
        title: (s) => s.tourGrowNewTitle,
        description: (s) => s.tourGrowNewDesc,
        icon: Icons.addchart,
      ),
      TourStep(
        tabIndex: 4,
        target: TourTargets.shopTab,
        circular: true,
        title: (s) => s.tourShopTitle,
        description: (s) => s.tourShopDesc,
        icon: Icons.shopping_bag,
      ),
      TourStep(
        tabIndex: 4,
        target: TourTargets.shopSearch,
        title: (s) => s.tourShopSearchTitle,
        description: (s) => s.tourShopSearchDesc,
        icon: Icons.search,
      ),
      TourStep(
        tabIndex: 5,
        target: TourTargets.profileTab,
        circular: true,
        title: (s) => s.tourProfileTitle,
        description: (s) => s.tourProfileDesc,
        icon: Icons.person,
      ),
      TourStep(
        tabIndex: 5,
        target: TourTargets.profileRewards,
        title: (s) => s.tourProfileRewardsTitle,
        description: (s) => s.tourProfileRewardsDesc,
        icon: Icons.stars,
      ),
      TourStep(
        tabIndex: 0,
        target: TourTargets.askFab,
        circular: true,
        title: (s) => s.tourAskTitle,
        description: (s) => s.tourAskDesc,
        icon: Icons.smart_toy,
      ),
      TourStep(
        tabIndex: -1,
        title: (s) => s.tourDoneTitle,
        description: (s) => s.tourDoneDesc,
        icon: Icons.celebration,
      ),
    ];

/// Persistent flag: has this account seen the tour?
/// Keyed per account (email) so a fresh login on the same device still gets
/// the tour; falls back to the legacy device-global key for users who saw
/// the old tour.
class AppTourService {
  static const _legacyKey = 'virello_tour_seen_v1';
  static String _keyFor(String? account) =>
      (account == null || account.isEmpty)
          ? _legacyKey
          : 'virello_tour_seen_${account.toLowerCase()}';

  static Future<bool> hasSeenTour() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(authStore.email);
    if (prefs.getBool(key) ?? false) return true;
    // One-time migration from the old device-global flag.
    if (key != _legacyKey && (prefs.getBool(_legacyKey) ?? false)) {
      await prefs.setBool(key, true);
      return true;
    }
    return false;
  }

  static Future<void> markTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(authStore.email), true);
  }

  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(authStore.email), false);
  }
}

/// Full-screen tour overlay with measured spotlight coach marks.
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _stackKey = GlobalKey(debugLabel: 'tour_overlay_stack');
  int _step = 0;
  int _navToken = 0;
  bool _started = false;
  late List<TourStep> _steps;

  /// Currently displayed spotlight rect (animated towards _holeTarget).
  Rect? _hole;
  Rect? _holeTarget;
  RectTween? _rectTween;
  late final AnimationController _rectController;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _rectController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _hole = _holeTarget;
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _steps = buildTourSteps(AppStrings(appState.localeCode));
    // Start at the welcome step once the overlay is laid out.
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goTo(0);
      });
    }
  }

  @override
  void didChangeMetrics() {
    // Rotation / resize: re-measure the current target.
    if (!mounted) return;
    final step = _steps[_step];
    if (step.target != null) {
      final token = ++_navToken;
      _measureTarget(step.target!, token).then((rect) {
        if (!mounted || token != _navToken) return;
        _animateHoleTo(rect);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rectController.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Go to [next]; switches tab, waits for the target widget to mount,
  /// measures its real rect and animates the spotlight to it.
  Future<void> _goTo(int next) async {
    if (next < 0 || !mounted) return;
    if (next >= _steps.length) {
      _finish();
      return;
    }
    final token = ++_navToken;
    setState(() => _step = next);
    final step = _steps[next];
    if (step.tabIndex >= 0) widget.onTabSwitch(step.tabIndex);
    Rect? rect;
    if (step.target != null) {
      rect = await _measureTarget(step.target!, token);
    }
    if (!mounted || token != _navToken) return;
    _animateHoleTo(rect);
  }

  /// One synchronous measurement attempt: returns the target rect in
  /// overlay coordinates, or null when the target isn't laid out yet.
  Rect? _tryMeasure(GlobalKey key) {
    final targetCtx = key.currentContext;
    final stackCtx = _stackKey.currentContext;
    if (targetCtx == null || stackCtx == null) return null;
    final box = targetCtx.findRenderObject() as RenderBox?;
    final stackBox = stackCtx.findRenderObject() as RenderBox?;
    if (box == null ||
        stackBox == null ||
        !box.hasSize ||
        box.size.shortestSide <= 0.5) {
      return null;
    }
    final local = stackBox.globalToLocal(box.localToGlobal(Offset.zero));
    var r = (local & box.size).inflate(12);
    r = r.intersect(Offset.zero & stackBox.size);
    return r.isEmpty ? null : r;
  }

  /// Polls until the target key is mounted and laid out (the tab page may
  /// still be building), then returns its rect in overlay coordinates.
  Future<Rect?> _measureTarget(GlobalKey key, int token) async {
    for (int i = 0; i < 30; i++) {
      if (!mounted || token != _navToken) return null;
      // Let the new tab finish building and laying out.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || token != _navToken) return null;
      final r = _tryMeasure(key);
      if (r != null) return r;
      await Future.delayed(const Duration(milliseconds: 90));
    }
    // Target never mounted (e.g. FAB hidden on this tab): show the card
    // without a spotlight rather than stalling the tour.
    return null;
  }

  void _animateHoleTo(Rect? rect) {
    _holeTarget = rect;
    var begin = _hole;
    if (begin == null && rect != null) {
      // First spotlight: grow from the target's center.
      begin = Rect.fromCenter(center: rect.center, width: 8, height: 8);
    }
    _rectTween = RectTween(begin: begin, end: rect);
    _rectController.forward(from: 0);
  }

  Future<void> _finish() async {
    _navToken++; // cancel any in-flight measurement
    await AppTourService.markTourSeen();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isFirst = _step == 0;
    final isLast = _step == _steps.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rectController, _pulse]),
        builder: (context, _) {
          // Smoothly interpolate the spotlight between steps.
          final t = Curves.easeOutCubic.transform(_rectController.value);
          final hole = _rectTween?.lerp(t) ?? _holeTarget;

          return Stack(
            key: _stackKey,
            children: [
              // Scrim with a real cutout over the measured target.
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {}, // Block touches to the app below.
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      hole: hole,
                      circular: step.circular,
                      pulse: _pulse.value,
                    ),
                  ),
                ),
              ),

              // Bouncing guidance arrow between card and target.
              if (hole != null && !hole.isEmpty)
                _GuidanceArrow(
                  hole: hole,
                  cardBelow: _cardBelowTarget(hole, context),
                  pulse: _pulse.value,
                ),

              // Popup info card.
              _positionedCard(
                context: context,
                hole: hole,
                child: _TourCard(
                  key: ValueKey(_step),
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
          );
        },
      ),
    );
  }

  /// True when the card sits below the target (arrow points up).
  bool _cardBelowTarget(Rect hole, BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final bottomInset = mq.viewInsets.bottom + mq.padding.bottom;
    final spaceAbove = hole.top - mq.padding.top;
    final spaceBelow = screenH - bottomInset - hole.bottom;
    return spaceBelow >= 280 || (spaceBelow > spaceAbove && spaceBelow >= 200);
  }

  Widget _positionedCard({
    required BuildContext context,
    required Rect? hole,
    required Widget child,
  }) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final bottomInset = mq.viewInsets.bottom + mq.padding.bottom;
    double? top;
    double? bottom;
    if (hole == null || hole.isEmpty) {
      // Welcome / done: center the card on the scrim.
      var topPos = (screenH - bottomInset - 340) / 2;
      if (topPos < mq.padding.top + 16) topPos = mq.padding.top + 16;
      top = topPos;
    } else if (_cardBelowTarget(hole, context)) {
      top = hole.bottom + 44;
    } else {
      bottom = screenH - hole.top + 44;
      if (bottom < bottomInset + 16) bottom = bottomInset + 16;
    }
    return Positioned(
      left: 20,
      right: 20,
      top: top,
      bottom: bottom,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenH - bottomInset - mq.padding.top - 48,
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

/// Small bouncing chevron that points from the card at the spotlight.
class _GuidanceArrow extends StatelessWidget {
  final Rect hole;
  final bool cardBelow;
  final double pulse;

  const _GuidanceArrow({
    required this.hole,
    required this.cardBelow,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cx = hole.center.dx.clamp(32.0, mq.size.width - 32);
    final bounce = pulse * 8;
    return Positioned(
      left: cx - 16,
      top: cardBelow ? hole.bottom + 8 + bounce : null,
      bottom: cardBelow
          ? null
          : (mq.size.height - hole.top + 8 + bounce),
      child: IgnorePointer(
        child: Icon(
          cardBelow ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: VirelloColors.pink,
          size: 32,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// Dark scrim with a cutout hole over the target + pulsing glow ring.
class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  final bool circular;
  final double pulse;

  _SpotlightPainter({
    required this.hole,
    required this.circular,
    required this.pulse,
  });

  Path _holePath(Rect r) => circular
      ? (Path()..addOval(r))
      : (Path()
        ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(18))));

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.saveLayer(full, Paint());
    canvas.drawRect(
        full, Paint()..color = Colors.black.withValues(alpha: 0.72));
    if (hole != null && !hole!.isEmpty) {
      canvas.drawPath(_holePath(hole!), Paint()..blendMode = BlendMode.clear);
    }
    canvas.restore();

    if (hole != null && !hole!.isEmpty) {
      final glow = hole!.inflate(5 + pulse * 7);
      final ring = Paint()
        ..color = VirelloColors.pink.withValues(alpha: 0.55 + pulse * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final edge = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      if (circular) {
        canvas.drawOval(glow, ring);
        canvas.drawOval(hole!, edge);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(glow, const Radius.circular(22)), ring);
        canvas.drawRRect(
            RRect.fromRectAndRadius(hole!, const Radius.circular(18)), edge);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse || old.circular != circular;
}

/// The elegant popup card shown for each tour step.
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
    super.key,
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
    final s = AppStrings(appState.localeCode);
    return Semantics(
      container: true,
      label: '${step.title(s)} — ${s.tourTakeTour} ${stepIndex + 1}/$totalSteps',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: VirelloColors.pink.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey('tour-body-$stepIndex'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title(s),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${stepIndex + 1} / $totalSteps',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: VirelloColors.pink
                                .withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      s.tourSkip,
                      style: const TextStyle(
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
                  // Progress dots (compact for 15 steps).
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          totalSteps,
                          (i) => Container(
                            width: i == stepIndex ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i == stepIndex
                                  ? VirelloColors.pink
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.black
                                          .withValues(alpha: 0.12)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
        ),
      ),
    );
  }
}
