import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_up_screen.dart';

/// Board screen 02 — Welcome: pink V mark, headline, description,
/// pink "Get Started" → Sign Up, "Already have an account? Log In".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      backgroundColor: VirelloColors.boardBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Image.asset(
                  'assets/images/logo-virello.png',
                  height: 72,
                  color: VirelloColors.pink,
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (_, __, ___) => const Text(
                    'V',
                    style: TextStyle(
                      color: VirelloColors.pink,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                s.boardWelcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                s.boardWelcomeDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VirelloColors.boardTextSec,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const Spacer(flex: 3),
              VPinkButton(
                label: s.getStarted,
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: VirelloColors.boardTextSec,
                  ),
                  children: [
                    TextSpan(text: s.alreadyHaveAccountQ),
                    TextSpan(
                      text: ' ${s.logInLink}',
                      style: const TextStyle(
                        color: VirelloColors.pink,
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SignInScreen(),
                          ),
                        ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
