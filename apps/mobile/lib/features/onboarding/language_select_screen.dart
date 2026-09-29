import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 05 — Select Language: rows with language name + radio,
/// pink Continue. All 11 languages switch the app locale immediately
/// (and persist as the backend preferred language).
class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  static const _langs = [
    ('en', 'English'),
    ('ur', 'اردو'),
    ('ar', 'العربية'),
    ('hi', 'हिन्दी'),
    ('fr', 'Français'),
    ('es', 'Español'),
    ('pt', 'Português'),
    ('de', 'Deutsch'),
    ('tr', 'Türkçe'),
    ('id', 'Bahasa Indonesia'),
    ('bn', 'বাংলা'),
  ];

  String _selected = 'en';
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _selected = appState.localeCode;
    if (!_langs.any((l) => l.$1 == _selected)) {
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
                    final selected = _selected == code;
                    return InkWell(
                      onTap: () => setState(() => _selected = code),
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
