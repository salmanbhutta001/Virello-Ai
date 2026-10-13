import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';

/// Board screen 28: "Generated Preview".
///
/// Board layout: header "Preview". Shows generated/transformed content when
/// available; otherwise an honest empty state. Never invents a preview.
///
/// Hafiz 2026-10-13: download button added so users can save the preview
/// as a .txt file (share sheet -> Save to Files/Downloads).
class GeneratedPreviewScreen extends StatefulWidget {
  final String? title;
  final String? body;
  const GeneratedPreviewScreen({super.key, this.title, this.body});

  @override
  State<GeneratedPreviewScreen> createState() => _GeneratedPreviewScreenState();
}

class _GeneratedPreviewScreenState extends State<GeneratedPreviewScreen> {
  bool _downloading = false;

  AppStrings get s => AppStrings(appState.localeCode);

  /// Hafiz 2026-10-13: download the preview as a .txt file so users can
  /// save their work (share sheet -> Save to Files/Downloads).
  Future<void> _download() async {
    final body = (widget.body ?? '').trim();
    if (body.isEmpty || _downloading) return;
    setState(() => _downloading = true);
    try {
      final dir = await getTemporaryDirectory();
      final name =
          'virello_preview_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${dir.path}/$name');
      final title = (widget.title ?? '').trim();
      await file.writeAsString(
          '${title.isNotEmpty ? '$title\n\n' : ''}$body\n\nvia Virello');
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain', name: name)],
        text: '${title.isNotEmpty ? '$title\n\n' : ''}via Virello',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.boardImageDownload)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.boardImageSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = (widget.body ?? '').trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.boardPreview),
        actions: [
          if (hasContent)
            IconButton(
              tooltip: s.boardImageDownload,
              onPressed: _downloading ? null : _download,
              icon: _downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: VTheme.chip(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VTheme.divider(context)),
              ),
              child: hasContent
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((widget.title ?? '').isNotEmpty)
                            Text(
                              widget.title!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: VTheme.text(context),
                              ),
                            ),
                          if ((widget.title ?? '').isNotEmpty)
                            const SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                widget.body!,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.7,
                                  color: VTheme.text(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.preview_outlined,
                            size: 56,
                            color:
                                VTheme.textSec(context).withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.boardNoRecommendations,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: VTheme.textSec(context),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (hasContent) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(s.boardImageDownload),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VirelloColors.pink,
                  side: const BorderSide(color: VirelloColors.pink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
