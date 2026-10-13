import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../services/local_tools/image_tools.dart';

/// Local image tools — crop, rotate/flip, filters, fine adjustments,
/// text overlay, watermark, and a 9:16 Reels frame. Pure on-device
/// (package:image): no network, no account, no setup.
///
/// Flow: pick an image -> edit -> save. Discrete tools apply immediately;
/// sliders preview live and are committed before the next discrete op
/// or save.
class ImageToolsScreen extends StatefulWidget {
  const ImageToolsScreen({super.key});

  @override
  State<ImageToolsScreen> createState() => _ImageToolsScreenState();
}

class _ImageToolsScreenState extends State<ImageToolsScreen> {
  img.Image? _committed;
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  bool _busy = false;

  AppStrings get s => AppStrings(appState.localeCode);

  img.Image? get _preview {
    final base = _committed;
    if (base == null) return null;
    return ImageTools.adjust(
      base,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pick() async {
    final picked = await FilePicker.pickFile(type: FileType.image);
    final path = picked?.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = ImageTools.decode(bytes);
      if (decoded == null) {
        _snack(s.noImagePicked);
        return;
      }
      setState(() {
        _committed = decoded;
        _brightness = 0;
        _contrast = 0;
        _saturation = 0;
      });
    } catch (_) {
      _snack(s.noImagePicked);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Folds live slider values into [_committed] and resets sliders.
  void _commitSliders() {
    final base = _committed;
    if (base == null) return;
    _committed = ImageTools.adjust(
      base,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
    );
    _brightness = 0;
    _contrast = 0;
    _saturation = 0;
  }

  void _applyDiscrete(img.Image Function(img.Image) op) {
    if (_committed == null) {
      _snack(s.noImagePicked);
      return;
    }
    setState(() {
      _commitSliders();
      _committed = op(_committed!);
    });
  }

  Future<void> _askText({required bool watermark}) async {
    if (_committed == null) {
      _snack(s.noImagePicked);
      return;
    }
    final ctrl = TextEditingController();
    double size = 28;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(watermark ? s.watermark : s.addText),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(hintText: s.enterText),
              ),
              if (!watermark) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: size,
                        min: 16,
                        max: 64,
                        divisions: 12,
                        label: size.round().toString(),
                        onChanged: (v) => setD(() => size = v),
                      ),
                    ),
                    Text('${size.round()}'),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || text.isEmpty) return;
    _applyDiscrete((im) => watermark
        ? ImageTools.watermark(im, text)
        : ImageTools.textOverlay(im, text: text, fontSize: size.round()));
  }

  /// Hafiz 2026-10-13: download the edited image straight to the phone
  /// gallery (in addition to the existing Save-to-file option).
  Future<void> _downloadToGallery() async {
    final base = _committed;
    if (base == null || _busy) {
      if (base == null) _snack(s.noImagePicked);
      return;
    }
    setState(() => _busy = true);
    try {
      _commitSliders();
      final out =
          ImageTools.encodeJpg(ImageTools.downscaleForUpload(_committed!));
      await Gal.putImageBytes(out, album: 'Virello');
      _snack(s.imageSaved);
    } catch (_) {
      _snack(s.noImagePicked);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final base = _committed;
    if (base == null) {
      _snack(s.noImagePicked);
      return;
    }
    setState(() => _busy = true);
    try {
      _commitSliders();
      final out =
          ImageTools.encodeJpg(ImageTools.downscaleForUpload(_committed!));
      final uri = await FilePicker.saveFile(
        fileName:
            'virello_edit_${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: out,
        mimeType: 'image/jpeg',
        type: FileType.image,
      );
      if (uri != null) {
        _snack(s.imageSaved);
      }
    } catch (_) {
      _snack(s.noImagePicked);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.imageTools),
        actions: [
          if (_committed != null)
            IconButton(
              tooltip: s.boardImageDownload,
              icon: const Icon(Icons.download_outlined),
              onPressed: _busy ? null : _downloadToGallery,
            ),
          if (_committed != null)
            IconButton(
              tooltip: s.saveImage,
              icon: const Icon(Icons.save_outlined),
              onPressed: _busy ? null : _save,
            ),
        ],
      ),
      body: _busy && _committed == null
          ? const Center(child: CircularProgressIndicator())
          : _committed == null
              ? _buildEmpty()
              : _buildEditor(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 72,
              color: VTheme.textSec(context),
            ),
            const SizedBox(height: 16),
            Text(
              s.pickImage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: VTheme.text(context),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(s.pickImage),
                style: FilledButton.styleFrom(
                  backgroundColor: VirelloColors.pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final preview = _preview;
    final bytes =
        preview == null ? null : ImageTools.encodeJpg(preview, quality: 82);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(s.pickImage),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(s.saveImage),
                style: FilledButton.styleFrom(
                  backgroundColor: VirelloColors.pink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _downloadToGallery,
            icon: const Icon(Icons.download_outlined, size: 18),
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
        const SizedBox(height: 16),
        _sectionTitle(s.filters),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ImageFilter.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final f = ImageFilter.values[i];
              return FilterChip(
                label: Text(_filterName(f)),
                selected: false,
                onSelected: (_) => _applyDiscrete(
                  (im) => ImageTools.applyFilter(im, f),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _sliderRow(s.brightness, _brightness, (v) {
          setState(() => _brightness = v);
        }),
        _sliderRow(s.contrast, _contrast, (v) {
          setState(() => _contrast = v);
        }),
        _sliderRow(s.saturation, _saturation, (v) {
          setState(() => _saturation = v);
        }),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _toolChip(
              Icons.crop, s.cropSquare,
              () => _applyDiscrete(ImageTools.cropCenterSquare),
            ),
            _toolChip(
              Icons.rotate_right, s.rotate,
              () => _applyDiscrete((im) => ImageTools.rotate90(im)),
            ),
            _toolChip(
              Icons.flip, s.flipH,
              () => _applyDiscrete(ImageTools.flipHorizontal),
            ),
            _toolChip(
              Icons.text_fields, s.addText,
              () => _askText(watermark: false),
            ),
            _toolChip(
              Icons.branding_watermark_outlined, s.watermark,
              () => _askText(watermark: true),
            ),
            _toolChip(
              Icons.smartphone, s.reelsFrame,
              () => _applyDiscrete(ImageTools.blurBackground916),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: VTheme.textSec(context),
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Row(
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
            min: -0.6,
            max: 0.6,
            divisions: 24,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _toolChip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: VirelloColors.pink),
      label: Text(label),
      onPressed: onTap,
    );
  }

  String _filterName(ImageFilter f) {
    switch (f) {
      case ImageFilter.none:
        return 'Original';
      case ImageFilter.grayscale:
        return 'B&W';
      case ImageFilter.sepia:
        return 'Sepia';
      case ImageFilter.vintage:
        return 'Vintage';
      case ImageFilter.brighten:
        return 'Bright';
      case ImageFilter.highContrast:
        return 'Contrast+';
    }
  }
}
