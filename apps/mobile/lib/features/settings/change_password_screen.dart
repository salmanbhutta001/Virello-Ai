import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Signed-in password change: current password + new password + confirm.
/// For accounts without a password yet (OTP/OAuth), directs to the
/// Forgot-password flow on the login screen instead.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _working = false;
  bool _obscure0 = true;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_newCtrl.text.length < 8) {
      setState(() => _error = s.passwordTooShort);
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = s.passwordsDontMatch);
      return;
    }
    setState(() { _working = true; _error = null; });
    try {
      await authStore.changePassword(_currentCtrl.text, _newCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.passwordChangedOk)));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() { _working = false; _error = _friendly(e); });
    }
  }

  String _friendly(Object e) {
    if (e is ApiException && e.status == 401) return s.currentPasswordWrong;
    if (e is ApiException && e.status == 422) return s.passwordTooShort;
    return s.signInFailed;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
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
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: label,
              suffixIcon: IconButton(
                icon: Icon(obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: onToggle,
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _change(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _currentCtrl.text.isNotEmpty &&
        _newCtrl.text.isNotEmpty &&
        _confirmCtrl.text.isNotEmpty &&
        !_working;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.changePasswordTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VCard(
                child: Column(children: [
                  _field(
                    controller: _currentCtrl,
                    label: s.currentPasswordLabel,
                    obscure: _obscure0,
                    onToggle: () =>
                        setState(() => _obscure0 = !_obscure0),
                  ),
                  _field(
                    controller: _newCtrl,
                    label: s.newPasswordLabel,
                    obscure: _obscure1,
                    onToggle: () =>
                        setState(() => _obscure1 = !_obscure1),
                  ),
                  _field(
                    controller: _confirmCtrl,
                    label: s.confirmPasswordLabel,
                    obscure: _obscure2,
                    onToggle: () =>
                        setState(() => _obscure2 = !_obscure2),
                  ),
                  if (_error != null) ...[
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    onPressed: canSubmit ? _change : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: VirelloColors.violet,
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
                        : Text(s.changePasswordTitle,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Text(s.noPasswordYet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: VirelloColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
