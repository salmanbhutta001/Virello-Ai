/// Local caption tools — pure Dart, no network, no native deps.
///
/// Turns plain caption/script text into timed caption lines, styles them,
/// and exports SRT. Burn-in onto video is Phase B (ffmpeg).
library;

/// One timed caption line.
class CaptionLine {
  final String text;
  final double start; // seconds
  final double end; // seconds

  const CaptionLine({
    required this.text,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'start': start,
        'end': end,
      };
}

/// Where captions sit on screen (used by Phase B burn-in + preview).
enum CaptionPosition { top, center, bottom }

/// Visual style preset for captions.
class CaptionStyle {
  final CaptionPosition position;
  final double fontSize;
  final int textColor; // 0xAARRGGBB
  final int backgroundColor; // 0xAARRGGBB
  final bool highlightKeywords;

  const CaptionStyle({
    this.position = CaptionPosition.bottom,
    this.fontSize = 22,
    this.textColor = 0xFFFFFFFF,
    this.backgroundColor = 0xCC000000,
    this.highlightKeywords = false,
  });

  Map<String, dynamic> toJson() => {
        'position': position.name,
        'fontSize': fontSize,
        'textColor': textColor,
        'backgroundColor': backgroundColor,
        'highlightKeywords': highlightKeywords,
      };

  static const List<CaptionStyle> presets = [
    CaptionStyle(), // Classic bottom
    CaptionStyle(
      position: CaptionPosition.center,
      fontSize: 30,
      backgroundColor: 0x00000000,
      highlightKeywords: true,
    ), // Bold center
    CaptionStyle(
      position: CaptionPosition.top,
      fontSize: 20,
      textColor: 0xFFFFEB3B,
      backgroundColor: 0xAA000000,
    ), // Top yellow
  ];
}

class CaptionTools {
  CaptionTools._();

  /// Splits [script] into timed lines. Timing is estimated from word count:
  /// each line holds up to [maxWordsPerLine] words and lasts
  /// `words / wordsPerSecond` seconds. [wordsPerSecond] is adjustable
  /// (average speaking pace ~2.5).
  static List<CaptionLine> timedCaptions(
    String script, {
    double wordsPerSecond = 2.5,
    int maxWordsPerLine = 8,
  }) {
    final wps = wordsPerSecond <= 0 ? 2.5 : wordsPerSecond;
    final words = script
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    final lines = <CaptionLine>[];
    double t = 0;
    for (var i = 0; i < words.length; i += maxWordsPerLine) {
      final chunk = words.sublist(
        i,
        (i + maxWordsPerLine).clamp(0, words.length),
      );
      final dur = chunk.length / wps;
      // Small floor so very short lines stay readable.
      final lineDur = dur < 0.8 ? 0.8 : dur;
      lines.add(CaptionLine(
        text: chunk.join(' '),
        start: t,
        end: t + lineDur,
      ));
      t += lineDur;
    }
    return lines;
  }

  /// Total spoken duration estimate in seconds.
  static double estimateDuration(String script, {double wordsPerSecond = 2.5}) {
    final words = script.trim().isEmpty
        ? 0
        : script.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final wps = wordsPerSecond <= 0 ? 2.5 : wordsPerSecond;
    return words / wps;
  }

  /// `1.5` -> `00:00:01,500`
  static String formatSrtTime(double seconds) {
    final totalMs = (seconds * 1000).round();
    final h = totalMs ~/ 3600000;
    final m = (totalMs % 3600000) ~/ 60000;
    final s = (totalMs % 60000) ~/ 1000;
    final ms = totalMs % 1000;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)},${ms.toString().padLeft(3, '0')}';
  }

  /// Exports timed lines as an SRT subtitle file body.
  static String toSrt(List<CaptionLine> lines) {
    final buf = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      buf.writeln('${i + 1}');
      buf.writeln(
          '${formatSrtTime(l.start)} --> ${formatSrtTime(l.end)}');
      buf.writeln(l.text);
      buf.writeln();
    }
    return buf.toString();
  }
}
