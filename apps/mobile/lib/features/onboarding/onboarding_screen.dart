import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';

/// Premium 3-slide onboarding → value prop → trust → get started.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    const slides = [
      _Slide(Icons.auto_awesome, 'Meet your AI Growth Manager',
        'Paste a post. Pick a goal. Press LET AI GROW.\nVirello AI handles the rest.'),
      _Slide(Icons.insights, 'Real growth, honestly measured',
        'Live reach, engagement, clicks and conversions.\nOptimized continuously — never faked.'),
      _Slide(Icons.verified_user, 'Trust by design',
        'No fake followers. No bots. No passwords.\nOAuth only. No guaranteed-virality claims — ever.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onDone,
              child: Text(appState.localeCode == 'ur' ? 'چھوڑیں' : 'Skip'),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: slides.length,
              itemBuilder: (_, i) => _buildSlide(slides[i]),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.all(4),
              width: _page == i ? 28 : 8, height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _page == i ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
              ),
            )),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _page == slides.length - 1 ? widget.onDone() : _ctrl.nextPage(
                  duration: const Duration(milliseconds: 400), curve: Curves.easeOut),
                child: Text(_page == slides.length - 1 ? s.letAiGrow : s.continueBtn),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSlide(_Slide slide) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 140, height: 140,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: VirelloTheme.growGradient,
          boxShadow: [BoxShadow(color: const Color(0xFFF95177).withValues(alpha: 0.35), blurRadius: 50)]),
        child: Icon(slide.icon, size: 64, color: VTheme.onBrand(context)),
      ),
      const SizedBox(height: 40),
      Text(slide.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(slide.body, style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5), textAlign: TextAlign.center),
    ]),
  );
}

class _Slide {
  final IconData icon; final String title, body;
  const _Slide(this.icon, this.title, this.body);
}
