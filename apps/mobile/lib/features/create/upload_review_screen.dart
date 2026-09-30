import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../ads/campaign_builder_screen.dart';
import '../audience/audience_intelligence_screen.dart';
import '../grow/grow_flow.dart';
import '../../services/api_client.dart';

/// Upload Studio: pick a file from the phone, upload it to Virello,
/// run an AI readiness check on it, then grow it — Analyze, Find
/// Audience, Promote with AI, or Let AI Grow. This is the "Upload
/// Content" destination: an uploaded file becomes the start of the
/// standard Virello flow instead of a pasted link.
class UploadReviewScreen extends StatefulWidget {
  const UploadReviewScreen({super.key});

  @override
  State<UploadReviewScreen> createState() => _UploadReviewScreenState();
}

enum _Phase { idle, uploading, uploaded, checking }

class _UploadReviewScreenState extends State<UploadReviewScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  _Phase _phase = _Phase.idle;
  String? _error;
  Map<String, dynamic>? _meta; // {id, filename, mime, size, kind, url}
  String? _localPath;
  final _captionCtrl = TextEditingController();
  Map<String, dynamic>? _report;

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
        'mp3',
        'wav',
        'm4a',
        'ogg',
        'pdf',
        'doc',
        'docx',
        'txt',
        'csv',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
      ],
    );
    final path = picked?.path;
    if (path == null) return; // user cancelled
    setState(() {
      _phase = _Phase.uploading;
      _localPath = path;
    });
    try {
      final meta = await apiClient.uploadFile(path);
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _phase = _Phase.uploaded;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = 'AuthException';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = e.toString();
      });
    }
  }

  Future<void> _runCheck() async {
    final id = _meta?['id'] as String?;
    if (id == null) return;
    setState(() {
      _phase = _Phase.checking;
      _error = null;
    });
    try {
      final report =
          await apiClient.analyzeUpload(id, _captionCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _report = report;
        _phase = _Phase.uploaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.uploaded;
        _error = e.toString();
      });
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024)
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'audio':
        return Icons.audio_file_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.uploadStudio,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_phase == _Phase.idle && _meta == null) _emptyState(context),
          if (_phase == _Phase.uploading) _uploadingState(),
          if (_meta != null) ...[
            _previewCard(context),
            const SizedBox(height: 16),
            _captionField(),
            const SizedBox(height: 12),
            _checkButton(),
            if (_report != null) ...[
              const SizedBox(height: 16),
              _reportCard(context),
            ],
            const SizedBox(height: 20),
            _growSection(context),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorCard(),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: VirelloColors.brandGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: VirelloColors.pink.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child:  Icon(
            Icons.cloud_upload_outlined,
            color: VTheme.onBrand(context),
            size: 48,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          s.pickFromPhone,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          s.pickFileHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: VTheme.textSec(context), height: 1.5),
        ),
        const SizedBox(height: 24),
        VGradientButton(
          label: s.pickFromPhone,
          icon: Icons.folder_open,
          onPressed: _pickAndUpload,
        ),
      ],
    );
  }

  Widget _uploadingState() {
    return const Column(
      children: [
        SizedBox(height: 64),
        CircularProgressIndicator(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _previewCard(BuildContext context) {
    final meta = _meta!;
    final kind = meta['kind'] as String? ?? 'document';
    final name = meta['filename'] as String? ?? '';
    final size = (meta['size'] as num?)?.toInt() ?? 0;
    final isImage = kind == 'image' && _localPath != null;
    return VCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: isImage
                ? Image.file(
                    File(_localPath!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _kindTile(kind),
                  )
                : _kindTile(kind),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${kind.toUpperCase()} • ${_sizeLabel(size)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: VTheme.textSec(context),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      s.uploadedOk,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: VTheme.textSec(context)),
            tooltip: s.pickFromPhone,
            onPressed: _pickAndUpload,
          ),
        ],
      ),
    );
  }

  Widget _kindTile(String kind) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: VirelloColors.pink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(_kindIcon(kind), color: VirelloColors.pink, size: 34),
    );
  }

  Widget _captionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.addCaption,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _captionCtrl,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: s.captionHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _checkButton() {
    final busy = _phase == _Phase.checking;
    return SizedBox(
      width: double.infinity,
      child: VGradientButton(
        label: busy ? s.checking : s.aiCheck,
        icon: Icons.auto_awesome,
        onPressed: busy ? null : _runCheck,
      ),
    );
  }

  Widget _reportCard(BuildContext context) {
    final r = _report!;
    final score = (r['score'] as num?)?.toInt() ?? 0;
    final verdict = r['verdict'] as String? ?? '';
    final checks = (r['checks'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final recs =
        (r['recommendations'] as List? ?? []).map((e) => '$e').toList();
    final scoreColor = score >= 75
        ? Colors.green
        : score >= 50
            ? Colors.orange
            : Colors.red;
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 7,
                      color: scoreColor,
                      backgroundColor: scoreColor.withValues(alpha: 0.15),
                    ),
                    Text(
                      '$score',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdict,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.heuristicNote,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: VTheme.textSec(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            s.readinessChecklist,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...checks.map((c) {
            final ok = c['ok'];
            final icon = ok == true
                ? Icons.check_circle
                : ok == false
                    ? Icons.cancel
                    : Icons.info;
            final color = ok == true
                ? Colors.green
                : ok == false
                    ? Colors.red
                    : Colors.orange;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['label']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        Text(
                          '${c['detail']}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: VTheme.textSec(context),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (recs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              s.recommendations,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...recs.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ',
                          style: TextStyle(color: VirelloColors.pink)),
                      Expanded(
                        child: Text(t,
                            style: const TextStyle(fontSize: 13, height: 1.45)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _growSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.growThisContent,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 10),
        _growRow(
          context,
          icon: Icons.track_changes,
          color: const Color(0xFFF59E0B),
          title: s.findAudience,
          desc: s.findAudienceDesc,
          onTap: () {
            final q = _captionCtrl.text.trim();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AudienceIntelligenceScreen(
                    initialQuery: q.isEmpty ? null : q),
              ),
            );
          },
        ),
        _growRow(
          context,
          icon: Icons.rocket_launch_outlined,
          color: VirelloColors.pink,
          title: s.promoteWithAI,
          desc: s.promoteWithAIDesc,
          onTap: () {
            final caption = _captionCtrl.text.trim();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CampaignBuilderScreen(
                  initialContent: caption.isEmpty ? null : caption,
                  initialMediaPath: _localPath,
                ),
              ),
            );
          },
        ),
        _growRow(
          context,
          icon: Icons.smart_toy_outlined,
          color: const Color(0xFF22B8CF),
          title: s.letAiGrowContent,
          desc: s.letAiGrowContentDesc,
          onTap: () {
            final caption = _captionCtrl.text.trim();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    GrowFlow(initialInput: caption.isEmpty ? null : caption),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _growRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12.5, color: VTheme.textSec(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: VTheme.textSec(context)),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    final isAuth = _error == 'AuthException';
    return VCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAuth ? s.uploadFailed : '${s.uploadFailed}: $_error',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: _pickAndUpload,
            child: Text(s.tryAgain),
          ),
        ],
      ),
    );
  }
}
