import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// AI Entertainment (Phase 6): AI-generated stories and comic ideas.
/// All AI output is labeled; the dev-preview note shows whenever the
/// backend flags its output as development/heuristic.
class EntertainScreen extends StatefulWidget {
  const EntertainScreen({super.key});
  @override
  State<EntertainScreen> createState() => _EntertainScreenState();
}

class _EntertainScreenState extends State<EntertainScreen> {
  // 0 = story, 1 = comic.
  int _mode = 0;
  final _storyCtrl = TextEditingController();
  String _storyLength = 'short';
  final _comicCtrl = TextEditingController();
  int _panels = 4;

  bool _generating = false;
  Map<String, dynamic>? _story;
  bool _storyDev = false;
  Map<String, dynamic>? _comic;
  bool _comicDev = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _storyCtrl.dispose();
    _comicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateStory() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final res = await apiClient.generateStory(
        topic: _storyCtrl.text.trim().isEmpty ? null : _storyCtrl.text.trim(),
        length: _storyLength,
        language: appState.localeCode,
      );
      if (!mounted) return;
      setState(() {
        _story = res['story'] != null
            ? Map<String, dynamic>.from(res['story'] as Map)
            : null;
        _storyDev = res['dev'] == true;
        _generating = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() => _generating = false);
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.askFailed)));
    }
  }

  Future<void> _generateComic() async {
    final topic = _comicCtrl.text.trim();
    if (_generating || topic.isEmpty) return;
    setState(() => _generating = true);
    try {
      final res = await apiClient.generateComicIdea(
        topic: topic,
        panels: _panels,
        language: appState.localeCode,
      );
      if (!mounted) return;
      setState(() {
        _comic = res['comic'] != null
            ? Map<String, dynamic>.from(res['comic'] as Map)
            : null;
        _comicDev = res['dev'] == true;
        _generating = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() => _generating = false);
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.askFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.stories)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.storiesTagline,
                style: TextStyle(color: VTheme.textSec(context), fontSize: 13)),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 0,
                    label: Text(s.storyTab),
                    icon: const Icon(Icons.auto_stories_outlined, size: 18)),
                ButtonSegment(
                    value: 1,
                    label: Text(s.comicTab),
                    icon: const Icon(Icons.grid_view_outlined, size: 18)),
              ],
              selected: {_mode},
              onSelectionChanged: (sel) => setState(() => _mode = sel.first),
            ),
            const SizedBox(height: 16),
            if (_mode == 0) _storyForm(context) else _comicForm(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _storyForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _storyCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: s.storyPromptHint,
            prefixIcon: const Icon(Icons.edit_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ChoiceChip(
              label: Text(s.shortLength),
              selected: _storyLength == 'short',
              onSelected: (_) => setState(() => _storyLength = 'short'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(s.mediumLength),
              selected: _storyLength == 'medium',
              onSelected: (_) => setState(() => _storyLength = 'medium'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _generating ? null : _generateStory,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(s.generateStory),
        ),
        const SizedBox(height: 16),
        if (_generating) const _LoadingCard(),
        if (!_generating && _story != null) _storyCard(context),
      ],
    );
  }

  Widget _storyCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories,
                    color: VirelloColors.pink, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${_story!['title'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${_story!['body'] ?? ''}',
                style: const TextStyle(fontSize: 14, height: 1.7)),
            if (_storyDev)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(s.devPreviewNote,
                    style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: VTheme.textSec(context))),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: _generating ? null : _generateStory,
                icon: const Icon(Icons.refresh_outlined, size: 16),
                label: Text(s.regenerate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comicForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _comicCtrl,
          decoration: InputDecoration(
            hintText: s.comicTopicHint,
            prefixIcon: const Icon(Icons.edit_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _generateComic(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(s.panels, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _panels > 2 ? () => setState(() => _panels--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: VTheme.chip(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$_panels',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              onPressed: _panels < 6 ? () => setState(() => _panels++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _generating ? null : _generateComic,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(s.generate),
        ),
        const SizedBox(height: 16),
        if (_generating) const _LoadingCard(),
        if (!_generating && _comic != null) _comicCard(context),
      ],
    );
  }

  Widget _comicCard(BuildContext context) {
    final panels = ((_comic!['panels'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.grid_view, color: VirelloColors.pink, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${_comic!['title'] ?? s.comicIdea}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final p in panels)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: VirelloColors.brandGradient,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text('${p['panel'] ?? ''}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${p['description'] ?? ''}',
                            style:
                                const TextStyle(fontSize: 13.5, height: 1.5)),
                      ),
                    ],
                  ),
                  if ('${p['caption'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: VTheme.chip(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('“${p['caption']}”',
                          style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.5)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (_comicDev)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.devPreviewNote,
                style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: VTheme.textSec(context))),
          ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: VTheme.chip(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
