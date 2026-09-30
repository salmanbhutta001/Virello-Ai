/// Phase B — renders a Phase A [ContentTemplate] into a finished video.
///
/// Fills the template's slots, picks photos (distributed across shots),
/// optional voiceover/music, then [TemplateVideoRenderer] assembles the
/// 9:16 MP4 with timed captions burned in.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/local_tools/template_video_renderer.dart';
import '../../services/local_tools/templates_engine.dart';
import 'video_render_dialogs.dart';

class TemplateRenderScreen extends StatefulWidget {
  final ContentTemplate template;
  const TemplateRenderScreen({super.key, required this.template});

  @override
  State<TemplateRenderScreen> createState() => _TemplateRenderScreenState();
}

class _TemplateRenderScreenState extends State<TemplateRenderScreen> {
  final Map<String, TextEditingController> _slotCtrls = {};
  final TextEditingController _ctaCtrl = TextEditingController();
  final List<String> _images = [];
  String? _music;
  String? _voiceover;
  bool _rendering = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    for (final slot in widget.template.slots) {
      _slotCtrls[slot.id] = TextEditingController();
    }
    _ctaCtrl.text = widget.template.defaultCta;
  }

  @override
  void dispose() {
    for (final c in _slotCtrls.values) {
      c.dispose();
    }
    _ctaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final paths =
        picked.map((f) => f.path).whereType<String>().toList();
    if (paths.isNotEmpty && mounted) {
      setState(() => _images.addAll(paths));
    }
  }

  Future<String?> _pickAudio() async {
    final picked = await FilePicker.pickFile(type: FileType.audio);
    return picked?.path;
  }

  Future<void> _render() async {
    if (_images.isEmpty || _rendering) return;
    setState(() => _rendering = true);
    try {
      final slotValues = {
        for (final e in _slotCtrls.entries) e.key: e.value.text.trim(),
      };
      final project = TemplatesEngine.buildProject(
        template: widget.template,
        slotValues: slotValues,
        assetPaths: List.of(_images),
        cta: _ctaCtrl.text.trim(),
      );
      final chosen = await runVideoTaskDialog(
        context,
        title: s.renderVideo,
        task: (progress) => TemplateVideoRenderer().render(
          RenderRequest(
            project: project,
            voiceoverPath: _voiceover,
            musicPath: _music,
          ),
          onProgress: progress,
        ),
      );
      if (chosen != null && mounted) {
        Navigator.of(context).pop(chosen);
      }
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return Scaffold(
      appBar: AppBar(title: Text(t.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            t.description,
            style: TextStyle(
              fontSize: 13.5,
              color: VTheme.textSec(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '~${t.totalSeconds}s · ${t.slots.length} shots',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: VirelloColors.pink,
            ),
          ),
          const SizedBox(height: 14),
          for (final slot in t.slots) ...[
            TextField(
              controller: _slotCtrls[slot.id],
              maxLines: 2,
              style: TextStyle(color: VTheme.text(context)),
              decoration: InputDecoration(
                labelText: '${slot.label} (~${slot.maxSeconds}s)',
                hintText: slot.hint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                labelStyle: TextStyle(color: VTheme.textSec(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _ctaCtrl,
            style: TextStyle(color: VTheme.text(context)),
            decoration: InputDecoration(
              labelText: 'CTA',
              labelStyle: TextStyle(color: VTheme.textSec(context)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Photos.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_images.length} ${s.photosPicked}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: VTheme.text(context),
                ),
              ),
              TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(s.pickImages),
                style: TextButton.styleFrom(
                  foregroundColor: VirelloColors.pink,
                ),
              ),
            ],
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_images[i]),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _images.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Voiceover + music.
          VBoardCard(
            child: Row(
              children: [
                const Icon(Icons.mic_outlined,
                    color: VirelloColors.pink, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _voiceover == null
                        ? s.toolVoiceover
                        : _voiceover!.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: VTheme.text(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final p = await _pickAudio();
                    if (p != null && mounted) {
                      setState(() => _voiceover = p);
                    }
                  },
                  child: Text(
                    s.pickAudio,
                    style: const TextStyle(
                      color: VirelloColors.pink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          VBoardCard(
            child: Row(
              children: [
                const Icon(Icons.music_note_outlined,
                    color: VirelloColors.pink, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _music == null ? s.toolAddMusic : _music!.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: VTheme.text(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final p = await _pickAudio();
                    if (p != null && mounted) {
                      setState(() => _music = p);
                    }
                  },
                  child: Text(
                    s.pickAudio,
                    style: const TextStyle(
                      color: VirelloColors.pink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_images.isEmpty || _rendering) ? null : _render,
              icon: _rendering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.movie_creation_outlined),
              label: Text(
                s.renderVideo,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VirelloColors.pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
