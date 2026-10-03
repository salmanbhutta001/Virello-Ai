import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/brand_icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Board screen 03 — Create Account: dark fields (Full name / Email /
/// Password), pink Sign Up, Apple sign-in on iOS only,
/// "Already have an account? Log In".
///
/// Logic preserved: email+password signup (backend bcrypt), Apple OAuth
/// on iOS (backend-verified). Google/Facebook removed per Hafiz 2026-10-03.
/// We never ask for social-media passwords.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _working = false;
  bool _obscure = true;
  String? _error;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = s.invalidEmail);
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      setState(() => _error = s.passwordTooShort);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await authStore.signUpWithPassword(
        email,
        _passwordCtrl.text,
        _nameCtrl.text.trim(),
      );
      // AuthStore notifies; main.dart swaps to the app shell.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(e);
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _friendly(Object e) {
    if (e is ApiException && e.status == 409) return s.accountExistsSignIn;
    if (e is ApiException && e.status == 422) return s.passwordTooShort;
    return s.signInFailed;
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = cred.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('missing identity token');
      }
      await authStore.signInWithProvider('apple', idToken, cred.email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = s.socialSignInFailed;
      });
    }
  }

  Widget _socialCircle({required Widget child, required VoidCallback? onTap}) {
    return InkWell(
      onTap: _working ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: VTheme.chip(context),
          border: Border.all(color: VTheme.divider(context)),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _emailCtrl.text.trim().contains('@') &&
        _passwordCtrl.text.length >= 8 &&
        !_working;
    return Scaffold(
      backgroundColor: VTheme.scaffold(context),
      appBar: AppBar(
        leading:  BackButton(color: VTheme.text(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.boardCreateAccount,
                  textAlign: TextAlign.center,
                  style:  TextStyle(
                    color: VTheme.text(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 28),
                VDarkField(
                  controller: _nameCtrl,
                  hint: s.boardFullName,
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                VDarkField(
                  controller: _emailCtrl,
                  hint: s.emailHint,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _signUp(),
                ),
                const SizedBox(height: 14),
                VDarkField(
                  controller: _passwordCtrl,
                  hint: s.passwordHint,
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: VTheme.textSec(context),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _signUp(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: VirelloColors.pink,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                VPinkButton(
                  label: s.signUpBtn,
                  loading: _working,
                  onPressed: canSubmit ? _signUp : null,
                ),
                const SizedBox(height: 20),
                // Social sign-in: Apple on iOS only (Google/Facebook removed).
                if (Platform.isIOS) ...[
                  Row(
                    children: [
                       Expanded(
                        child: Divider(color: VTheme.divider(context)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          s.orContinueWith,
                          style:  TextStyle(
                            fontSize: 12,
                            color: VTheme.textSec(context),
                          ),
                        ),
                      ),
                       Expanded(
                        child: Divider(color: VTheme.divider(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _socialCircle(
                        onTap: _signInWithApple,
                        child:  IconTheme(
                          data: IconThemeData(color: VTheme.text(context)),
                          child: AppleIcon(size: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
                Text.rich(
                  TextSpan(
                    style:  TextStyle(
                      fontSize: 13.5,
                      color: VTheme.textSec(context),
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
                          ..onTap = _working
                              ? null
                              : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
