import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 01 — cinematic splash: full-bleed hero image (no blur),
/// original colorful logo (single, no duplicate wordmark), tagline
/// "Create • Discover • Grow • Viral", and the pink arrow CTA.
///
/// Re-created 2026-10-05 (Hafiz): background MUST cover every pixel of the
/// screen — no stretch, no side bars. Implementation notes:
/// - StackFit.expand forces the background to the exact screen size.
/// - BoxFit.cover fills without distortion (crops only if aspect differs).
/// - Hero art is 9:20 (1008x2240) so cover-crop on tall phones is ~zero.
/// - Seam color sampled from the hero edges (#2A3733) as the last-resort
///   backdrop; the status bar is transparent so the image runs edge to edge.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});
  final VoidCallback onGetStarted;

  /// Seam color sampled from splash-hero.jpg edges.
  static const _seamColor = Color(0xFF2A3733);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    // Transparent system bars: the hero runs behind status + navigation.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: _seamColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cinematic background — exact screen size, never stretched.
            Image.asset(
              'assets/images/splash-hero.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: _seamColor),
            ),
            // Gentle scrims: a touch of dark at the very top (logo
            // legibility) and bottom (CTA legibility). Middle stays vibrant.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.22, 0.72, 1.0],
                  colors: [
                    Color(0x61000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x6B000000),
                  ],
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
      ),
    );
  }
}
