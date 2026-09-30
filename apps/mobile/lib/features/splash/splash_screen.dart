import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 01 — cinematic splash: full-bleed hero image with scrim,
/// pink V mark, "Virello AI", "Create • Discover • Grow • Earn • Viral",
/// tagline, pink circular arrow button.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: VTheme.scaffold(context),
      body: Stack(
        children: [
          // Cinematic background image (full-bleed).
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash-hero.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Scrim for readability: darker at top/bottom, lighter in middle.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.65),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.72),
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0.78),
                        ],
                ),
              ),
            ),
          ),
          SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Pink V mark.
              Image.asset(
                'assets/images/logo-virello.png',
                height: 92,
                color: VirelloColors.pink,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, __, ___) => const Text(
                  'V',
                  style: TextStyle(
                    color: VirelloColors.pink,
                    fontSize: 84,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 20),
               Text(
                'Virello AI',
                style: TextStyle(
                  color: VirelloColors.pink,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.splashTagline,
                textAlign: TextAlign.center,
                style:  TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF3A3A4A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                s.boardIdeasAmplified,
                textAlign: TextAlign.center,
                style:  TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF5A5A6A),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(flex: 4),
              VPinkCircleButton(onPressed: onGetStarted),
              const SizedBox(height: 36),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }
}
