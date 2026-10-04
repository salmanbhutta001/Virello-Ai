import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 01 — cinematic splash: full-bleed hero image (no blur),
/// original colorful logo (single, no duplicate wordmark), tagline
/// "Create • Discover • Grow • Viral", and the pink arrow CTA.
///
/// Background color is sampled from the hero image edges (#2A3733 dark
/// slate) so the image blends seam-free edge-to-edge with no black bars
/// and no stretching (BoxFit.cover crops, never distorts).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});
  final VoidCallback onGetStarted;

  /// Seam color sampled from splash-hero.jpg edges.
  static const _seamColor = Color(0xFF2A3733);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      backgroundColor: _seamColor,
      body: Stack(
        children: [
          // Cinematic background — full-bleed, sharp, aligned (no blur).
          // BoxFit.cover fills every pixel: crops overflow, never stretches.
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash-hero.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: _seamColor),
            ),
          ),
          // Gentle scrims: a touch of dark at the very top (logo legibility)
          // and bottom (CTA legibility). The middle stays fully vibrant.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.22, 0.72, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.38),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.42),
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
                  const Spacer(flex: 2),
                  // Original colorful logo — already carries the
                  // "Virello AI" wordmark, so no separate text below it.
                  Image.asset(
                    'assets/images/logo-virello-dark.png',
                    height: 68,
                    errorBuilder: (_, __, ___) => const Text(
                      'Virello AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    s.splashTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.boardIdeasAmplified,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                  VPinkCircleButton(onPressed: onGetStarted),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
