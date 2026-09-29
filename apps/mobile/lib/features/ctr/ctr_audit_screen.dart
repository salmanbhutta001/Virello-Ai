import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';

/// Free organic growth strategy #6: Link CTR optimizer.
///
/// Pastes a public link -> factual OpenGraph/meta checklist (pass/warn/fail,
/// no 0-100 score) + AI-written title/description fixes with Copy buttons.
/// Per-feature EN/UR/AR strings live in [_CtrStrings] below (l10n .arb files
/// are owned by the coordinator and intentionally untouched).
class CtrAuditScreen extends StatefulWidget {
  final String initialUrl;
  const CtrAuditScreen({super.key, this.initialUrl = ''});

  @override
  State<CtrAuditScreen> createState() => _CtrAuditScreenState();
}

// ---------------------------------------------------------------------------
// Per-feature strings (EN/UR/AR). Keyed lookup with English fallback.
class _CtrStrings {
  final String code;
  const _CtrStrings(this.code);

  static const Map<String, Map<String, String>> _t = {
    'title': {
      'en': 'Link CTR Audit',
      'ur': 'لنک CTR آڈٹ',
      'ar': 'تدقيق CTR للرابط',
    },
    'subtitle': {
      'en':
          'See how your link looks when shared — a factual OpenGraph & meta audit.',
      'ur': 'دیکھیں آپ کا لنک شیئر ہونے پر کیسا لگے گا — حقائق پر مبنی آڈٹ۔',
      'ar': 'شاهد كيف يبدو رابطك عند مشاركته — تدقيق واقعي للوسوم.',
    },
    'urlHint': {
      'en': 'Paste a public link (https://…)',
      'ur': 'عوامی لنک پیسٹ کریں (https://…)',
      'ar': 'الصق رابطًا عامًا (https://…)',
    },
    'auditButton': {
      'en': 'Audit Link',
      'ur': 'لنک آڈٹ کریں',
      'ar': 'تدقيق الرابط',
    },
    'invalidUrl': {
      'en': 'Paste a valid http(s) link first.',
      'ur': 'پہلے درست لنک پیسٹ کریں۔',
      'ar': 'الصق رابطًا صالحًا أولًا.',
    },
    'auditFailed': {
      'en': "Couldn't audit that link. Check the URL and try again.",
      'ur': 'اس لنک کا آڈٹ نہیں ہو سکا۔ URL چیک کر کے دوبارہ کوشش کریں۔',
      'ar': 'تعذّر تدقيق هذا الرابط. تحقق من الرابط وحاول مجددًا.',
    },
    'summaryTitle': {
      'en': 'Audit summary',
      'ur': 'آڈٹ کا خلاصہ',
      'ar': 'ملخص التدقيق',
    },
    'noScoreNote': {
      'en': 'No score — this is a factual checklist, not a prediction.',
      'ur': 'کوئی اسکور نہیں — یہ حقائق پر مبنی چیک لسٹ ہے، پیشگوئی نہیں۔',
      'ar': 'لا توجد نتيجة — هذه قائمة تحقق واقعية وليست توقعًا.',
    },
    'pass': {'en': 'Pass', 'ur': 'پاس', 'ar': 'ناجح'},
    'warn': {'en': 'Warning', 'ur': 'تنبیہ', 'ar': 'تحذير'},
    'fail': {'en': 'Fail', 'ur': 'ناکام', 'ar': 'فشل'},
    'checklistTitle': {
      'en': 'Checklist',
      'ur': 'چیک لسٹ',
      'ar': 'قائمة التحقق',
    },
    'fixLabel': {'en': 'Fix', 'ur': 'اصلاح', 'ar': 'إصلاح'},
    'suggestionsTitle': {
      'en': 'Fix suggestions',
      'ur': 'اصلاح کی تجاویز',
      'ar': 'اقتراحات الإصلاح',
    },
    'titlesLabel': {
      'en': 'Better titles (≤60 chars)',
      'ur': 'بہتر عنوان (≤60 حروف)',
      'ar': 'عناوين أفضل (≤60 حرفًا)',
    },
    'descsLabel': {
      'en': 'Better descriptions (≤160 chars)',
      'ur': 'بہتر تفصیل (≤160 حروف)',
      'ar': 'أوصاف أفضل (≤160 حرفًا)',
    },
    'copy': {'en': 'Copy', 'ur': 'کاپی', 'ar': 'نسخ'},
    'copied': {'en': 'Copied', 'ur': 'کاپی ہو گیا', 'ar': 'تم النسخ'},
    'chars': {'en': 'chars', 'ur': 'حروف', 'ar': 'حرف'},
    'sourceAi': {
      'en': 'Written by AI',
      'ur': 'AI نے لکھا ہے',
      'ar': 'كتبه الذكاء الاصطناعي',
    },
    'sourceHeuristic': {
      'en': 'Heuristic suggestions (AI unavailable)',
      'ur': 'ہیورسٹک تجاویز (AI دستیاب نہیں)',
      'ar': 'اقتراحات إرشادية (الذكاء الاصطناعي غير متاح)',
    },
    'check_page_title': {
      'en': 'Page title',
      'ur': 'صفحے کا عنوان',
      'ar': 'عنوان الصفحة',
    },
    'check_meta_description': {
      'en': 'Meta description',
      'ur': 'میٹا تفصیل',
      'ar': 'الوصف التعريفي',
    },
    'check_og_tags': {
      'en': 'OpenGraph tags',
      'ur': 'اوپن گراف ٹیگز',
      'ar': 'وسوم OpenGraph',
    },
    'check_og_image': {
      'en': 'Share image (og:image)',
      'ur': 'شیئر امیج (og:image)',
      'ar': 'صورة المشاركة (og:image)',
    },
    'check_twitter_card': {
      'en': 'Twitter card',
      'ur': 'ٹوئٹر کارڈ',
      'ar': 'بطاقة تويتر',
    },
    'check_canonical': {
      'en': 'Canonical URL',
      'ur': 'کینونیکل URL',
      'ar': 'الرابط الأساسي',
    },
  };

