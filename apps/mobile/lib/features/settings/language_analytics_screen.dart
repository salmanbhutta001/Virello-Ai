import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board 58 — Language Analytics.
///
/// "Languages" header, one row per real supported language with a
/// percentage bar. The percentage is the HONEST app-UI translation
/// coverage: en/ur/ar ship a complete app interface (100%); the other
/// packs are content languages (AI detection + audience matching) with no
/// app-UI translation (0% + "Content" badge). Never usage estimates —
/// no usage data exists. Data: GET /api/v1/languages (the 44-pack registry).
class LanguageAnalyticsScreen extends StatefulWidget {
  const LanguageAnalyticsScreen({super.key});
  @override
  State<LanguageAnalyticsScreen> createState() =>
      _LanguageAnalyticsScreenState();
}

class _LanguageAnalyticsScreenState extends State<LanguageAnalyticsScreen> {
  List<Map<String, dynamic>> _langs = [];
  int _count = 0;
  bool _loading = true;
  String? _error;

  /// Codes with a complete app interface in the shipped Flutter UI.
  static const _fullUi = {
    'en',
    'ur',
    'ar',
    'hi',
    'fr',
    'es',
    'pt',
    'de',
    'tr',
    'id',
    'bn'
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await apiClient.listLanguages();
      if (!mounted) return;
      final langs = (r['languages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      langs.sort((a, b) {
        final fa = _fullUi.contains(a['code']) ? 0 : 1;
        final fb = _fullUi.contains(b['code']) ? 0 : 1;
        if (fa != fb) return fa.compareTo(fb);
        return (a['name_en'] as String? ?? '')
            .compareTo(b['name_en'] as String? ?? '');
      });
      setState(() {
        _langs = langs;
        _count = (r['count'] as int?) ?? langs.length;
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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final fullCount = _langs.where((l) => _fullUi.contains(l['code'])).length;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p11Languages,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: VirelloColors.muted)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        VBoardCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.p11LangsSupported(_count),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                '$fullCount ${s.p11FullUi} · ${_count - fullCount} ${s.p11ContentOnly}',
                                style: const TextStyle(
                                    fontSize: 13, color: VirelloColors.muted),
                              ),
                              const SizedBox(height: 8),
                              Text(s.p11CoverageNote,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: VirelloColors.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        VBoardCard(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: List.generate(_langs.length, (i) {
                              final l = _langs[i];
                              final code = (l['code'] ?? '').toString();
                              final full = _fullUi.contains(code);
                              final nameEn = (l['name_en'] ?? code).toString();
                              final native =
                                  (l['name_native'] ?? '').toString();
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 9),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  native.isNotEmpty
                                                      ? '$nameEn · $native'
                                                      : nameEn,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: full
                                                      ? VirelloColors.pink
                                                          .withValues(
                                                              alpha: 0.15)
                                                      : VTheme.chip(context),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  full
                                                      ? s.p11FullUi
                                                      : s.p11ContentOnly,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: full
                                                        ? VirelloColors.pink
                                                        : VirelloColors.muted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: full ? 1.0 : 0.0,
                                              minHeight: 6,
                                              backgroundColor:
                                                  VTheme.chip(context),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                          Color>(
                                                      VirelloColors.pink),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 44,
                                      child: Text(
                                        full ? '100%' : '—',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: VirelloColors.muted),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(s.p11ContentOnlyNote,
                            style: const TextStyle(
                                fontSize: 12, color: VirelloColors.muted)),
                      ],
                    ),
                  ),
      ),
    );
  }
}
