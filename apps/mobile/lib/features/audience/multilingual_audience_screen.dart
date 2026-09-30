import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// 37 · Multilingual Audience — board-faithful "Languages" screen.
///
/// Rows show the REAL languages from the backend's 44-pack registry with a
/// "Details" button per language. The board shows percentages, but audience
/// share per language is not tracked anywhere — we never invent them, so an
/// honest note says so instead.
class MultilingualAudienceScreen extends StatefulWidget {
  const MultilingualAudienceScreen({super.key});
  @override
  State<MultilingualAudienceScreen> createState() =>
      _MultilingualAudienceScreenState();
}

class _MultilingualAudienceScreenState
    extends State<MultilingualAudienceScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final j = await apiClient.listLanguages();
      final langs = (j['languages'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      langs.sort((a, b) => '${a['name_en']}'.compareTo('${b['name_en']}'));
      return langs;
    } on AuthException {
      if (mounted) handleAuthFailure(s.sessionExpired);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10Languages,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: VirelloColors.pink,
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: const [
                  VShimmerBox(height: 64, radius: 16),
                  SizedBox(height: 10),
                  VShimmerBox(height: 64, radius: 16),
                  SizedBox(height: 10),
                  VShimmerBox(height: 64, radius: 16),
                ],
              );
            }
            final all = snap.data ?? [];
            final q = _query.trim().toLowerCase();
            final langs = q.isEmpty
                ? all
                : all
                    .where((l) =>
                        '${l['name_en']}'.toLowerCase().contains(q) ||
                        '${l['name_native']}'.toLowerCase().contains(q) ||
                        '${l['code']}'.toLowerCase().contains(q))
                    .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _honestNote(all.length),
                const SizedBox(height: 12),
                VSearchBar(
                  hint: s.boardSearchHint,
                  onSubmitted: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                if (langs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(s.boardNoResults,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: VTheme.textSec(context))),
                  )
                else
                  for (final l in langs) ...[
                    _languageRow(l),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _honestNote(int count) {
    return VBoardCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: VirelloColors.pink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.p10LangStatsNote,
              style:  TextStyle(
                  fontSize: 12, color: VTheme.textSec(context), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageRow(Map<String, dynamic> l) {
    final code = '${l['code'] ?? ''}';
    final nameEn = '${l['name_en'] ?? code}';
    final nameNative = '${l['name_native'] ?? ''}';
    return VBoardCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          VGlassLangBadge(code: code),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nameEn,
                    style:  TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: VTheme.text(context))),
                if (nameNative.isNotEmpty && nameNative != nameEn)
                  Text(nameNative,
                      style:  TextStyle(
                          fontSize: 12.5, color: VTheme.textSec(context))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _showDetails(l),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: VTheme.divider(context)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(s.p10Details, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showDetails(Map<String, dynamic> l) {
    final scripts = ((l['scripts'] as List?) ?? []).join(', ');
    final regions = ((l['regions'] as List?) ?? []).join(', ');
    showModalBottomSheet(
      context: context,
      backgroundColor: VTheme.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VGlassLangBadge(code: '${l['code'] ?? ''}'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${l['name_en'] ?? ''}',
                            style:  TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: VTheme.text(context))),
                        Text('${l['name_native'] ?? ''}',
                            style:  TextStyle(
                                fontSize: 13,
                                color: VTheme.textSec(context))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _meta('Code', (l['code'] ?? '').toString()),
              if (scripts.isNotEmpty) _meta('Scripts', scripts),
              if (regions.isNotEmpty) _meta('Regions', regions),
              _meta('RTL', l['rtl'] == true ? '✓' : '—'),
              _meta('UI status', (l['ui_status'] ?? '').toString()),
              _meta('Pack quality', '${l['pack_quality'] ?? ''}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: RichText(
          text: TextSpan(
            style:  TextStyle(
                fontSize: 13, color: VTheme.textSec(context)),
            children: [
              TextSpan(
                  text: '$label: ',
                  style:  TextStyle(
                      fontWeight: FontWeight.w700, color: VTheme.text(context))),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}
