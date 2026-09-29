import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Phase 3 — Creator Studio: AI content creation (text-first).
/// Tabs: Ideas | Scripts | Captions | Hooks. All output labeled
/// dev/heuristic until a production provider is configured.
class CreatorStudioScreen extends StatefulWidget {
  const CreatorStudioScreen({super.key});

  @override
  State<CreatorStudioScreen> createState() => _CreatorStudioScreenState();
}

class _CreatorStudioScreenState extends State<CreatorStudioScreen>
    with SingleTickerProviderStateMixin {
  AppStrings get s => AppStrings(appState.localeCode);

  late final TabController _tabs;
  final _topicCtrl = TextEditingController();
  String _format = 'video';
  bool _working = false;
  String? _error;

  List<Map> _ideas = [];
  Map<String, dynamic>? _script;
  List<Map> _captions = [];
  List<String> _hooks = [];
  bool _dev = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  String get _topic => _topicCtrl.text.trim();

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.copied)));
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_topic.isEmpty) {
      setState(() => _error = s.enterTextFirst);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await fn();
    } catch (_) {
      if (mounted) setState(() => _error = s.askFailed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _genIdeas() => _run(() async {
        final r = await apiClient.createIdeas(
          _topic,
          language: appState.localeCode,
        );
        setState(() {
          _ideas = ((r['ideas'] as List?) ?? []).cast<Map>().toList();
          _dev = r['dev'] == true;
        });
      });

  Future<void> _genScript() => _run(() async {
        final r = await apiClient.createScript(
          _topic,
          format: _format,
          language: appState.localeCode,
        );
        setState(() {
          _script = (r['script'] as Map?)?.cast<String, dynamic>();
          _dev = r['dev'] == true;
        });
      });

  Future<void> _genCaptions() => _run(() async {
        final r = await apiClient.createCaptions(
          _topic,
          language: appState.localeCode,
        );
        setState(() {
          _captions = ((r['captions'] as List?) ?? []).cast<Map>().toList();
          _dev = r['dev'] == true;
        });
      });

  Future<void> _genHooks() => _run(() async {
        final r = await apiClient.createHooks(
          _topic,
          language: appState.localeCode,
        );
        setState(() {
          _hooks = ((r['hooks'] as List?) ?? []).map((e) => '$e').toList();
          _dev = r['dev'] == true;
        });
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.creatorStudio,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: VirelloColors.pink,
          unselectedLabelColor: VTheme.textSec(context),
          indicatorColor: VirelloColors.pink,
          tabs: [
            Tab(
              text: s.tabIdeas,
              icon: const Icon(Icons.lightbulb_outline, size: 20),
            ),
            Tab(
              text: s.tabScripts,
              icon: const Icon(Icons.movie_outlined, size: 20),
            ),
            Tab(
              text: s.tabCaptions,
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
            ),
            Tab(
              text: s.tabHooks,
              icon: const Icon(Icons.bolt_outlined, size: 20),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _topicBar(context),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ideasTab(context),
                _scriptsTab(context),
                _captionsTab(context),
                _hooksTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _topicCtrl,
        decoration: InputDecoration(
          hintText: s.topicHint,
          prefixIcon: const Icon(Icons.topic_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: VTheme.divider(context)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        onSubmitted: (_) {
          switch (_tabs.index) {
            case 0:
              _genIdeas();
              break;
            case 1:
              _genScript();
              break;
            case 2:
              _genCaptions();
              break;
            case 3:
              _genHooks();
              break;
          }
        },
      ),
    );
  }

  Widget _generateButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _working ? null : onTap,
          icon: _working
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: VirelloColors.pink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _devBadge(BuildContext context) {
    if (!_dev) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        s.devPreviewNote,
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: VTheme.textSec(context),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          s.noResultsYet,
          textAlign: TextAlign.center,
          style: TextStyle(color: VTheme.textSec(context), fontSize: 14),
        ),
      ),
    );
  }

  // ------------------------------ Ideas tab ------------------------------
  Widget _ideasTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _generateButton(s.generateIdeas, _genIdeas),
        _devBadge(context),
        if (_ideas.isEmpty)
          _emptyState(context)
        else
          ..._ideas.map(
            (idea) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: VCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${idea['title']}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: VTheme.chip(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${idea['format'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: VirelloColors.pink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${idea['brief'] ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: VTheme.textSec(context),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            _copy('${idea['title']}\n${idea['brief'] ?? ''}'),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(s.copyText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------ Scripts tab ------------------------------
  Widget _scriptsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'video', label: Text(s.formatVideo)),
              ButtonSegment(value: 'reel', label: Text(s.formatReel)),
              ButtonSegment(value: 'post', label: Text(s.formatPost)),
            ],
            selected: {_format},
            onSelectionChanged: (v) => setState(() => _format = v.first),
          ),
        ),
        _generateButton(s.generateScript, _genScript),
        _devBadge(context),
        if (_script == null)
          _emptyState(context)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: VCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _scriptSection(
                    s.scriptHook,
                    '${_script!['hook'] ?? ''}',
                    Icons.bolt,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _scriptSection(
                    s.scriptBody,
                    ((_script!['body'] as List?) ?? [])
                        .map((b) => '• $b')
                        .join('\n'),
                    Icons.list,
                    VirelloColors.pink,
                  ),
                  const SizedBox(height: 12),
                  _scriptSection(
                    s.scriptCta,
                    '${_script!['cta'] ?? ''}',
                    Icons.rocket_launch_outlined,
                    Colors.green,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _copy(
                        'HOOK: ${_script!['hook']}\n\n${((_script!['body'] as List?) ?? []).map((b) => "• $b").join("\n")}\n\nCTA: ${_script!['cta']}',
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(s.copyText),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _scriptSection(String title, String body, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
      ],
    );
  }

  // ------------------------------ Captions tab ------------------------------
  Widget _captionsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _generateButton(s.generateCaptions, _genCaptions),
        _devBadge(context),
        if (_captions.isEmpty)
          _emptyState(context)
        else
          ..._captions.map((cap) {
            final tags =
                ((cap['hashtags'] as List?) ?? []).map((t) => '$t').join(' ');
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: VCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cap['caption'] ?? ''}',
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          tags,
                          style: const TextStyle(
                            fontSize: 13,
                            color: VirelloColors.pink,
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            _copy('${cap['caption'] ?? ''}\n\n$tags'),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(s.copyText),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ------------------------------ Hooks tab ------------------------------
  Widget _hooksTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _generateButton(s.generateHooks, _genHooks),
        _devBadge(context),
        if (_hooks.isEmpty)
          _emptyState(context)
        else
          ..._hooks.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: VCard(
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: VirelloColors.pink.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: VirelloColors.pink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () => _copy(e.value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}
