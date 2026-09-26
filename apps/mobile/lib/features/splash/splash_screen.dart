import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../auth/sign_in_screen.dart';

/// Board screen 1 — full-bleed splash over the hero image.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      body: Stack(
        children: [
          // Full-bleed hero image.
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash-hero.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Cinematic dark top + bottom scrim so the tag and copy stay
          // readable over the bright hero photo (mockup-approved).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.32, 0.55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Text block is left-aligned and width-constrained so the
                  // splash photo's subject stays fully visible (no overlap).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 210),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/images/logo-virello-dark.png',
                            height: 48,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            s.splashTagline,
                            softWrap: false,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          // Headline sits just below the tag.
                          const SizedBox(height: 30),
                          Text(
                            s.splashHeadline,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.splashSub,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  VGradientButton(
                    label: s.getStarted,
                    icon: Icons.arrow_forward,
                    onPressed: onGetStarted,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignInScreen(),
                        ),
                      );
                    },
                    child: Text(
                      s.alreadyHaveAccount,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
