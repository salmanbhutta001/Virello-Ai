/// Phase B — on-device video engine built on the maintained
/// `ffmpeg_kit_flutter_new_video` fork (FFmpeg 8.1.2, LGPL `video` variant).
///
/// Architecture:
/// * [FfmpegCommands] — pure-Dart command builders. No device needed;
///   fully unit-tested in test/ffmpeg_command_test.dart.
/// * [FfmpegService] — async execution with progress, cancellation,
///   timeouts and typed errors. Serializes to one render at a time.
///
/// Video is encoded H.264 via the Android hardware encoder
/// (`h264_mediacodec`, LGPL-safe — NOT the GPL x264), audio as native AAC.
/// There is no software fallback: if the hardware encoder is missing the
/// operation fails with a typed [FfmpegErrorKind.unsupported] error instead
/// of silently producing a non-H.264 file.
library;

import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'caption_tools.dart';

/// Typed failure for every ffmpeg operation. The UI must surface
/// [message] honestly — never a fake success.
enum FfmpegErrorKind {
  busy,
  invalidInput,
  fileNotFound,
  executionFailed,
  cancelled,
  timeout,
  unsupported,
}

class FfmpegException implements Exception {
  final FfmpegErrorKind kind;
  final String message;
  const FfmpegException(this.kind, this.message);
  @override
  String toString() => 'FfmpegException($kind): $message';
}

/// Pure-Dart ffmpeg command builders. Every method returns the exact
/// command string handed to FFmpegKit — testable without a device.
class FfmpegCommands {
  FfmpegCommands._();

  /// Quote a path for FFmpegKit's command parser (single-quote grouping).
  static String q(String path) {
    if (path.contains("'")) {
      return "'${path.replaceAll("'", "'\\''")}'";
    }
    return "'$path'";
  }

  /// Escape a file path for use *inside* a filter argument
  /// (e.g. `subtitles=`): escapes \ ' : [ ] , ;
  static String escapeFilterPath(String path) {
    return path
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll(':', '\\:')
        .replaceAll('[', '\\[')
        .replaceAll(']', '\\]')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
  }

  static String _f(double v) {
    // Trim trailing zeros: 2.50 -> 2.5 ; 3.0 -> 3
    var s = v.toStringAsFixed(3);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s.isEmpty ? '0' : s;
  }

  /// H.264 video codec args via the Android hardware encoder.
  /// Throws [FfmpegException.unsupported] when [hwH264] is false — there is
  /// deliberately no mpeg4 software fallback, so a missing hardware encoder
  /// surfaces honestly instead of producing a non-H.264 file.
  /// Bitrate scales with [height].
  static String videoCodec({required bool hwH264, int? height}) {
    if (!hwH264) {
      throw const FfmpegException(FfmpegErrorKind.unsupported,
          'H.264 hardware encoding is not available on this device.');
    }
    final bitrate = height == null
        ? '4M'
        : height >= 1080
            ? '6M'
            : height >= 720
                ? '3M'
                : '1.5M';
    return '-c:v h264_mediacodec -b:v $bitrate';
  }

  static const String audioCodec = '-c:a aac -b:a 128k';
  static const String faststart = '-movflags +faststart';

  static String trim({
    required String input,
    required double startSec,
    required double endSec,
    required String output,
    required bool hwH264,
  }) {
    final dur = (endSec - startSec).clamp(0.1, 86400.0);
    return '-ss ${_f(startSec)} -i ${q(input)} -t ${_f(dur)} '
        '${videoCodec(hwH264: hwH264)} $audioCodec $faststart ${q(output)}';
  }

  /// Body of a concat-demuxer list file (one `file '…'` per line).
  static String concatListBody(List<String> files) {
    return files.map((f) => "file ${q(f)}").join('\n');
  }

  static String concat({
    required String listFile,
    required String output,
    required bool hwH264,
  }) {
    return "-f concat -safe 0 -i ${q(listFile)} "
        '${videoCodec(hwH264: hwH264)} $audioCodec $faststart ${q(output)}';
  }

  static String compress({
    required String input,
    required int height,
    required String output,
    required bool hwH264,
  }) {
    return '-i ${q(input)} -vf "scale=-2:$height" '
        '${videoCodec(hwH264: hwH264, height: height)} $audioCodec $faststart ${q(output)}';
  }

