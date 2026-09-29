import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Tutorial / Guide screen: plays the in-app Virello walkthrough video
/// (English narration) with built-in subtitles in 44 languages, chapter jumps,
/// play/pause/seek controls, replay, and resume-from-last-position.
class TutorialGuideScreen extends StatefulWidget {
  const TutorialGuideScreen({super.key});

  @override
  State<TutorialGuideScreen> createState() => _TutorialGuideScreenState();
}

class _Chapter {
  final String titleKey;
  final double startSec;
  const _Chapter(this.titleKey, this.startSec);
}

const _chapters = <_Chapter>[
  _Chapter('tutChWelcome', 0.0),
  _Chapter('tutChHome', 11.33),
  _Chapter('tutChDiscover', 21.0),
  _Chapter('tutChCreate', 31.0),
  _Chapter('tutChAnalyze', 40.05),
  _Chapter('tutChAudience', 53.8),
  _Chapter('tutChSetup', 64.0),
  _Chapter('tutChAgent', 76.0),
  _Chapter('tutChCampaigns', 85.36),
  _Chapter('tutChProfile', 94.16),
  _Chapter('tutChThanks', 100.99),
];

const _prefsKey = 'tutorial_last_position_sec';
const _subLangKey = 'tutorial_subtitle_lang';

