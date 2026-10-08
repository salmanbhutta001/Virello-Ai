/// First-launch privacy consent gate (Huawei AppGallery review rule 7.5).
///
/// Shown once on the very first app launch, before any other screen: the
/// user must explicitly accept the Privacy Policy to continue. The full
/// policy opens in [LegalDocumentScreen]. Acceptance is persisted in
/// SharedPreferences ('virello_privacy_accepted').
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../settings/legal_document_screen.dart';

/// Full-screen, non-dismissible gate shown on first launch.
class PrivacyConsentGate extends StatefulWidget {
  final VoidCallback onAccepted;
  const PrivacyConsentGate({super.key, required this.onAccepted});

  @override
  State<PrivacyConsentGate> createState() => _PrivacyConsentGateState();
}

class _PrivacyConsentGateState extends State<PrivacyConsentGate> {
  AppStrings get s => AppStrings(appState.localeCode);

  Future<void> _accept() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('virello_privacy_accepted', true);
    } catch (_) {}
    widget.onAccepted();
  }

  void _decline() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.privacyConsentDeclineMsg)),
    );
  }

  void _readPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const LegalDocumentScreen(doc: LegalDoc.privacyPolicy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VTheme.scaffold(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 64,
                  color: VirelloColors.pink,
                ),
                const SizedBox(height: 20),
                Text(
                  s.privacyConsentTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VTheme.text(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  s.privacyConsentBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VTheme.textSec(context),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: VTheme.textSec(context),
                    ),
                    children: [
                      TextSpan(text: s.agreePrivacyPrefix),
                      TextSpan(
                        text: s.privacyPolicyLink,
                        style: const TextStyle(
                          color: VirelloColors.pink,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = _readPolicy,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                VPinkButton(
                  label: s.privacyConsentAccept,
                  onPressed: _accept,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _readPolicy,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VTheme.text(context),
                    side: BorderSide(color: VTheme.divider(context)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(s.privacyConsentRead),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _decline,
                  child: Text(
                    s.privacyConsentDecline,
                    style: TextStyle(color: VTheme.textSec(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
