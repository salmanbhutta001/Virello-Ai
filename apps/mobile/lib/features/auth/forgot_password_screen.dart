import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// "Forgot password?" — step 1: email an OTP code (proves ownership);
/// step 2: code + new password. Backend signs the user in on success.
/// Also lets OTP/OAuth accounts attach a password for the first time.
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
    setState(() { _working = true; _error = null; });
    try {
      await authStore.requestPasswordReset(email);
      if (!mounted) return;
      setState(() { _codeSent = true; _working = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _working = false; _error = s.signInFailed; });
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
    setState(() { _working = true; _error = null; });
    try {
      await authStore.confirmPasswordReset(
          _emailCtrl.text, _codeCtrl.text, _passwordCtrl.text);
      // AuthStore notifies; main.dart swaps to the app shell.
    } catch (e) {
      if (!mounted) return;
      setState(() { _working = false; _error = _friendly(e); });
    }
  }

  String _friendly(Object e) {
    if (e is ApiException && e.status == 401) return s.invalidCode;
    if (e is ApiException && e.status == 422) return s.passwordTooShort;
    if (e is ApiException && e.status == 404) return s.invalidEmailOrPassword;
    return s.signInFailed;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    Widget? prefix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label *',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: !obscure,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: prefix,
              suffixIcon: suffix,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _codeSent ? _reset() : _sendCode(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFF4F50FE);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.resetPasswordTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                if (!_codeSent) ...[
                  _field(
                    controller: _emailCtrl,
                    label: s.emailLabel,
                    hint: s.emailHint,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (_error != null) ...[
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    onPressed: (_emailCtrl.text.trim().contains('@') &&
                            !_working)
                        ? _sendCode
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
                        : Text(s.sendCodeBtn,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                ] else ...[
                  Text('${s.codeSentTo} ${_emailCtrl.text.trim()}',
                      style: const TextStyle(
                          fontSize: 13.5, color: Colors.grey)),
                  const SizedBox(height: 16),
                  _field(
                    controller: _codeCtrl,
                    label: s.enterCode,
                    hint: s.codeHint,
                    keyboardType: TextInputType.number,
                    prefix: const Icon(Icons.key_outlined),
                  ),
                  _field(
                    controller: _passwordCtrl,
                    label: s.newPasswordLabel,
                    hint: s.passwordHint,
                    obscure: _obscure1,
                    suffix: IconButton(
                      icon: Icon(_obscure1
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  _field(
                    controller: _confirmCtrl,
                    label: s.confirmPasswordLabel,
                    hint: s.confirmPasswordLabel,
                    obscure: _obscure2,
                    suffix: IconButton(
                      icon: Icon(_obscure2
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
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
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    onPressed: _working ? null : _reset,
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
                        : Text(s.resetPasswordBtn,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
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
