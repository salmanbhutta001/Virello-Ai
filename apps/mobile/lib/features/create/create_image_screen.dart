import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/ai_image_service.dart';
import '../../core/config.dart';

/// Board screen 22: "Create Image" — fully functional AI image generation.
///
/// Hafiz 2026-10-04: Agnes AI is the ONLY provider (via backend proxy).
/// Pollinations.ai was removed entirely.
///
/// HONEST: every generated image is labeled "AI-generated" in the UI.
class CreateImageScreen extends StatefulWidget {
  const CreateImageScreen({super.key});

  @override
  State<CreateImageScreen> createState() => _CreateImageScreenState();
}

class _CreateImageScreenState extends State<CreateImageScreen> {
  final _promptCtrl = TextEditingController();
  int _style = 0; // 0 realistic, 1 cartoon, 2 3d
  String? _imageUrl;
  int _seed = 0;
  bool _loading = false;
  Timer? _genTimer;
  bool _loadFailed = false;
  // Hafiz 2026-10-04: the actual failure reason, shown to the user.
  String? _failMessage;
  bool _sharing = false;
  // Hafiz 2026-10-03: image download to gallery.
  bool _downloading = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _genTimer?.cancel();
    _promptCtrl.dispose();
    super.dispose();
  }

  /// Hafiz 2026-10-04: Agnes AI is the ONLY provider. No Pollinations
  /// fallback. Failures throw AgnesException with a user-facing message.
  Future<void> _generate() async {
    if (_loading) return; // guard against double-tap (audit 2026-10-03)
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    final seed = Random().nextInt(999999);
    final styleName = ['realistic', 'cartoon', '3d'][_style];
    setState(() {
      _seed = seed;
      _imageUrl = null;
      _loading = true;
      _loadFailed = false;
      _failMessage = null;
    });
    _armTimeout();

    try {
      final agnesUrl = await AiImageService.instance.generateViaAgnes(
        prompt: prompt,
        style: styleName,
        seed: seed,
      );
      if (!mounted) return;
      _genTimer?.cancel();
      setState(() {
        _imageUrl = agnesUrl;
        // Keep _loading true until Image.network finishes loading.
      });
    } on AgnesException catch (e) {
      if (!mounted) return;
      _genTimer?.cancel();
      setState(() {
        _loading = false;
        _loadFailed = true;
        _failMessage = e.message;
      });
    }
  }

  /// Safety net: image generation can stall on slow networks — never spin
  /// forever. After 2 minutes without a loaded image, show retry.
  void _armTimeout() {
    _genTimer?.cancel();
    _genTimer = Timer(const Duration(seconds: 150), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    });
  }

  Future<void> _regenerate() async {
    if (_loading) return; // guard against double-tap (audit 2026-10-03)
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    final seed = Random().nextInt(999999);
    final styleName = ['realistic', 'cartoon', '3d'][_style];
    setState(() {
      _seed = seed;
      _imageUrl = null;
      _loading = true;
      _loadFailed = false;
      _failMessage = null;
    });
    _armTimeout();

    try {
      final agnesUrl = await AiImageService.instance.generateViaAgnes(
        prompt: prompt,
        style: styleName,
        seed: seed,
      );
      if (!mounted) return;
      _genTimer?.cancel();
      setState(() => _imageUrl = agnesUrl);
    } on AgnesException catch (e) {
      if (!mounted) return;
      _genTimer?.cancel();
      setState(() {
        _loading = false;
        _loadFailed = true;
        _failMessage = e.message;
      });
    }
  }

  Future<void> _share() async {
    if (_imageUrl == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final res = await http.get(Uri.parse(_imageUrl!));
      if (res.statusCode == 200 && mounted) {
        await Share.shareXFiles(
          [XFile.fromData(res.bodyBytes, name: 'virello-ai-image.jpg', mimeType: 'image/jpeg')],
          text: '${_promptCtrl.text.trim()}\n\nvia Virello',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.boardImageShareFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.boardImageShareFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Hafiz 2026-10-03: download the generated image to the phone gallery.
  Future<void> _downloadImage() async {
    if (_imageUrl == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final res = await http
          .get(Uri.parse(_imageUrl!))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await Gal.putImageBytes(res.bodyBytes, album: 'Virello');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.boardImageSavedToGallery)),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.boardImageSaveFailed)),
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
    final styles = [s.boardStyleRealistic, s.boardStyleCartoon, s.boardStyle3d];
    return Scaffold(
      appBar: AppBar(title: Text(s.boardCreateImage)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Prompt hint (board shows suggestion text at top).
          Text(
            s.boardImagePromptHint,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: VTheme.textSec(context),
            ),
          ),
          const SizedBox(height: 12),
          // Prompt field.
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _promptCtrl,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(color: VTheme.text(context)),
              decoration: InputDecoration(
                hintText: s.boardImagePromptHint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Style tabs (board: Realistic pink pill / Cartoon / 3D).
          VPillTabs(
            tabs: styles,
            selected: _style,
            onTap: (i) => setState(() => _style = i),
          ),
          const SizedBox(height: 16),
          // Preview area.
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: VTheme.chip(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VTheme.divider(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildPreview(),
            ),
          ),
          // Action row after generation.
          // Hafiz 2026-10-03: added Download button.
          // Hafiz 2026-10-03: compact buttons — single-line labels, no wrap.
          if (_imageUrl != null && !_loading && !_loadFailed) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _regenerate,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(s.boardImageRegenerate,
                          maxLines: 1, style: const TextStyle(fontSize: 13)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloading ? null : _downloadImage,
                    icon: _downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 16),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(s.boardImageDownload,
                          maxLines: 1, style: const TextStyle(fontSize: 13)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share, size: 16),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(s.boardImageShare,
                          maxLines: 1, style: const TextStyle(fontSize: 13)),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Pink circular generate button (board style).
          Center(
            child: VPinkCircleButton(onPressed: _generate),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    // Loading state — Hafiz 2026-10-03: also covers Agnes generation where
    // _imageUrl is still null (backend is generating).
    if (_loading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_imageUrl != null)
            Image.network(AppConfig.resolveImageUrl(_imageUrl!),
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) {
                  // Image fully loaded behind the spinner; flip state.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _loading) {
                      _genTimer?.cancel();
                      setState(() => _loading = false);
                    }
                  });
                  return child;
                }
                return _loadingPlaceholder(progress.expectedTotalBytes != null &&
                        progress.cumulativeBytesLoaded > 0
                    ? progress.cumulativeBytesLoaded /
                        (progress.expectedTotalBytes ?? 1)
                    : null);
              },
              errorBuilder: (ctx, err, stack) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _loading) {
                    setState(() {
                      _loading = false;
                      _loadFailed = true;
                      // Hafiz 2026-10-04: show the actual load error.
                      _failMessage =
                          'The image could not be loaded. Please try again.';
                    });
                  }
                });
                return const SizedBox.shrink();
              },
            ),
          if (_loading) _loadingOverlay(),
        ],
      );
    }
    // Generated image.
    if (_imageUrl != null && !_loadFailed) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(AppConfig.resolveImageUrl(_imageUrl!),
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() {
                  _loadFailed = true;
                  _failMessage =
                      'The image could not be loaded. Please try again.';
                });
              });
              return const SizedBox.shrink();
            },
          ),
          // Honest "AI-generated" badge.
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s.boardImageAiLabel,
                style:  TextStyle(
                  color: VTheme.onBrand(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }
    // Failed state.
    if (_loadFailed) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: VirelloColors.pink,
            ),
            const SizedBox(height: 12),
            Text(
              // Hafiz 2026-10-04: show the actual failure reason.
              _failMessage ?? s.boardImageFailed,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: VTheme.textSec(context),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _regenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(s.boardImageRetry),
            ),
          ],
        ),
      );
    }
    // Empty state.
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 64,
        color: VTheme.textSec(context).withValues(alpha: 0.5),
      ),
    );
  }

  Widget _loadingPlaceholder(double? progress) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              color: VirelloColors.pink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.boardImageGenerating,
            style: TextStyle(
              fontSize: 13.5,
              color: VTheme.textSec(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: VTheme.chip(context).withValues(alpha: 0.85),
      child: _loadingPlaceholder(null),
    );
  }
}
