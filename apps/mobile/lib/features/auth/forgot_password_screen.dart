import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// "Forgot password?" — step 1: email an OTP code (proves ownership);
/// step 2: code + new password. Backend signs the user in on success.
/// Also lets OTP/OAuth accounts attach a password for the first time.
/// Board styling: dark background, dark icon fields, pink buttons.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _codeSent = false;
  bool _working = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = s.invalidEmail);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await authStore.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _working = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = s.signInFailed;
      });
    }
  }

  Future<void> _reset() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = s.invalidCode);
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      setState(() => _error = s.passwordTooShort);
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = s.passwordsDontMatch);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await authStore.confirmPasswordReset(
        _emailCtrl.text,
        _codeCtrl.text,
        _passwordCtrl.text,
      );
      // AuthStore notifies; main.dart swaps to the app shell.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    if (e is ApiException && e.status == 401) return s.invalidCode;
    return s.signInFailed;
  }

  Widget _eye(bool obscured, VoidCallback onTap) => IconButton(
    icon: Icon(
      obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      color: VTheme.textSec(context),
    ),
    onPressed: onTap,
  );

  @override
  Widget build(BuildContext context) {
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
                  s.resetPasswordTitle,
                  textAlign: TextAlign.center,
                  style:  TextStyle(
                    color: VTheme.text(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_codeSent) ...[
                  VDarkField(
                    controller: _emailCtrl,
                    hint: s.emailHint,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _sendCode(),
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
                  const SizedBox(height: 20),
                  VPinkButton(
                    label: s.sendCodeBtn,
                    loading: _working,
                    onPressed:
                        (_emailCtrl.text.trim().contains('@') && !_working)
                        ? _sendCode
                        : null,
                  ),
                ] else ...[
                  Text(
                    '${s.codeSentTo} ${_emailCtrl.text.trim()}',
                    textAlign: TextAlign.center,
                    style:  TextStyle(
                      fontSize: 13.5,
                      color: VTheme.textSec(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  VDarkField(
                    controller: _codeCtrl,
                    hint: s.codeHint,
                    icon: Icons.key_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  VDarkField(
                    controller: _passwordCtrl,
                    hint: s.passwordHint,
                    icon: Icons.lock_outline,
                    obscure: _obscure1,
                    suffix: _eye(
                      _obscure1,
                      () => setState(() => _obscure1 = !_obscure1),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  VDarkField(
                    controller: _confirmCtrl,
                    hint: s.confirmPasswordLabel,
                    icon: Icons.lock_outline,
                    obscure: _obscure2,
                    suffix: _eye(
                      _obscure2,
                      () => setState(() => _obscure2 = !_obscure2),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _reset(),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _working
                          ? null
                          : () => setState(() => _codeSent = false),
                      child: Text(
                        s.useDifferentEmail,
                        style: const TextStyle(color: VirelloColors.pink),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: VirelloColors.pink,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  VPinkButton(
                    label: s.resetPasswordBtn,
                    loading: _working,
                    onPressed: _working ? null : _reset,
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
