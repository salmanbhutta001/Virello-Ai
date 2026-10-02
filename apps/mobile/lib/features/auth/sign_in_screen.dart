import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/brand_icons.dart';
import '../../core/device_info.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// Board screen 04 — Welcome Back: dark fields (Email / Password),
/// "Forgot password?", pink Log In, "or continue with" + social circles.
///
/// Logic preserved: email+password (backend bcrypt),
/// Google/Apple OAuth (backend-verified). No social-media passwords.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _working = false;
  bool _obscurePassword = true;
  String? _error;
  // Fire OS / de-Googled devices have no Play Services: hide Google Sign-In.
  bool _showGoogle = true;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _error = authStore.lastNotice;
    authStore.lastNotice = null;
    DeviceInfo.hasPlayServices.then((ok) {
      if (mounted && !ok) setState(() => _showGoogle = false);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _passwordLogin() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = s.invalidEmail);
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      setState(() => _error = s.passwordTooShort);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await authStore.signInWithPassword(email, _passwordCtrl.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _friendlyPassword(e);
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _friendlyPassword(Object e) {
    if (e is AuthException) return s.sessionExpired;
    if (e is ApiException && e.status == 401) return s.invalidEmailOrPassword;
    if (e is ApiException && e.status == 429) return s.tooManyAttempts;
    if (e is TimeoutException) return s.tryAgain;
    return s.signInFailed;
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final account = await GoogleSignIn(scopes: const ['email', 'profile'])
          .signIn();
      if (account == null) {
        if (mounted) setState(() => _working = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('missing id_token');
      }
      await authStore.signInWithProvider('google', idToken, account.email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = s.socialSignInFailed;
      });
    }
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

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: VTheme.divider(context))),
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
        Expanded(child: Divider(color: VTheme.divider(context))),
      ],
    );
  }

  Widget _socialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Hidden on Fire OS / devices without Play Services (Google
        // Sign-In cannot work there). Email + OTP login still available.
        if (_showGoogle)
          _socialCircle(
            onTap: _signInWithGoogle,
            child: const GoogleGIcon(size: 22),
          ),
        if (_showGoogle) const SizedBox(width: 16),
        if (Platform.isIOS)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _socialCircle(
              onTap: _signInWithApple,
              child:  IconTheme(
                data: IconThemeData(color: VTheme.text(context)),
                child: AppleIcon(size: 24),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: VTheme.scaffold(context),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.boardWelcomeBack,
                      textAlign: TextAlign.center,
                      style:  TextStyle(
                        color: VTheme.text(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 28),
                    VDarkField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      hint: s.emailHint,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _passwordLogin(),
                    ),
                    const SizedBox(height: 14),
                    VDarkField(
                      controller: _passwordCtrl,
                      hint: s.passwordHint,
                      icon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: VTheme.textSec(context),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _passwordLogin(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _working
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordScreen(),
                                ),
                              ),
                        child: Text(
                          s.forgotPassword,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: VirelloColors.pink,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: VirelloColors.pink,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    VPinkButton(
                      label: s.logInBtn,
                      loading: _working,
                      onPressed:
                          (_emailCtrl.text.trim().contains('@') &&
                              _passwordCtrl.text.isNotEmpty)
                          ? _passwordLogin
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _orDivider(),
                    const SizedBox(height: 18),
                    _socialRow(),
                    const SizedBox(height: 22),
                    Text.rich(
                      TextSpan(
                        style:  TextStyle(
                          fontSize: 13.5,
                          color: VTheme.textSec(context),
                        ),
                        children: [
                          TextSpan(text: s.newToVirello),
                          TextSpan(
                            text: ' ${s.signUpLink}',
                            style: const TextStyle(
                              color: VirelloColors.pink,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _working
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SignUpScreen(),
                                      ),
                                    ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            if (canPop)
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon:  Icon(Icons.arrow_back, color: VTheme.text(context)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
