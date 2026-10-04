import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/local_tools/tts_service.dart';

/// Local voiceover studio — turns typed text into speech using the phone's
/// own TTS engine. Works offline: no network, no account, no setup.
///
/// Pick a voice (Urdu preferred when available), tune speed/pitch, preview,
/// and export the narration as an audio file for use in videos.
class VoiceoverScreen extends StatefulWidget {
  final String initialText;
  const VoiceoverScreen({super.key, this.initialText = ''});

  @override
  State<VoiceoverScreen> createState() => _VoiceoverScreenState();
}

class _VoiceoverScreenState extends State<VoiceoverScreen> {
  final TtsService _tts = TtsService();
  late final TextEditingController _ctrl;
  List<TtsVoice> _voices = [];
  TtsVoice? _voice;
  double _rate = 0.5;
  double _pitch = 1.0;
  bool _loadingVoices = true;
  bool _speaking = false;
  bool _exporting = false;
  String? _status;
  // Hafiz 2026-10-04: exported file path for sharing.
  String? _exportedPath;
  bool _sharing = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _boot();
  }

  Future<void> _boot() async {
    await _tts.init();
    final voices = await _tts.voices();
    final best = await _tts.pickVoice(from: voices);
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _voice = best;
      _loadingVoices = false;
      if (voices.isEmpty) _status = s.ttsUnavailable;
    });
    if (best != null) await _tts.useVoice(best);
  }

  @override
  void dispose() {
    _tts.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _speaking = true;
      _status = null;
    });
    await _tts.speak(text);
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _stop() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  /// Hafiz 2026-10-04: export saves the audio into the phone's
  /// Downloads folder (not just app cache), then offers Share.
  Future<void> _export() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _exporting) return;
    setState(() {
      _exporting = true;
      _status = null;
    });
    final fileName =
        'virello_voiceover_${DateTime.now().millisecondsSinceEpoch}.wav';
    final path = await _tts.exportToDownloads(text, fileName);
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _exportedPath = path;
      _status = path == null
          ? 'Audio export failed. Please try again.'
          : 'Audio saved to Downloads.';
    });
  }

  /// Hafiz 2026-10-04: share the exported audio via the system sheet.
  Future<void> _share() async {
    if (_sharing) return;
    var path = _exportedPath;
    if (path == null) {
      // Export on demand, then share.
      await _export();
      path = _exportedPath;
    }
    if (path == null || !mounted) return;
    final file = File(path);
    if (!await file.exists()) {
      setState(() => _status = 'Audio file not found. Please export again.');
      return;
    }
    setState(() => _sharing = true);
    try {
      await Share.shareXFiles(
        [XFile(path, mimeType: 'audio/wav', name: 'virello-voiceover.wav')],
        text: 'My voiceover — via Virello',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.voiceover)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _ctrl,
              maxLines: 6,
              minLines: 4,
              style: TextStyle(
                color: VTheme.text(context),
                fontSize: 15,
                height: 1.7,
              ),
              decoration: InputDecoration(
                hintText: s.voiceoverTextHint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label(s.voice),
          const SizedBox(height: 8),
          _loadingVoices
              ? const LinearProgressIndicator()
              : VBoardCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TtsVoice>(
                      value: _voice,
                      isExpanded: true,
                      hint: Text(s.ttsUnavailable),
                      items: _voices
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                '${v.name} (${v.locale})',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: VTheme.text(context), fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _voice = v);
                        await _tts.useVoice(v);
                      },
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          _sliderRow(s.teleprompterSpeed, _rate, 0.1, 1.0, (v) async {
            setState(() => _rate = v);
            await _tts.setRate(v);
          }),
          _sliderRow(s.pitch, _pitch, 0.5, 2.0, (v) async {
            setState(() => _pitch = v);
            await _tts.setPitch(v);
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _speaking ? _stop : _speak,
                  icon: Icon(
                    _speaking ? Icons.stop : Icons.play_arrow,
                    size: 20,
                  ),
                  label: Text(_speaking ? s.stop : s.speak),
                  style: FilledButton.styleFrom(
                    backgroundColor: VirelloColors.pink,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: Text(s.exportAudio),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Hafiz 2026-10-04: share the exported audio.
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_sharing || _ctrl.text.trim().isEmpty) ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share audio'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            VBoardCard(
              child: Text(
                _status!,
                style: TextStyle(
                  fontSize: 13,
                  color: VTheme.textSec(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) {
    return Text(
      t,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: VTheme.textSec(context),
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: VTheme.textSec(context)),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: VTheme.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