  String get(String key) => _t[key]?[code] ?? _t[key]?['en'] ?? key;

  String summary(int p, int w, int f) {
    switch (code) {
      case 'ur':
        return '$p پاس، $w تنبیہ، $f ناکام';
      case 'ar':
        return '$p ناجح، $w تحذير، $f فشل';
      default:
        return '$p pass, $w warn, $f fail';
    }
  }
}

// ---------------------------------------------------------------------------
// Minimal API call for this feature only. ApiClient itself is owned by the
// coordinator (not edited here); the global apiClient's public baseUrl and
// tokenProvider give us the same auth headers.
class _CtrApi {
  static Future<Map<String, dynamic>> ctrAudit(String url) async {
    final token = apiClient.tokenProvider?.call();
    final res = await http.post(
      Uri.parse('${apiClient.baseUrl}/api/v1/content/ctr-audit'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'url': url}),
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

// ---------------------------------------------------------------------------

class _CtrAuditScreenState extends State<CtrAuditScreen> {
  late final TextEditingController _ctrl;
  bool _working = false;
  Map<String, dynamic>? _result;

  _CtrStrings get s => _CtrStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valid {
    final v = _ctrl.text.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  Future<void> _audit() async {
    if (!_valid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.get('invalidUrl'))));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _result = null;
    });
    try {
      final result = await _CtrApi.ctrAudit(_ctrl.text.trim());
      if (!mounted) return;
      setState(() {
        _working = false;
        _result = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.get('auditFailed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.get('title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(s.get('title'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(s.get('subtitle'),
              style: TextStyle(color: VTheme.textSec(context), fontSize: 13)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: VTheme.card(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: VirelloColors.cardShadow,
            ),
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _audit(),
              decoration: InputDecoration(
                hintText: s.get('urlHint'),
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                prefixIcon: const Icon(Icons.link, color: VirelloColors.pink),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          VGradientButton(
            label: s.get('auditButton'),
            icon: Icons.fact_check_outlined,
            onPressed: (_working || !_valid) ? null : _audit,
          ),
          const SizedBox(height: 24),
          if (_working)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            )),
          if (_result != null) ..._buildResult(context, _result!),
        ],
      ),
    );
  }

  List<Widget> _buildResult(BuildContext context, Map<String, dynamic> d) {
    final summary = Map<String, dynamic>.from(d['summary'] as Map? ?? {});
    final checks = ((d['checks'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final sug = Map<String, dynamic>.from(d['suggestions'] as Map? ?? {});
    return [
      _buildSummaryCard(context, summary),
      const SizedBox(height: 20),
      VSectionHeader(title: s.get('checklistTitle')),
      const SizedBox(height: 8),
      ...checks.map((c) => _buildCheckRow(context, c)),
      const SizedBox(height: 20),
      VSectionHeader(title: s.get('suggestionsTitle')),
      const SizedBox(height: 4),
      _buildSourceBadge(context, sug['source'] as String? ?? 'heuristic'),
      const SizedBox(height: 8),
      Text(s.get('titlesLabel'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      ...((sug['titles'] as List?) ?? []).map((e) =>
          _buildSuggestionCard(context, Map<String, dynamic>.from(e as Map))),
      const SizedBox(height: 12),
      Text(s.get('descsLabel'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      ...((sug['descriptions'] as List?) ?? []).map((e) =>
          _buildSuggestionCard(context, Map<String, dynamic>.from(e as Map))),
    ];
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> summary) {
    final p = (summary['pass'] as num? ?? 0).toInt();
    final w = (summary['warn'] as num? ?? 0).toInt();
    final f = (summary['fail'] as num? ?? 0).toInt();
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.get('summaryTitle'),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryChip(s.get('pass'), p, VirelloColors.success),
              const SizedBox(width: 8),
              _summaryChip(s.get('warn'), w, const Color(0xFFF0A22E)),
              const SizedBox(width: 8),
              _summaryChip(s.get('fail'), f, VirelloColors.danger),
            ],
          ),
          const SizedBox(height: 10),
          Text(s.summary(p, w, f),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(s.get('noScoreNote'),
              style: TextStyle(color: VTheme.textSec(context), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckRow(BuildContext context, Map<String, dynamic> c) {
    final status = c['status'] as String? ?? 'warn';
    final color = status == 'pass'
        ? VirelloColors.success
        : status == 'fail'
            ? VirelloColors.danger
            : const Color(0xFFF0A22E);
    final icon = status == 'pass'
        ? Icons.check_circle
        : status == 'fail'
            ? Icons.cancel
            : Icons.warning_amber_rounded;
    final needsFix = status != 'pass';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.get('check_${c['check']}'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s.get(status),
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${c['detail'] ?? ''}',
                      style: TextStyle(
                          color: VTheme.textSec(context), fontSize: 12.5)),
                  if (needsFix &&
                      (c['fix_hint'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: VirelloColors.pink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.black87),
                          children: [
                            TextSpan(
                              text: '${s.get('fixLabel')}: ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: VirelloColors.pink),
                            ),
                            TextSpan(text: '${c['fix_hint']}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge(BuildContext context, String source) {
    final isAi = source == 'ai';
    return Row(
      children: [
        Icon(isAi ? Icons.auto_awesome : Icons.build_outlined,
            size: 14, color: VTheme.textSec(context)),
        const SizedBox(width: 6),
        Text(
          isAi ? s.get('sourceAi') : s.get('sourceHeuristic'),
          style: TextStyle(color: VTheme.textSec(context), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(BuildContext context, Map<String, dynamic> item) {
    final text = '${item['text'] ?? ''}';
    final length = (item['length'] as num? ?? text.length).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 14, height: 1.45)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('$length ${s.get('chars')}',
                    style: TextStyle(
                        color: VTheme.textSec(context), fontSize: 12)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(s.get('copied'))));
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(s.get('copy')),
                  style:
                      TextButton.styleFrom(foregroundColor: VirelloColors.pink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
