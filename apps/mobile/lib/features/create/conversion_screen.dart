import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 30: "Conversion".
///
/// Board layout: header, format option rows, input field, Convert button.
/// Wires to the REAL POST /api/v1/content/transform endpoint — converts a
/// link or text into native drafts per format. Output is honestly labeled
/// (AI vs heuristic) and never promises reach or virality.
class ConversionScreen extends StatefulWidget {
  const ConversionScreen({super.key});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  final _inputCtrl = TextEditingController();
  int _format = 0; // 0 video script, 1 carousel, 2 thread, 3 story caption
  bool _working = false;
  String? _error;
  Map<String, dynamic>? _result; // full transform response
  bool _dev = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  static const _formatKeys = [
    'video_script',
    'carousel',
    'thread',
    'story_caption',
  ];

  Future<void> _convert() async {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = s.boardEnterTextFirst);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
      _result = null;
    });
    try {
      final token = authStore.accessToken;
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/content/transform'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'text': raw}),
      );
      if (res.statusCode != 200) throw Exception(res.body);
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _dev = data['source'] != 'ai';
        _result = data;
        _working = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = s.askFailed;
        _working = false;
      });
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.boardCopied)));
  }

  /// Renders the user-selected format from the real transform response.
  String _formatText() {
    final result = _result;
    if (result == null) return '';
    final platforms = (result['platforms'] as List?) ?? [];
    if (platforms.isEmpty) return '';
    final fmts = ((platforms.first as Map)['formats'] as Map?)
            ?.cast<String, dynamic>() ??
        {};
    final key = _formatKeys[_format];
    switch (key) {
      case 'video_script':
        final vs =
            (fmts['video_script'] as Map?)?.cast<String, dynamic>() ?? {};
        final beats =
            (vs['beats'] as List?)?.map((b) => '• $b').join('\n') ?? '';
        return '${vs['hook'] ?? ''}\n\n$beats\n\n${vs['cta'] ?? ''}'.trim();
      case 'carousel':
        final slides =
            (fmts['carousel']?['slides'] as List?)?.cast<String>() ?? [];
        return slides
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .join('\n\n');
      case 'thread':
        final posts = (fmts['thread']?['posts'] as List?)?.cast<String>() ?? [];
        return posts
            .asMap()
            .entries
            .map((e) => '${e.key + 1}/${posts.length} ${e.value}')
            .join('\n\n');
      default:
        return '${fmts['story_caption'] ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formats = ['Video Script', 'Carousel', 'Thread', 'Story Caption'];
    final formatIcons = [
      Icons.videocam_outlined,
      Icons.view_carousel_outlined,
      Icons.forum_outlined,
      Icons.auto_stories_outlined,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.boardConversion)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Format option rows (board style list).
          ...List.generate(formats.length, (i) {
            final active = _format == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VBoardCard(
                onTap: () => setState(() => _format = i),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (active
                                ? VirelloColors.pink
                                : VirelloColors.pink.withValues(alpha: 0.14))
                            .withValues(alpha: active ? 1 : 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        formatIcons[i],
                        color: active ? Colors.white : VirelloColors.pink,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        formats[i],
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: VTheme.text(context),
                        ),
                      ),
                    ),
                    if (active)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: VirelloColors.pink,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          // Input field.
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _inputCtrl,
              maxLines: 4,
              minLines: 3,
              style: TextStyle(color: VTheme.text(context)),
              decoration: InputDecoration(
                hintText: s.boardConvertInputHint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _working ? null : _convert,
              style: FilledButton.styleFrom(
                backgroundColor: VirelloColors.pink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _working
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      s.boardConvert,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: VirelloColors.danger, fontSize: 13),
            ),
          ],
          if (_dev && _result != null) ...[
            const SizedBox(height: 12),
            Text(
              s.boardDevHeuristic,
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: VTheme.textSec(context),
              ),
            ),
          ],
          // Draft result (selected format).
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: VBoardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formats[_format],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: VTheme.text(context),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copy(_formatText()),
                          icon: const Icon(
                            Icons.copy_outlined,
                            color: VirelloColors.pink,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatText(),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.7,
                        color: VTheme.text(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
