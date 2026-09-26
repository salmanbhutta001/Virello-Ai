import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Email + password account creation. Backend bcrypt-hashes the password
/// and returns the JWT pair (signed in immediately).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _working = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
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
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = s.passwordsDontMatch);
      return;
    }
    setState(() { _working = true; _error = null; });
    try {
      await authStore.signUpWithPassword(
          email, _passwordCtrl.text, _nameCtrl.text);
      // AuthStore notifies; main.dart swaps to the app shell.
    } catch (e) {
      if (!mounted) return;
      setState(() { _working = false; _error = _friendly(e); });
    }
  }

  String _friendly(Object e) {
    if (e is ApiException && e.status == 409) return s.accountExistsSignIn;
    if (e is ApiException && e.status == 422) return s.passwordTooShort;
    return s.signInFailed;
  }

  void _policySoon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.policySoon)));
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool optional = false,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(optional ? label : '$label *',
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
              suffixIcon: suffix,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _signUp(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFF4F50FE);
    final canSubmit = _emailCtrl.text.trim().contains('@') &&
        _passwordCtrl.text.isNotEmpty &&
        _confirmCtrl.text.isNotEmpty &&
        !_working;
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
                Text(s.signUpTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
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
                const SizedBox(height: 24),
                _field(
                  controller: _nameCtrl,
                  label: s.nameLabelOptional,
                  hint: s.nameLabelOptional,
                  optional: true,
                ),
                _field(
                  controller: _emailCtrl,
                  label: s.emailLabel,
                  hint: s.emailHint,
                  keyboardType: TextInputType.emailAddress,
                ),
                _field(
                  controller: _passwordCtrl,
                  label: s.passwordLabel,
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
                if (_error != null) ...[
                  Text(_error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 13)),
                  const SizedBox(height: 10),
                ],
                FilledButton(
                  onPressed: canSubmit ? _signUp : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: violet,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: _working
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(s.signUpBtn,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.alreadyHaveAccountQ,
                        style: const TextStyle(
                            fontSize: 13.5, color: Colors.grey)),
                    TextButton(
                      onPressed: _working
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4)),
                      child: Text(s.logInLink,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: violet)),
                    ),
                  ],
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
