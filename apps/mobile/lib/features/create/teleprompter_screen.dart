import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/local_tools/tts_service.dart';

/// Local teleprompter — auto-scrolling script reader for hands-free
/// recording. 100% on-device: no network, no account, no setup.
///
/// Two modes: edit (write/paste the script) and prompter (big readable
/// text auto-scrolling at an adjustable speed).
///
/// Hafiz 2026-10-04: prompter can also SPEAK the script (TTS), and the
/// narration can be downloaded to the phone + shared.
class TeleprompterScreen extends StatefulWidget {
  final String initialScript;
  const TeleprompterScreen({super.key, this.initialScript = ''});

  @override
  State<TeleprompterScreen> createState() => _TeleprompterScreenState();
}

class _TeleprompterScreenState extends State<TeleprompterScreen> {
  late final TextEditingController _ctrl;
  final ScrollController _scroll = ScrollController();
  final TtsService _tts = TtsService();
  Timer? _timer;
  bool _playing = false;
  bool _prompterMode = false;
  double _speed = 2.0; // 1..6
  // Hafiz 2026-10-04: TTS speak + audio export state.
  bool _speaking = false;
  bool _exporting = false;
  bool _aiWriting = false;
  String? _audioPath;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialScript);
    _tts.init();
    // Hafiz 2026-10-04: reset the Speak button when TTS finishes.
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.setCompletionHandler(null);
    _tts.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _start() {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _prompterMode = true;
      _playing = true;
    });
    _timer?.cancel();
    // Scroll ~110px/sec at speed 1x, scaled by _speed.
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final next = _scroll.offset + _speed * 5.5;
      if (next >= pos.maxScrollExtent) {
        _scroll.jumpTo(pos.maxScrollExtent);
        _stop();
      } else {
        _scroll.jumpTo(next);
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _stopSpeaking();
    if (mounted) setState(() => _playing = false);
  }

  /// Hafiz 2026-10-04: speak the script aloud with the phone's TTS.
  Future<void> _toggleSpeaking() async {
    if (_speaking) {
      await _stopSpeaking();
      return;
    }
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _speaking = true);
    await _tts.speak(text);
    // speak() returns after queuing; poll completion via a simple timer.
    // If the user navigates away, dispose() stops TTS.
  }

  Future<void> _stopSpeaking() async {
    if (!_speaking) return;
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  /// Hafiz 2026-10-04: render narration to audio, save to Downloads.
  Future<void> _downloadAudio() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    final name =
        'virello_teleprompter_${DateTime.now().millisecondsSinceEpoch}.wav';
    final path = await _tts.exportToDownloads(text, name);
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _audioPath = path;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path == null
            ? 'Audio export failed. Please try again.'
            : 'Audio saved to Downloads.'),
      ),
    );
  }

  /// Hafiz 2026-10-04: share the exported audio file.
  Future<void> _shareAudio() async {
    var path = _audioPath;
    if (path == null) {
      // Export on demand, then share.
      await _downloadAudio();
      path = _audioPath;
    }
    if (path == null || !mounted) return;
    final file = File(path);
    if (!await file.exists()) return;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'audio/wav', name: 'virello-teleprompter.wav')],
      text: 'My teleprompter narration — via Virello',
    );
  }

  /// Muse AI writes the prompter script (Hafiz 2026-10-21): the text
  /// in the editor is treated as the topic; the backend's Claude-first
  /// script tool returns hook/body/cta, loaded ready to roll.
  Future<void> _writeWithAi() async {
    final topic = _ctrl.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    if (_aiWriting) return;
    setState(() => _aiWriting = true);
    try {
      final r = await apiClient.createScript(
        topic,
        language: appState.localeCode,
      );
      final scr = (r['script'] as Map?)?.cast<String, dynamic>();
      final beats =
          (scr?['body'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
      final parts = <String>[
        if ((scr?['hook'] ?? '').toString().isNotEmpty)
          scr!['hook'].toString(),
        ...beats,
        if ((scr?['cta'] ?? '').toString().isNotEmpty) scr!['cta'].toString(),
      ];
      if (parts.isEmpty) throw Exception('empty script');
      if (!mounted) return;
      setState(() => _ctrl.text = parts.join('\n'));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.aiWriteFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _aiWriting = false);
    }
  }

  void _toggle() {
    if (_playing) {
      _stop();
    } else {
      _start();
    }
  }

  void _restart() {
    _stop();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.teleprompter),
        actions: [
          if (_prompterMode)
            IconButton(
              tooltip: s.boardImageRegenerate,
              icon: const Icon(Icons.restart_alt_outlined),
              onPressed: _restart,
            ),
        ],
      ),
      body: _prompterMode ? _buildPrompter() : _buildEditor(),
      bottomNavigationBar: _prompterMode ? _buildControls() : _buildStartBar(),
    );
  }

  Widget _buildEditor() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VBoardCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _ctrl,
            // Hafiz 2026-10-04: rebuild on every keystroke so the Play
            // button enables as soon as there is text.
            onChanged: (_) => setState(() {}),
            maxLines: 12,
            minLines: 8,
            style: TextStyle(
              color: VTheme.text(context),
              fontSize: 15,
              height: 1.7,
            ),
            decoration: InputDecoration(
              hintText: s.scriptHint,
              hintStyle: TextStyle(color: VTheme.textSec(context)),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _aiWriting ? null : _writeWithAi,
            icon: _aiWriting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(s.aiWriteScript),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.teleprompterSpeed,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: VTheme.textSec(context),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _speed,
                min: 1,
                max: 6,
                divisions: 10,
                label: '${_speed.toStringAsFixed(1)}x',
                onChanged: (v) => setState(() => _speed = v),
              ),
            ),
            Text(
              '${_speed.toStringAsFixed(1)}x',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: VTheme.text(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrompter() {
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
        child: Text(
          _ctrl.text,
          style:  TextStyle(
            color: VTheme.onBrand(context),
            fontSize: 30,
            height: 1.9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return SafeArea(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hafiz 2026-10-04: speak / download / share the narration.
            // Hafiz 2026-10-13: fixed text wrapping — smaller font, no wrap.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleSpeaking,
                    icon: Icon(
                      _speaking ? Icons.stop : Icons.record_voice_over_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _speaking ? 'Stop voice' : 'Speak',
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: VTheme.textSec(context)
                              .withValues(alpha: 0.24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exporting ? null : _downloadAudio,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined, size: 18),
                    label: const Text(
                      'Audio',
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: VTheme.textSec(context)
                              .withValues(alpha: 0.24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareAudio,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text(
                      'Share',
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: VTheme.textSec(context)
                              .withValues(alpha: 0.24)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _stop();
                      setState(() => _prompterMode = false);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(s.boardWriteScript),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: VTheme.textSec(context)
                              .withValues(alpha: 0.24)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(
                      _playing ? Icons.pause : Icons.play_arrow,
                      size: 20,
                    ),
                    label: Text(_playing ? s.pause : s.play),
                    style: FilledButton.styleFrom(
                      backgroundColor: VirelloColors.pink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _ctrl.text.trim().isEmpty ? null : _start,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text(
              s.play,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: VirelloColors.pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
