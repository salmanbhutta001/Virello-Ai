import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import 'transform_strings.dart';

/// Link → Native Content Transformer (free organic growth strategy #1).
///
/// Paste a link or raw text, pick a platform tab, and get four native
/// content drafts: Video Script, Carousel, Thread, Story Caption. Every
/// card has a Copy button. Output is honestly labeled (AI vs heuristic
/// drafts) and never promises reach or virality.
class TransformScreen extends StatefulWidget {
  final String localeCode; // 'en' | 'ur' | 'ar'
  const TransformScreen({super.key, this.localeCode = 'en'});

  @override
  State<TransformScreen> createState() => _TransformScreenState();
}

const _platformKeys = ['instagram', 'tiktok', 'youtube', 'facebook', 'x'];

class _TransformScreenState extends State<TransformScreen> {
  final _input = TextEditingController();
  int _mode = 0; // 0 = link, 1 = text
  int _platformIdx = 0;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  String t(String key) => trTransform(widget.localeCode, key);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _transform() async {
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = t('emptyInput'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        if (_mode == 0) 'url': raw else 'text': raw,
      };
      final token = authStore.accessToken;
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/content/transform'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode != 200) throw Exception(res.body);
      if (!mounted) return;
      setState(() {
        _result = jsonDecode(res.body) as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = t('error');
        _loading = false;
      });
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(t('copied')), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('subtitle'), style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            VPillTabs(
              tabs: [t('modeUrl'), t('modeText')],
              selected: _mode,
              onTap: (i) => setState(() => _mode = i),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _mode == 0 ? t('hintUrl') : t('hintText'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            VPillTabs(
              tabs: _platformKeys.map((k) => t(k)).toList(),
              selected: _platformIdx,
              onTap: (i) => setState(() => _platformIdx = i),
            ),
            const SizedBox(height: 12),
            VGradientButton(
              label: _loading ? '…' : t('transform'),
              onPressed: _loading ? null : _transform,
              icon: Icons.auto_awesome,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _sourceBadge(),
              const SizedBox(height: 12),
              ..._formatCards(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sourceBadge() {
    final isAi = _result!['source'] == 'ai';
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAi ? t('sourceAi') : t('sourceHeuristic'),
              style: const TextStyle(
                color: VirelloColors.pink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(t('draftsNote'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  List<Widget> _formatCards() {
    final platforms = (_result!['platforms'] as List).cast<Map>();
    final key = _platformKeys[_platformIdx];
    final entry = platforms.firstWhere(
      (p) => p['platform'] == key,
      orElse: () => platforms.first,
    );
    final fmts = (entry['formats'] as Map).cast<String, dynamic>();
    final vs = (fmts['video_script'] as Map).cast<String, dynamic>();
    final slides = (fmts['carousel']['slides'] as List).cast<String>();
    final posts = (fmts['thread']['posts'] as List).cast<String>();
    final story = fmts['story_caption'] as String;

    final videoText = '${t('hook')}: ${vs['hook']}\n\n'
        '${t('beats')}:\n${(vs['beats'] as List).map((b) => '• $b').join('\n')}\n\n'
        '${t('cta')}: ${vs['cta']}';
    final carouselText = slides
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n\n');
    final threadText = posts
        .asMap()
        .entries
        .map((e) => '${e.key + 1}/${posts.length} ${e.value}')
        .join('\n\n');

    return [
      _formatCard(t('videoScript'), videoText, Icons.movie),
      _formatCard(t('carousel'), carouselText, Icons.view_carousel),
      _formatCard(t('thread'), threadText, Icons.forum),
      _formatCard(t('storyCaption'), story, Icons.auto_stories),
    ];
  }

  Widget _formatCard(String title, String body, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: VirelloColors.pink, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () => _copy(body),
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(t('copy')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(body),
          ],
        ),
      ),
    );
  }
}