  static String extractAudio({
    required String input,
    required String output,
  }) {
    return '-i ${q(input)} -vn $audioCodec ${q(output)}';
  }

  static String thumbnail({
    required String input,
    required double atSec,
    required String output,
  }) {
    return '-ss ${_f(atSec)} -i ${q(input)} -frames:v 1 -q:v 2 ${q(output)}';
  }

  static String gifPreview({
    required String input,
    required double startSec,
    required double durationSec,
    required String output,
  }) {
    return '-ss ${_f(startSec)} -t ${_f(durationSec)} -i ${q(input)} '
        '-vf "fps=10,scale=320:-1:flags=lanczos,split[s0][s1];'
        '[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" ${q(output)}';
  }

  static String changeSpeed({
    required String input,
    required double factor,
    required String output,
    required bool hwH264,
  }) {
    final f = factor.clamp(0.5, 4.0);
    return '-i ${q(input)} -vf "setpts=${_f(1 / f)}*PTS" -af "${_atempoChain(f)}" '
        '${videoCodec(hwH264: hwH264)} $audioCodec $faststart ${q(output)}';
  }

  /// Chains `atempo` filters so any factor in 0.5–4.0 is valid:
  /// a single atempo only supports 0.5–2.0 (e.g. 4x -> atempo=2.0,atempo=2.0).
  static String _atempoChain(double factor) {
    final parts = <String>[];
    var f = factor;
    while (f > 2.0) {
      parts.add('atempo=${_f(2.0)}');
      f /= 2.0;
    }
    while (f < 0.5) {
      parts.add('atempo=${_f(0.5)}');
      f /= 0.5;
    }
    parts.add('atempo=${_f(f)}');
    return parts.join(',');
  }

  /// Scale + center-crop into an exact WxH frame (9:16, 1:1, 16:9 …).
  static String toAspect({
    required String input,
    required int width,
    required int height,
    required String output,
    required bool hwH264,
  }) {
    return '-i ${q(input)} -vf '
        '"scale=$width:$height:force_original_aspect_ratio=increase,'
        'crop=$width:$height,setsar=1,format=yuv420p" '
        '${videoCodec(hwH264: hwH264, height: height)} $audioCodec $faststart ${q(output)}';
  }

  static String rotate({
    required String input,
    required int quarterTurnsClockwise,
    required String output,
    required bool hwH264,
  }) {
    final turns = ((quarterTurnsClockwise % 4) + 4) % 4;
    final vf = turns == 1
        ? 'transpose=1'
        : turns == 2
            ? 'transpose=1,transpose=1'
            : turns == 3
                ? 'transpose=2'
                : 'null';
    return '-i ${q(input)} -vf "$vf" '
        '${videoCodec(hwH264: hwH264)} $audioCodec $faststart ${q(output)}';
  }

