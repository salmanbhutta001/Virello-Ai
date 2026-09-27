import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/brand_icons.dart';
import '../../core/strings.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// Reddit-style login: centered "Log In", agreement line, pill buttons
/// (Google / Apple / email me a one-time code), OR divider, email +
/// password fields, "Log In" button, "New to Virello? Sign Up".
///
/// Three ways in: email + password (backend bcrypt-hashed), email one-time
/// code, or the device's Google/Apple account (OAuth, backend-verified).
/// We never ask for social-media passwords.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _codeSent = false;
  bool _working = false;
  bool _emailValid = false;
  bool _obscurePassword = true;
  String? _error;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    // Surface one-shot notices (e.g. expired session) exactly once.
    _error = authStore.lastNotice;
    authStore.lastNotice = null;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = s.invalidEmail);
      return;
    }
    setState(() { _working = true; _error = null; });
    try {
      await authStore.requestOtp(email);
      if (!mounted) return;
      setState(() { _codeSent = true; _working = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _working = false; _error = _friendly(e); });
    }
  }

  /// "Email me a one-time code" pill: sends the code straight away when the
  /// email looks valid, otherwise focuses the email field.
  Future<void> _emailCodePill() async {
    if (!_emailCtrl.text.trim().contains('@')) {
      _emailFocus.requestFocus();
      setState(() => _error = s.invalidEmail);
      return;
    }
    await _sendCode();
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = s.invalidCode);
      return;
    }
    setState(() { _working = true; _error = null; });
    try {
      await authStore.verifyOtp(_emailCtrl.text, _codeCtrl.text);
      // AuthStore notifies; main.dart swaps to the app shell.
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _friendly(e); });
    } finally {
      if (mounted) setState(() => _working = false);
    }
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
    setState(() { _working = true; _error = null; });
    try {
      await authStore.signInWithPassword(email, _passwordCtrl.text);
      // AuthStore notifies; main.dart swaps to the app shell.
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _friendlyPassword(e); });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _friendly(Object e) {
    if (e is AuthException) return s.sessionExpired;
    if (e is ApiException && e.status == 401) return s.invalidCode;
    return s.signInFailed;
  }

  String _friendlyPassword(Object e) {
    if (e is AuthException) return s.sessionExpired;
    if (e is ApiException && e.status == 401) return s.invalidEmailOrPassword;
    if (e is ApiException && e.status == 429) return s.tooManyAttempts;
    return s.signInFailed;
  }

  /// Google (Gmail) sign-in. The native SDK returns an id_token; the backend
  /// verifies it via Google JWKS and creates/links the Virello account —
  /// the user's Gmail address is saved automatically.
  Future<void> _signInWithGoogle() async {
    setState(() { _working = true; _error = null; });
    try {
      final account = await GoogleSignIn(scopes: const ['email', 'profile'])
          .signIn();
      if (account == null) {
        // User cancelled the account picker.
        if (mounted) setState(() => _working = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('missing id_token');
      }
      await authStore.signInWithProvider('google', idToken, account.email);
      // AuthStore notifies; main.dart swaps to the app shell.
    } catch (e) {
      if (!mounted) return;
      setState(() { _working = false; _error = s.socialSignInFailed; });
    }
  }

  /// Apple sign-in (iOS only). Same backend-verified OAuth flow as Google.
  Future<void> _signInWithApple() async {
    setState(() { _working = true; _error = null; });
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
      setState(() { _working = false; _error = s.socialSignInFailed; });
    }
  }

  void _policySoon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.policySoon)));
  }

  Widget _pillButton({
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999)),
          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(s.orDivider,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *',
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: !obscure,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFF4F50FE);
    // Smart back button: only when this screen was pushed (e.g. from the
    // splash's "I already have an account"). As the logged-out root there
    // is nowhere to go back to, so no button is shown.
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text(s.logInTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style:
                        const TextStyle(fontSize: 12.5, color: Colors.grey),
                    children: [
                      TextSpan(text: s.loginAgreementLead),
                      TextSpan(
                        text: s.userAgreement,
                        style: const TextStyle(
                            color: violet, fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _policySoon,
                      ),
                      TextSpan(text: s.loginAgreementMid),
                      TextSpan(
                        text: s.privacyPolicy,
                        style: const TextStyle(
                            color: violet, fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _policySoon,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                if (!_codeSent) ...[
                  _pillButton(
                    icon: const GoogleGIcon(size: 18),
                    label: s.continueWithGoogle,
                    onPressed: _working ? null : _signInWithGoogle,
                  ),
                  if (Platform.isIOS)
                    _pillButton(
                      icon: const AppleIcon(size: 20),
                      label: s.continueWithApple,
                      onPressed: _working ? null : _signInWithApple,
                    ),
                  _pillButton(
                    icon: const Icon(Icons.link, size: 20),
                    label: s.emailMeCode,
                    onPressed: _working ? null : _emailCodePill,
                  ),
                  _orDivider(),
                  _textField(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    label: s.emailLabel,
                    hint: s.emailHint,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) => setState(
                        () => _emailValid = v.trim().contains('@')),
                    onSubmitted: (_) => _passwordLogin(),
                  ),
                  const SizedBox(height: 14),
                  _textField(
                    controller: _passwordCtrl,
                    label: s.passwordLabel,
                    hint: s.passwordHint,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
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
                                        const ForgotPasswordScreen()),
                              ),
                      style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4)),
                      child: Text(s.forgotPassword,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: violet)),
                    ),
                  ),
                  if (_error != null) ...[
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    onPressed: (_emailValid &&
                            _passwordCtrl.text.isNotEmpty &&
                            !_working)
                        ? _passwordLogin
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: violet,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding:
                          const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: _working
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(s.logInBtn,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.newToVirello,
                          style: const TextStyle(
                              fontSize: 13.5, color: Colors.grey)),
                      TextButton(
                        onPressed: _working
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SignUpScreen()),
                                ),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4)),
                        child: Text(s.signUpLink,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: violet)),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(s.enterCode,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(_emailCtrl.text.trim(),
                      style: const TextStyle(
                          fontSize: 13.5, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: s.codeHint,
                      prefixIcon: const Icon(Icons.key_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _working
                          ? null
                          : () => setState(() => _codeSent = false),
                      child: Text(s.useDifferentEmail),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _working ? null : _verify,
                    style: FilledButton.styleFrom(
                      backgroundColor: violet,
                      padding:
                          const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: _working
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(s.verify,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 28),
                Text(s.noPasswordsNote,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
          if (canPop)
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
