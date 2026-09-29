import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';

/// Board screen 26: "Upload Content".
///
/// Board layout: header "Upload", tabs Data / Comments (pink active pill).
/// Data tab: pick a photo/video from the phone, caption, Analyze & Improve.
/// Comments tab: the AI readiness report (real analysis output).
///
/// Everything is REAL: file_picker → POST /api/v1/uploads → analyzeUpload.
/// Never fakes an upload or a report.
class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key});

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  int _tab = 0;
  bool _uploading = false;
  bool _analyzing = false;
  String? _error;
  Map<String, dynamic>? _meta; // {id, filename, mime, size, kind, url}
  String? _localPath;
  final _captionCtrl = TextEditingController();
  Map<String, dynamic>? _report;
  bool _suggesting = false;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _error = null;
      _report = null;
      _meta = null;
    });
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'mp4',
        'mov',
        'webm',
        '3gp',
        'mkv',
      ],
    );
    final path = picked?.path;
    if (path == null) return;
    setState(() {
      _uploading = true;
      _localPath = path;
    });
    try {
      final meta = await apiClient.uploadFile(path);
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _uploading = false;
      });
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
      setState(() => _uploading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = s.askFailed;
      });
    }
  }

  Future<void> _analyze() async {
    final id = _meta?['id']?.toString();
    if (id == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final report =
          await apiClient.analyzeUpload(id, _captionCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _report = report;
        _analyzing = false;
        _tab = 1; // jump to Comments tab with the report
      });
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
      setState(() => _analyzing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = s.askFailed;
      });
    }
  }

  /// AI intelligence: suggests 3 punchy captions for the uploaded content.
  Future<void> _suggestCaptions() async {
    final hint = _captionCtrl.text.trim();
    final filename = _meta?['filename']?.toString() ?? 'my post';
    final topic = hint.isEmpty ? filename : hint;
    setState(() {
      _suggesting = true;
      _suggestions = [];
    });
    try {
      final langNote = appState.localeCode == 'ur'
          ? 'Write them in Roman Urdu.'
          : appState.localeCode == 'ar'
              ? 'Write them in Arabic.'
              : 'Write them in English.';
      final prompt =
          'Suggest 3 short punchy social media captions for a post about: $topic. '
          '$langNote Each caption on its own line. No numbering, no hashtags, no quotes.';
      final url =
          'https://text.pollinations.ai/${Uri.encodeComponent(prompt)}?model=openai&private=true';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final lines = res.body
            .split('\n')
            .map((l) => l.trim().replaceAll(RegExp(r'^[\d]+[.)]\s*'), ''))
            .where((l) => l.isNotEmpty)
            .take(3)
            .toList();
        setState(() {
          _suggestions = lines;
          _suggesting = false;
        });
      } else {
        setState(() => _suggesting = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.boardUploadTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: VPillTabs(
              tabs: [s.boardTabData, s.boardTabComments],
              selected: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: _tab == 0 ? _dataTab() : _commentsTab(),
          ),
        ],
      ),
    );
  }

  Widget _dataTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // Upload area (board style).
        GestureDetector(
          onTap: _uploading ? null : _pickAndUpload,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: VTheme.chip(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VirelloColors.boardBorder),
            ),
            child: _uploading
                ? const Center(child: CircularProgressIndicator())
                : _localPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _isImage(_localPath!)
                            ? Image.file(
                                File(_localPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.videocam_outlined,
                                      size: 48,
                                      color: VirelloColors.pink,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _meta?['filename']?.toString() ?? '',
                                      style: TextStyle(
                                        color: VTheme.textSec(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: VirelloColors.pink,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.boardTapToSelect,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: VTheme.textSec(context),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        if (_meta != null) ...[
          const SizedBox(height: 12),
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _captionCtrl,
              style: TextStyle(color: VTheme.text(context)),
              decoration: InputDecoration(
                hintText: s.boardCaptionTopicHint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // AI caption suggestions.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _suggesting ? null : _suggestCaptions,
              icon: _suggesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: VirelloColors.pink,
                    ),
              label: Text(
                s.boardSuggestCaptions,
                style: const TextStyle(
                  color: VirelloColors.pink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            ..._suggestions.map(
              (cap) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _captionCtrl.text = cap),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: VirelloColors.pink.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            VirelloColors.pink.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      cap,
                      style: TextStyle(
                        fontSize: 13,
                        color: VTheme.text(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _analyzing ? null : _analyze,
              style: FilledButton.styleFrom(
                backgroundColor: VirelloColors.pink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _analyzing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      s.boardAnalyzeUpload,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: VirelloColors.danger, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _commentsTab() {
    final report = _report;
    if (report == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            s.boardNoRecommendations,
            textAlign: TextAlign.center,
            style: TextStyle(color: VTheme.textSec(context)),
          ),
        ),
      );
    }
    final comments = (report['comments'] as List?) ?? [];
    final summary = '${report['summary'] ?? ''}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (summary.isNotEmpty)
          VBoardCard(
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: VTheme.text(context),
              ),
            ),
          ),
        if (summary.isNotEmpty) const SizedBox(height: 12),
        ...comments.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VBoardCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: VirelloColors.pink.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      color: VirelloColors.pink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$c',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: VTheme.text(context),
                      ),
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

  bool _isImage(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif');
  }
}
