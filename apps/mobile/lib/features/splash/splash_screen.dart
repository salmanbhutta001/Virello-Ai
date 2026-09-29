import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 01 — dark splash: pink V mark, "Virello AI",
/// "Create • Discover • Grow", tagline, pink circular arrow button.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      backgroundColor: VirelloColors.boardBg,
      body: SafeArea(
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
              const Text(
                'Virello AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.splashTagline,
                style: const TextStyle(
                  color: VirelloColors.boardTextSec,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                s.boardIdeasAmplified,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VirelloColors.boardTextSec,
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
    );
  }
}
