import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../main.dart';

/// Language settings: app UI language (en/ur/ar — the only full interfaces),
/// preferred content language, content languages (any of the 44 packs), and
/// the "all relevant languages" AI-matching preference.
///
/// Honest labels: languages whose pack has ui_status != "full" are marked
/// as content-language only — the UI itself stays in the chosen full
/// interface language.
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});
  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  List<Map<String, dynamic>> _packs = [];
  String? _preferred;
  Set<String> _contentLangs = {};
  bool _allRelevant = false;
  bool _loading = true;
  String _query = '';
  String? _error;

  static const _fullUi = {'en', 'ur', 'ar'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final langs = await apiClient.listLanguages();
      final me = await apiClient.me();
      final packs = (langs['languages'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      packs.sort((a, b) =>
          (a['name_en'] as String).compareTo(b['name_en'] as String));
      if (!mounted) return;
      setState(() {
        _packs = packs;
        _preferred = me['preferred_language'] as String?;
        _contentLangs = {
          for (final c in (me['content_languages'] as List? ?? [])) c as String
        };
        _allRelevant = me['all_relevant_languages'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _savePrefs() async {
    final s = AppStrings(appState.localeCode);
    try {
      await apiClient.updateLanguagePrefs(
        preferredLanguage: _preferred,
        contentLanguages: _contentLangs.toList(),
        allRelevantLanguages: _allRelevant,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.savedDone)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      appBar: AppBar(title: Text(s.langSettings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  _SectionTitle(s.langUiLanguage),
                  RadioGroup<String>(
                    groupValue: appState.localeCode,
                    onChanged: (v) {
                      if (v != null) appState.setLocale(v);
                    },
                    child: Column(
                      children: _fullUi.map((code) {
                        final pack = _packs.firstWhere(
                            (p) => p['code'] == code,
                            orElse: () => {'code': code, 'name_en': code});
                        final native = pack['name_native'] as String? ?? '';
                        return RadioListTile<String>(
                          value: code,
                          title: Text(
                              '${pack['name_en']}${native.isNotEmpty ? ' · $native' : ''}'),
                          subtitle: Text(s.langUiFullNote),
                          secondary: pack['rtl'] == true
                              ? const Icon(Icons.format_textdirection_r_to_l)
                              : null,
                        );
                      }).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(s.langUiPartialNote,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const Divider(),
                  _SectionTitle(s.langPreferred),
                  _PreferredPicker(
                    packs: _packs,
                    value: _preferred,
                    onChanged: (v) => setState(() => _preferred = v),
                  ),
                  const Divider(),
                  _SectionTitle(s.langContentLanguages),
                  SwitchListTile(
                    value: _allRelevant,
                    onChanged: (v) => setState(() => _allRelevant = v),
                    title: Text(s.langAllRelevant),
                    subtitle: Text(s.langAllRelevantDesc),
                  ),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: s.langSearchLanguages,
                    ),
                    onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  ..._packs
                      .where((p) =>
                          _query.isEmpty ||
                          (p['name_en'] as String)
                              .toLowerCase()
                              .contains(_query) ||
                          ((p['name_native'] as String?) ?? '')
                              .contains(_query))
                      .map((p) {
                    final code = p['code'] as String;
                    final fullUi = _fullUi.contains(code);
                    return CheckboxListTile(
                      value: _contentLangs.contains(code),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _contentLangs.add(code);
                        } else {
                          _contentLangs.remove(code);
                        }
                      }),
                      title: Text(
                          '${p['name_en']} · ${p['name_native'] ?? ''}'),
                      subtitle: Text(fullUi
                          ? s.langUiFullNote
                          : (p['ui_status'] == 'full'
                              ? s.langUiFullNote
                              : s.langUiPartialNote)),
                      secondary: p['rtl'] == true
                          ? const Icon(Icons.format_textdirection_r_to_l,
                              size: 18)
                          : null,
                    );
                  }),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _savePrefs,
                    child: Text(s.saveChanges),
                  ),
                  const SizedBox(height: 24),
                ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _PreferredPicker extends StatelessWidget {
  final List<Map<String, dynamic>> packs;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _PreferredPicker(
      {required this.packs, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value != null && packs.any((p) => p['code'] == value)
          ? value
          : null,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      hint: const Text('—'),
      items: packs
          .map((p) => DropdownMenuItem<String>(
                value: p['code'] as String,
                child: Text('${p['name_en']} · ${p['name_native'] ?? ''}',
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
