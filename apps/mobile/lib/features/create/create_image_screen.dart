import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
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
/// Uses the free Pollinations.ai image API (no key required) as the default
/// provider. The provider is abstracted in [_buildImageUrl] so a keyed
/// provider (OpenAI, Stability, etc.) can be swapped in later via config.
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
  // Hafiz 2026-10-03: track network errors separately for a clear message.
  bool _networkError = false;
  bool _sharing = false;

  AppStrings get s => AppStrings(appState.localeCode);

  static const _styleSuffix = [
    'photorealistic, ultra-detailed, professional photography, sharp focus',
    'vibrant cartoon illustration, bold outlines, flat colors, playful',
    '3d render, pixar style, soft volumetric lighting, high detail',
  ];

  /// Builds the AI image URL via [AiImageService].
  /// Free provider (Pollinations.ai) by default, no key needed.
  /// A keyed provider (OpenAI, Stability) can be configured in one place.
  String _buildImageUrl(String prompt, int style, int seed) {
    return AiImageService.instance.buildImageUrl(
      prompt,
      _styleSuffix[style],
      seed,
    );
  }

  @override
  void dispose() {
    _genTimer?.cancel();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    setState(() {
      _seed = Random().nextInt(999999);
      _imageUrl = _buildImageUrl(prompt, _style, _seed);
      _loading = true;
      _loadFailed = false;
      _networkError = false;
    });
    _armTimeout();
  }

  /// Hafiz 2026-10-03: detects network-level failures (DNS, connection)
  /// so the UI can show "check your internet" instead of a generic error.
  bool _isNetworkError(Object err) {
    final msg = err.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection refused') ||
        msg.contains('connection timed out') ||
        msg.contains('clientexception');
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

  void _regenerate() {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _seed = Random().nextInt(999999);
      _imageUrl = _buildImageUrl(prompt, _style, _seed);
      _loading = true;
      _loadFailed = false;
      _networkError = false;
    });
    _armTimeout();
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
          if (_imageUrl != null && !_loading && !_loadFailed) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _regenerate,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(s.boardImageRegenerate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share, size: 18),
                    label: Text(s.boardImageShare),
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
    // Loading state.
    if (_loading && _imageUrl != null) {
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
                      // Hafiz 2026-10-03: network errors get a specific message.
                      _networkError = _isNetworkError(err);
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
                  _networkError = _isNetworkError(err);
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
              // Hafiz 2026-10-03: network errors get a specific message.
              _networkError ? s.boardImageNetworkFailed : s.boardImageFailed,
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