  /// ASS color for libass `force_style`: 0xAARRGGBB -> &HAABBGGRR.
  static String assColor(int argb) {
    final a = ((argb >> 24) & 0xFF).toRadixString(16).padLeft(2, '0');
    final r = ((argb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((argb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = (argb & 0xFF).toRadixString(16).padLeft(2, '0');
    return '&H$a$b$g$r'.toUpperCase();
  }

  static int _assAlignment(CaptionPosition p) => switch (p) {
        CaptionPosition.top => 8,
        CaptionPosition.center => 5,
        CaptionPosition.bottom => 2,
      };

  static String burnSubtitles({
    required String input,
    required String srtPath,
    required CaptionStyle style,
    required String output,
    required bool hwH264,
  }) {
    final forceStyle = 'FontSize=${style.fontSize.round()},'
        'PrimaryColour=${assColor(style.textColor)},'
        'OutlineColour=${assColor(0xFF000000)},'
        'BackColour=${assColor(style.backgroundColor)},'
        'BorderStyle=1,Outline=2,Shadow=0,'
        'Alignment=${_assAlignment(style.position)}';
    return '-i ${q(input)} -vf '
        '"subtitles=${escapeFilterPath(srtPath)}:force_style=\'$forceStyle\'" '
        '${videoCodec(hwH264: hwH264)} -c:a copy $faststart ${q(output)}';
  }

  /// Body of a concat-demuxer slideshow list. Each image shows for
  /// [durationsSec[i]]; the last file is repeated (demuxer quirk).
  static String slideshowListBody(
      List<String> images, List<double> durationsSec) {
    final buf = StringBuffer();
    for (var i = 0; i < images.length; i++) {
      buf.writeln("file ${q(images[i])}");
      buf.writeln('duration ${_f(durationsSec[i])}');
    }
    buf.writeln("file ${q(images.last)}");
    return buf.toString();
  }

  static String slideshow({
    required String listFile,
    required String output,
    required bool hwH264,
    String? audioPath,
    int width = 1080,
    int height = 1920,
  }) {
    final audioIn = audioPath == null ? '' : '-i ${q(audioPath)} ';
    final audioMap = audioPath == null ? '-an' : '$audioCodec -shortest';
    return '-f concat -safe 0 -i ${q(listFile)} $audioIn'
        '-vf "scale=$width:$height:force_original_aspect_ratio=increase,'
        'crop=$width:$height,setsar=1,fps=30,format=yuv420p" '
        '${videoCodec(hwH264: hwH264, height: height)} $audioMap $faststart ${q(output)}';
  }

  /// Builds the input/filter/map args for mixing voiceover and/or background
  /// music onto [video]. Input 0 is always the video; voice (if any) is the
  /// next input, music the one after. Returns the full command.
  static String mixAudio({
    required String video,
    String? voicePath,
    String? musicPath,
    double musicVolume = 0.25,
    required bool baseHasAudio,
    required String output,
    required bool hwH264,
  }) {
    final inputs = <String>['-i ${q(video)}'];
    var voiceIdx = -1;
    var musicIdx = -1;
    if (voicePath != null) {
      voiceIdx = inputs.length;
      inputs.add('-i ${q(voicePath)}');
    }
    if (musicPath != null) {
      musicIdx = inputs.length;
      inputs.add('-i ${q(musicPath)}');
    }
    final inArgs = inputs.join(' ');

    String? filter;
    String maps;
    var shortest = false;

    if (voiceIdx >= 0 && musicIdx >= 0) {
      // voice + music (+ optional base audio, ducked under voice)
      if (baseHasAudio) {
        filter = '[0:a]volume=0.25[bg];'
            '[bg][$voiceIdx:a]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[m1];'
            '[$musicIdx:a]volume=${_f(musicVolume)},apad[m2];'
            '[m1][m2]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[aout]';
      } else {
        filter = '[$musicIdx:a]volume=${_f(musicVolume)},apad[m2];'
            '[$voiceIdx:a][m2]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[aout]';
      }
      maps = '-map 0:v -map "[aout]"';
    } else if (voiceIdx >= 0) {
      if (baseHasAudio) {
        filter = '[0:a]volume=0.25[bg];'
            '[bg][$voiceIdx:a]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[aout]';
        maps = '-map 0:v -map "[aout]"';
      } else {
        maps = '-map 0:v -map $voiceIdx:a';
      }
      shortest = true;
    } else if (musicIdx >= 0) {
      if (baseHasAudio) {
        filter = '[$musicIdx:a]volume=${_f(musicVolume)}[m];'
            '[0:a][m]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[aout]';
        maps = '-map 0:v -map "[aout]"';
      } else {
        maps = '-map 0:v -map $musicIdx:a';
      }
      shortest = true;
    } else {
      throw const FfmpegException(
          FfmpegErrorKind.invalidInput, 'Nothing to mix: no voice or music.');
    }

    final filterArg = filter == null ? '' : '-filter_complex "$filter" ';
    final shortestArg = shortest ? '-shortest ' : '';
    return '$inArgs $filterArg$maps '
        '${videoCodec(hwH264: hwH264)} $audioCodec $shortestArg$faststart ${q(output)}';
  }

  /// Encoder listing probe (valid FFmpeg command, run via FFmpegKit).
  static const String probeEncoders = '-hide_banner -encoders';
}

/// On-device video engine. One render at a time; every method returns the
/// output file path or throws [FfmpegException] — never a silent failure.
class FfmpegService {
  static final FfmpegService instance = FfmpegService._();
  FfmpegService._();

  bool _busy = false;
  bool? _hwH264;
  bool? _healthCheckCache;

  /// True when the Android hardware H.264 encoder is available (probed once).
  Future<bool> get supportsHwH264 async {
    if (_hwH264 != null) return _hwH264!;
    try {
      final out = await _probeRaw(FfmpegCommands.probeEncoders);
      _hwH264 = out.contains('h264_mediacodec');
    } catch (_) {
      _hwH264 = false;
    }
    return _hwH264!;
  }

  /// Health check: verifies the FFmpeg native library loads and responds.
  ///
  /// Runs a trivial `-version` command with a 5-second timeout. Returns
  /// true when FFmpeg executes successfully, false on any failure
  /// (library load failure, timeout, native crash).
  ///
  /// The result is cached for the app session — call [resetHealthCheck]
  /// to force a re-probe (useful in tests or after an app update).
  ///
  /// This is fast (<5s) and safe to call lazily; never call it during
  /// app startup — only when a video operation is about to run.
  Future<bool> isAvailable() async {
    if (_healthCheckCache != null) return _healthCheckCache!;
    try {
      final session =
          await FFmpegKit.execute('-version').timeout(const Duration(seconds: 5));
      final rc = await session.getReturnCode();
      _healthCheckCache = ReturnCode.isSuccess(rc);
    } catch (_) {
      _healthCheckCache = false;
    }
    return _healthCheckCache!;
  }

  /// Clears the cached [isAvailable] (and hardware-encoder probe) results
  /// so the next call re-probes the device. Intended for tests and
  /// diagnostics; not needed in normal app flow.
  Future<void> resetHealthCheck() async {
    _healthCheckCache = null;
    _hwH264 = null;
  }

  Future<Directory> _workDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/virello_ffmpeg');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _outPath(String name) async {
    final dir = await _workDir();
    final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$safe';
  }

  Future<String> _listFile(String body, String name) async {
    final dir = await _workDir();
    final f = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name.txt');
    await f.writeAsString(body);
    return f.path;
  }

  Future<void> _needFile(String path) async {
    if (!await File(path).exists()) {
      throw FfmpegException(
          FfmpegErrorKind.fileNotFound, 'File not found: $path');
    }
  }

  Future<String> _probeRaw(String command) async {
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw FfmpegException(
          FfmpegErrorKind.executionFailed, 'Probe failed: $command');
    }
    return (await session.getOutput()) ?? '';
  }

  /// Media duration in seconds, or null when unknown.
  /// Uses the package's FFprobeKit API (not FFmpegKit with ffprobe flags).
  Future<double?> probeDurationSec(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final raw = session.getMediaInformation()?.getDuration();
      return raw == null ? null : double.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasAudioStream(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final streams = session.getMediaInformation()?.getStreams() ?? [];
      return streams.any((s) => s.getType() == 'audio');
    } catch (_) {
      return false;
    }
  }

  /// Runs [command]; reports 0..1 progress when [totalSeconds] is known.
  /// Throws [FfmpegException] on failure, cancellation or timeout.
  Future<void> _run(
    String command, {
    double? totalSeconds,
    void Function(double progress)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    if (_busy) {
      throw const FfmpegException(
          FfmpegErrorKind.busy, 'Another video task is already running.');
    }
    _busy = true;
    try {
      final done = Completer<dynamic>();
      await FFmpegKit.executeAsync(
        command,
        (session) {
          if (!done.isCompleted) done.complete(session);
        },
        null,
        (stats) {
          final cb = onProgress;
          final total = totalSeconds;
          if (cb != null && total != null && total > 0) {
            try {
              final ms = stats.getTime();
              cb(((ms / 1000) / total).clamp(0.0, 1.0));
            } catch (_) {}
          }
        },
      );
      dynamic session;
      try {
        session = await done.future.timeout(timeout);
      } on TimeoutException {
        try {
          await FFmpegKit.cancel();
        } catch (_) {}
        throw const FfmpegException(
            FfmpegErrorKind.timeout, 'Video processing timed out.');
      }
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        onProgress?.call(1.0);
        return;
      }
      if (ReturnCode.isCancel(rc)) {
        throw const FfmpegException(
            FfmpegErrorKind.cancelled, 'Video processing was cancelled.');
      }
      var detail = '';
      try {
        final out = await session.getOutput() ?? '';
        detail = out.length > 400 ? out.substring(out.length - 400) : out;
      } catch (_) {}
      throw FfmpegException(FfmpegErrorKind.executionFailed,
          'Video processing failed. $detail'.trim());
    } finally {
      _busy = false;
    }
  }

  /// Cancels the in-flight render, if any.
  Future<void> cancel() async {
    try {
      await FFmpegKit.cancel();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- ops

  Future<String> trim({
    required String input,
    required double startSec,
    required double endSec,
    void Function(double)? onProgress,
  }) async {
    await _needFile(input);
    if (endSec <= startSec) {
      throw const FfmpegException(
          FfmpegErrorKind.invalidInput, 'End time must be after start time.');
    }
    final hw = await supportsHwH264;
    final out = await _outPath('trim.mp4');
    await _run(
      FfmpegCommands.trim(
          input: input,
          startSec: startSec,
          endSec: endSec,
          output: out,
          hwH264: hw),
      totalSeconds: endSec - startSec,
      onProgress: onProgress,
    );
    return out;
  }

  Future<String> concat(
    List<String> inputs, {
    void Function(double)? onProgress,
  }) async {
    if (inputs.length < 2) {
      throw const FfmpegException(
          FfmpegErrorKind.invalidInput, 'Need at least 2 videos to join.');
    }
    for (final p in inputs) {
      await _needFile(p);
    }
    final hw = await supportsHwH264;
    final list = await _listFile(FfmpegCommands.concatListBody(inputs), 'join');
    final out = await _outPath('joined.mp4');
    double? total;
    for (final p in inputs) {
      total = (total ?? 0) + (await probeDurationSec(p) ?? 0);
    }
    await _run(
      FfmpegCommands.concat(listFile: list, output: out, hwH264: hw),
      totalSeconds: total,
      onProgress: onProgress,
    );
    return out;
  }

  Future<String> compress({
    required String input,
    int height = 720,
    void Function(double)? onProgress,
  }) async {
    await _needFile(input);
    if (height != 720 && height != 1080) {
      throw const FfmpegException(
          FfmpegErrorKind.invalidInput, 'Height must be 720 or 1080.');
    }
    final hw = await supportsHwH264;
    final out = await _outPath('compressed_${height}p.mp4');
    await _run(
      FfmpegCommands.compress(
          input: input, height: height, output: out, hwH264: hw),
      totalSeconds: await probeDurationSec(input),
      onProgress: onProgress,
    );
    return out;
  }

  Future<String> extractAudio({
    required String input,
    void Function(double)? onProgress,
  }) async {
    await _needFile(input);
    final out = await _outPath('audio.m4a');
    await _run(
      FfmpegCommands.extractAudio(input: input, output: out),
      totalSeconds: await probeDurationSec(input),
      onProgress: onProgress,
    );
    return out;
  }

  Future<String> thumbnailAt({
    required String input,
    required double atSec,
  }) async {
    await _needFile(input);
    final out = await _outPath('thumb.jpg');
    await _run(FfmpegCommands.thumbnail(input: input, atSec: atSec, output: out));
    return out;
  }

  Future<String> gifPreview({
    required String input,
    double startSec = 0,
    double durationSec = 3,
    void Function(double)? onProgress,
  }) async {
    await _needFile(input);
    final out = await _outPath('preview.gif');
    await _run(
      FfmpegCommands.gifPreview(
          input: input,
          startSec: startSec,
          durationSec: durationSec,
          output: out),
      totalSeconds: durationSec,
      onProgress: onProgress,
    );
    return out;
  }

  Future<String> changeSpeed({
    required String input,
    required double factor,
    void Function(double)? onProgress,
  }) async {
    await _needFile(input);
    if (factor < 0.5 || factor > 4) {
      throw const FfmpegException(
          FfmpegErrorKind.invalidInput, 'Speed must be between 0.5x and 4x.');
    }
    final hw = await supportsHwH264;
    final dur = await probeDurationSec(input);
    final out = await _outPath('speed_${factor}x.mp4');
    await _run(
      FfmpegCommands.changeSpeed(
          input: input, factor: factor, output: out, hwH264: hw),
      totalSeconds: dur == null ? null : dur / factor,
      onProgress: onProgress,
    );
    return out;
  }

  /// Fits [input] into an exact WxH frame (center-crop). Use 1080x1920 for
  /// 9:16 (Reels/Shorts/TikTok), 1080x1080 for 1:1, 1920x1080 for 16:9.
  Future<String> toAspect({
    required String input,
    required int width,
    required int height,
    void Function(double)? onProgress,
  }) async {
    await _needFile(input);
    final hw = await supportsHwH264;
    final out = await _outPath('aspect_${width}x$height.mp4');
    await _run(
      FfmpegCommands.toAspect(
          input: input, width: width, height: height, output: out, hwH264: hw),
      totalSeconds: await probeDurationSec(input),
      onProgress: onProgress,
    );
    return out;
  }

  Future<String> rotate({
    required String input,
    required int quarterTurnsClockwise,
    void Function(double)? onProgress,
  }) async {
    await _needFile(input);
    final hw = await supportsHwH264;
    final out = await _outPath('rotated.mp4');
    await _run(
      FfmpegCommands.rotate(
          input: input,
          quarterTurnsClockwise: quarterTurnsClockwise,
          output: out,
          hwH264: hw),
      totalSeconds: await probeDurationSec(input),
      onProgress: onProgress,
    );
    return out;
  }

  /// Adds background [music] under the video, ducking it below any existing
  /// audio. Probes the video for an audio stream first.
  Future<String> addBackgroundMusic({
    required String video,
    required String music,
    double musicVolume = 0.25,
    void Function(double)? onProgress,
  }) async {
    return mixAudio(video: video, musicPath: music, musicVolume: musicVolume,
        onProgress: onProgress);
  }

  /// Mixes a [voiceover] file over [video] (original audio ducked to 25%),
  /// optionally with background [music] ducked further.
  Future<String> mixAudio({
    required String video,
    String? voicePath,
    String? musicPath,
    double musicVolume = 0.25,
    void Function(double)? onProgress,
  }) async {
    await _needFile(video);
    if (voicePath != null) await _needFile(voicePath);
    if (musicPath != null) await _needFile(musicPath);
    if (voicePath == null && musicPath == null) {
      throw const FfmpegException(
          FfmpegErrorKind.invalidInput, 'Pick a voiceover or music file.');
    }
    final hw = await supportsHwH264;
    final baseHasAudio = await hasAudioStream(video);
    final out = await _outPath('mixed.mp4');
    await _run(
      FfmpegCommands.mixAudio(
        video: video,
        voicePath: voicePath,
        musicPath: musicPath,
        musicVolume: musicVolume,
        baseHasAudio: baseHasAudio,
        output: out,
        hwH264: hw,
      ),
      totalSeconds: await probeDurationSec(video),
      onProgress: onProgress,
    );
    return out;
  }

  /// Burns an SRT file into the video with [style]. Audio is copied
  /// untouched (no re-encode).
  Future<String> burnSubtitles({
    required String video,
    required String srtPath,
    CaptionStyle style = const CaptionStyle(),
    void Function(double)? onProgress,
  }) async {
    await _needFile(video);
    await _needFile(srtPath);
    final hw = await supportsHwH264;
    final out = await _outPath('captioned.mp4');
    await _run(
      FfmpegCommands.burnSubtitles(
          input: video, srtPath: srtPath, style: style, output: out, hwH264: hw),
      totalSeconds: await probeDurationSec(video),
      onProgress: onProgress,
    );
    return out;
  }

  /// Builds a WxH MP4 slideshow from [images], each shown for
  /// [durationsSec[i]] seconds, with optional [audioPath] underneath.
  Future<String> slideshow({
    required List<String> images,
    required List<double> durationsSec,
    String? audioPath,
    int width = 1080,
    int height = 1920,
    void Function(double)? onProgress,
  }) async {
    if (images.isEmpty || images.length != durationsSec.length) {
      throw const FfmpegException(FfmpegErrorKind.invalidInput,
          'Images and durations must match and not be empty.');
    }
    for (final p in images) {
      await _needFile(p);
    }
    if (audioPath != null) await _needFile(audioPath);
    final hw = await supportsHwH264;
    final list = await _listFile(
        FfmpegCommands.slideshowListBody(images, durationsSec), 'slideshow');
    final out = await _outPath('story.mp4');
    final total = durationsSec.fold(0.0, (a, b) => a + b);
    await _run(
      FfmpegCommands.slideshow(
        listFile: list,
        output: out,
        hwH264: hw,
        audioPath: audioPath,
        width: width,
        height: height,
      ),
      totalSeconds: total,
      onProgress: onProgress,
    );
    return out;
  }

  /// Writes [srtBody] to a temp .srt file and returns its path.
  Future<String> writeSrt(String srtBody) async {
    final dir = await _workDir();
    final f = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_caps.srt');
    await f.writeAsString(srtBody);
    return f.path;
  }
}