class _TutorialGuideScreenState extends State<TutorialGuideScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _showResume = false;
  double _resumeAt = 0;

  // Built-in 44-language subtitles (assets/tutorial_subtitles.json)
  Map<String, dynamic>? _subLangs;
  List<dynamic> _subChapters = const [];
  List<String> _subLangCodes = const [];
  String _subLang = 'en';

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.asset('assets/video/virello_tutorial.mp4');
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getDouble(_prefsKey) ?? 0;
      final dur = _controller.value.duration.inSeconds.toDouble();
      if (last > 3 && last < dur - 5) {
        _resumeAt = last;
        _showResume = true;
      }
      await _loadSubtitles(prefs);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
    _controller.addListener(_persist);
  }

  Future<void> _loadSubtitles(SharedPreferences prefs) async {
    try {
      final raw = await rootBundle.loadString('assets/tutorial_subtitles.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final langs = decoded['languages'] as Map<String, dynamic>;
      final codes = langs.keys.toList()..sort();
      var def = appState.localeCode;
      if (!langs.containsKey(def)) def = 'en';
      final saved = prefs.getString(_subLangKey);
      _subChapters = decoded['chapters'] as List<dynamic>;
      _subLangCodes = List<String>.from(codes);
      _subLangs = langs;
      _subLang = (saved != null && langs.containsKey(saved)) ? saved : def;
    } catch (_) {
      // Subtitles stay unavailable; video still plays.
    }
  }

  void _persist() {
    if (!_controller.value.isInitialized) return;
    final pos = _controller.value.position.inSeconds.toDouble();
    final dur = _controller.value.duration.inSeconds.toDouble();
    if (pos > 3 && pos < dur - 5) {
      SharedPreferences.getInstance().then((p) => p.setDouble(_prefsKey, pos));
    } else if (pos >= dur - 5 && dur > 0) {
      SharedPreferences.getInstance().then((p) => p.remove(_prefsKey));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_persist);
    _controller.dispose();
    super.dispose();
  }

  String _fmt(double sec) {
    final s = sec.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _seek(double sec) {
    _controller.seekTo(Duration(milliseconds: (sec * 1000).round()));
    if (!_controller.value.isPlaying) _controller.play();
  }

  /// Current subtitle line for the selected language, synced to playback.
  Widget _subtitleBar() {
    final pos = _controller.value.position.inSeconds.toDouble();
    String? line;
    final lines = (_subLangs![_subLang]['lines'] as List<dynamic>);
    for (var i = 0; i < _subChapters.length; i++) {
      final ch = _subChapters[i] as Map<String, dynamic>;
      final start = (ch['start'] as num).toDouble();
      final end = (ch['end'] as num).toDouble();
      if (pos >= start && pos < end) {
        if (i < lines.length) line = lines[i] as String;
        break;
      }
    }
    if (line == null || line.isEmpty) return const SizedBox.shrink();
    final rtl = _subLangs![_subLang]['rtl'] as bool;
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          line,
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(appState.localeCode);
    return Scaffold(
      appBar: AppBar(title: Text(strings.tutorialTitle)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _controller.value.hasError
              ? Center(child: Text(strings.tutorialLoadError))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Subtitle language picker (44 built-in languages)
                    if (_subLangCodes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.subtitles_rounded,
                                size: 18, color: VirelloColors.pink),
                            const SizedBox(width: 8),
                            Text(strings.tutorialSubtitles,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            DropdownButton<String>(
                              value: _subLang,
                              underline: const SizedBox.shrink(),
                              items: [
                                for (final c in _subLangCodes)
                                  DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                        _subLangs![c]['name_native'] as String),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _subLang = v);
                                SharedPreferences.getInstance()
                                    .then((p) => p.setString(_subLangKey, v));
                              },
                            ),
                          ],
                        ),
                      ),
                    // Video player
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_controller),
                            _ControlsOverlay(controller: _controller),
                            if (_subLangs != null)
                              Positioned(
                                left: 10,
                                right: 10,
                                bottom: 36,
                                child: AnimatedBuilder(
                                  animation: _controller,
                                  builder: (_, __) => _subtitleBar(),
                                ),
                              ),
                            VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: VirelloColors.pink,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Transport row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: strings.tutorialReplay,
                          icon: const Icon(Icons.replay_rounded),
                          onPressed: () => _seek(0),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          }),
                          icon: Icon(_controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                          label: Text(_controller.value.isPlaying
                              ? strings.pause
                              : strings.play),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: strings.tutorialRestartChapter,
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: () {
                            final pos =
                                _controller.value.position.inSeconds.toDouble();
                            final ch = _chapters.lastWhere(
                              (c) => c.startSec <= pos + 0.5,
                              orElse: () => _chapters.first,
                            );
                            _seek(ch.startSec);
                          },
                        ),
                      ],
                    ),
                    if (_showResume) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => _showResume = false);
                            _seek(_resumeAt);
                          },
                          icon: const Icon(Icons.history_rounded),
                          label: Text(strings.tutorialResume(_fmt(_resumeAt))),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    VSectionHeader(title: strings.tutorialChapters),
                    const SizedBox(height: 8),
                    VCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < _chapters.length; i++)
                            _chapterRow(
                              context,
                              index: i,
                              chapter: _chapters[i],
                              next: i + 1 < _chapters.length
                                  ? _chapters[i + 1]
                                  : null,
                              total: _controller.value.duration.inSeconds
                                  .toDouble(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.tutorialNote,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _chapterRow(
    BuildContext context, {
    required int index,
    required _Chapter chapter,
    required _Chapter? next,
    required double total,
  }) {
    final strings = AppStrings(appState.localeCode);
    final title = _chapterTitle(strings, chapter.titleKey);
    final end = next?.startSec ?? total;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: VirelloColors.pink.withValues(alpha: 0.15),
        child: Text('${index + 1}',
            style: const TextStyle(
                color: VirelloColors.pink, fontWeight: FontWeight.bold)),
      ),
      title: Text(title),
      subtitle: Text('${_fmt(chapter.startSec)} – ${_fmt(end)}'),
      trailing: const Icon(Icons.play_circle_outline_rounded,
          color: VirelloColors.pink),
      onTap: () => _seek(chapter.startSec),
    );
  }

  String _chapterTitle(AppStrings s, String key) {
    switch (key) {
      case 'tutChWelcome':
        return s.tutChWelcome;
      case 'tutChHome':
        return s.tutChHome;
      case 'tutChDiscover':
        return s.tutChDiscover;
      case 'tutChCreate':
        return s.tutChCreate;
      case 'tutChAnalyze':
        return s.tutChAnalyze;
      case 'tutChAudience':
        return s.tutChAudience;
      case 'tutChSetup':
        return s.tutChSetup;
      case 'tutChAgent':
        return s.tutChAgent;
      case 'tutChCampaigns':
        return s.tutChCampaigns;
      case 'tutChProfile':
        return s.tutChProfile;
      default:
        return s.tutChThanks;
    }
  }
}

/// Play/pause overlay shown on tap.
class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _ControlsOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          controller.value.isPlaying ? controller.pause() : controller.play(),
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Container(
          color: Colors.transparent,
          child: Center(
            child: AnimatedOpacity(
              opacity: controller.value.isPlaying ? 0.0 : 0.9,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 48, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
