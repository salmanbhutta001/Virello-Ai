/// Local image tools — pure Dart via package:image. No native deps, no network.
///
/// Crop, resize, rotate/flip, filters, brightness/contrast/saturation,
/// text overlay, watermark, and a blurred-background 9:16 fit for
/// Reels/Shorts/TikTok. All functions are synchronous and operate on
/// decoded [img.Image] frames; use [decode]/[encodeJpg]/[encodePng] at the
/// edges.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Built-in one-tap filters.
enum ImageFilter {
  none,
  grayscale,
  sepia,
  vintage,
  brighten,
  highContrast,
}

class ImageTools {
  ImageTools._();

  /// Decodes JPEG/PNG/WebP/GIF bytes. Returns null when undecodable.
  static img.Image? decode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List encodeJpg(img.Image image, {int quality = 90}) =>
      img.encodeJpg(image, quality: quality);

  static Uint8List encodePng(img.Image image) => img.encodePng(image);

  /// Center-square crop (safe default for profile/thumbnail use).
  static img.Image cropCenterSquare(img.Image src) {
    final side = src.width < src.height ? src.width : src.height;
    final x = (src.width - side) ~/ 2;
    final y = (src.height - side) ~/ 2;
    return img.copyCrop(src, x: x, y: y, width: side, height: side);
  }

  static img.Image crop(
    img.Image src, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    final cx = x.clamp(0, src.width - 1);
    final cy = y.clamp(0, src.height - 1);
    final cw = width.clamp(1, src.width - cx);
    final ch = height.clamp(1, src.height - cy);
    return img.copyCrop(src, x: cx, y: cy, width: cw, height: ch);
  }

  static img.Image resize(img.Image src, {int? width, int? height}) {
    if (width == null && height == null) return src;
    return img.copyResize(src, width: width, height: height);
  }

  /// Rotates clockwise by 90° [times] (1-3).
  static img.Image rotate90(img.Image src, {int times = 1}) {
    var out = src;
    final n = times % 4;
    for (var i = 0; i < n; i++) {
      out = img.copyRotate(out, angle: 90);
    }
    return out;
  }

  static img.Image flipHorizontal(img.Image src) => img.flipHorizontal(src);

  static img.Image flipVertical(img.Image src) => img.flipVertical(src);

  static img.Image applyFilter(img.Image src, ImageFilter filter) {
    switch (filter) {
      case ImageFilter.none:
        return src;
      case ImageFilter.grayscale:
        return img.grayscale(src);
      case ImageFilter.sepia:
        return img.sepia(src);
      case ImageFilter.vintage:
        return img.adjustColor(
          img.sepia(src),
          brightness: -0.06,
          contrast: 0.12,
          saturation: -0.15,
        );
      case ImageFilter.brighten:
        return img.adjustColor(src, brightness: 0.18);
      case ImageFilter.highContrast:
        return img.adjustColor(src, contrast: 0.35);
    }
  }

  /// Fine adjustments. [brightness]/[contrast]/[saturation] in roughly
  /// -1.0..1.0 (0 = no change).
  static img.Image adjust(
    img.Image src, {
    double brightness = 0,
    double contrast = 0,
    double saturation = 0,
  }) {
    if (brightness == 0 && contrast == 0 && saturation == 0) return src;
    return img.adjustColor(
      src,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );
  }

  static img.BitmapFont _fontFor(int fontSize) {
    if (fontSize <= 16) return img.arial14;
    if (fontSize <= 32) return img.arial24;
    return img.arial48;
  }

  /// Draws [text] at ([x],[y]). Colors are 0-255 ints.
  static img.Image textOverlay(
    img.Image src, {
    required String text,
    int x = 24,
    int y = 24,
    int fontSize = 24,
    int r = 255,
    int g = 255,
    int b = 255,
    int a = 255,
  }) {
    final out = src.clone();
    img.drawString(
      out,
      text,
      font: _fontFor(fontSize),
      x: x.clamp(0, out.width - 1),
      y: y.clamp(0, out.height - 1),
      color: img.ColorRgba8(r, g, b, a),
    );
    return out;
  }

  /// Semi-transparent text watermark at the bottom-right corner.
  static img.Image watermark(img.Image src, String text) {
    final out = src.clone();
    final font = img.arial24;
    // Rough width estimate: arial24 averages ~12px per char.
    final w = (text.length * 12).clamp(0, out.width - 32);
    img.drawString(
      out,
      text,
      font: font,
      x: (out.width - w - 16).clamp(0, out.width - 1),
      y: (out.height - 48).clamp(0, out.height - 1),
      color: img.ColorRgba8(255, 255, 255, 110),
    );
    return out;
  }

  /// 9:16 (1080x1920) frame for Reels/Shorts/TikTok: the source is fitted
  /// centered over a blurred, darkened copy of itself filling the frame.
  static img.Image blurBackground916(img.Image src) {
    const w = 1080;
    const h = 1920;
    // Background: cover the frame, center-crop exactly, then blur.
    img.Image bg = img.copyResize(src, width: w);
    if (bg.height < h) {
      bg = img.copyResize(bg, height: h);
    }
    bg = img.copyCrop(
      bg,
      x: (bg.width - w) ~/ 2,
      y: (bg.height - h) ~/ 2,
      width: w,
      height: h,
    );
    bg = img.gaussianBlur(bg, radius: 24);
    bg = img.adjustColor(bg, brightness: -0.25);
    // Foreground: fit inside the frame preserving aspect ratio.
    img.Image fg = img.copyResize(src, width: w);
    if (fg.height > h) {
      fg = img.copyResize(src, height: h);
    }
    final dstX = (w - fg.width) ~/ 2;
    final dstY = (h - fg.height) ~/ 2;
    return img.compositeImage(bg, fg, dstX: dstX, dstY: dstY);
  }

  /// Downscales so the longest side is at most [maxSide] (upload-friendly).
  static img.Image downscaleForUpload(img.Image src, {int maxSide = 2048}) {
    final longest = src.width > src.height ? src.width : src.height;
    if (longest <= maxSide) return src;
    if (src.width >= src.height) {
      return img.copyResize(src, width: maxSide);
    }
    return img.copyResize(src, height: maxSide);
  }
}
