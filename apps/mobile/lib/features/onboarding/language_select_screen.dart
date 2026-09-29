import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Board screen 05 — Select Language: rows with language name + radio,
/// pink Continue. English / اردو / العربية switch the app locale
/// immediately (and persist as the backend preferred language);
/// Français / Español / हिन्दी are shown as "soon" per the board.
class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  static const _langs = [
    ('en', 'English', true),
    ('ur', 'اردو', true),
    ('ar', 'العربية', true),
    ('fr', 'Français', false),
    ('es', 'Español', false),
    ('hi', 'हिन्दी', false),
  ];

  String _selected = 'en';
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _selected = appState.localeCode;
    if (!_langs.any((l) => l.$1 == _selected && l.$3)) {
      _selected = 'en';
    }
  }

  Future<void> _continue() async {
    setState(() => _working = true);
    appState.setLocale(_selected);
    // Persist as the backend preferred language; never blocks onboarding.
    try {
      await apiClient.updateLanguagePrefs(preferredLanguage: _selected);
    } catch (_) {}
    if (mounted) setState(() => _working = false);
    widget.onDone();
  }

  void _soon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.policySoon)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VirelloColors.boardBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                s.boardSelectLanguage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _langs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final code = _langs[i].$1;
                    final name = _langs[i].$2;
                    final supported = _langs[i].$3;
                    final selected = _selected == code;
                    return InkWell(
                      onTap: supported
                          ? () => setState(() => _selected = code)
                          : _soon,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: VirelloColors.boardField,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? VirelloColors.pink
                                : VirelloColors.boardBorder,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            VGlassLangBadge(code: code, glyphSize: 13),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!supported)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: VirelloColors.boardBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Soon',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: VirelloColors.boardTextSec,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: selected
                                    ? VirelloColors.pink
                                    : VirelloColors.boardTextSec,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              VPinkButton(
                label: s.continueBtn,
                loading: _working,
                onPressed: _continue,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
