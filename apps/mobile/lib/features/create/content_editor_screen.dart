import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../transform/transform_screen.dart';
import 'generated_preview_screen.dart';

/// Board screen 27: "Content Editor".
///
/// Board layout: header "Edit Content" + X close button, media preview with
/// a play button overlay, bottom toolbar: Fonts, Photos, Music, Edit,
/// Effects (icon + label each).
///
/// HONEST wiring: Edit opens the real content transformer. Fonts/Photos/
/// Music/Effects need a media-editing provider — they show an honest
/// "coming soon" state instead of fake editing tools.
class ContentEditorScreen extends StatelessWidget {
  final String? mediaPath; // optional local path passed from upload
  const ContentEditorScreen({super.key, this.mediaPath});

  AppStrings get s => AppStrings(appState.localeCode);

  void _comingSoon(BuildContext context, String tool) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VirelloColors.boardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: VirelloColors.boardBorder),
        ),
        title: Text(
          tool,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          s.boardProviderKeyNeeded,
          style: const TextStyle(color: VirelloColors.boardTextSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: VirelloColors.pink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: VTheme.chip(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VirelloColors.boardBorder),
            ),
            child: Icon(icon, color: VirelloColors.pink, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: VTheme.textSec(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = [
      (Icons.font_download_outlined, 'Fonts'),
      (Icons.photo_library_outlined, 'Photos'),
      (Icons.music_note_outlined, 'Music'),
      (Icons.edit_outlined, 'Edit'),
      (Icons.auto_fix_high_outlined, 'Effects'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(s.boardEditContent),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  color: VTheme.chip(context),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (mediaPath != null)
                        Positioned.fill(
                          child: Icon(
                            Icons.photo_outlined,
                            size: 80,
                            color:
                                VTheme.textSec(context).withValues(alpha: 0.4),
                          ),
                        )
                      else
                        Icon(
                          Icons.photo_outlined,
                          size: 80,
                          color: VTheme.textSec(context).withValues(alpha: 0.4),
                        ),
                      // Play button overlay (board style).
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom toolbar (board: Fonts, Photos, Music, Edit, Effects).
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: VirelloColors.boardSurface,
              border: Border(
                top: BorderSide(color: VirelloColors.boardBorder),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tools.map((t) {
                final label = t.$2;
                return _tool(context, t.$1, label, () {
                  if (label == 'Edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransformScreen(
                          localeCode: appState.localeCode,
                        ),
                      ),
                    );
                  } else if (label == 'Effects') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GeneratedPreviewScreen(),
                      ),
                    );
                  } else {
                    _comingSoon(context, label);
                  }
                });
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
