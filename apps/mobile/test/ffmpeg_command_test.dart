import 'package:flutter_test/flutter_test.dart';

import 'package:virello/services/local_tools/caption_tools.dart';
import 'package:virello/services/local_tools/ffmpeg_service.dart';

/// Pure-Dart unit tests for the Phase B ffmpeg command builders.
/// No device, no native calls — every assertion is on the exact command
/// string handed to FFmpegKit.
void main() {
  group('path quoting', () {
    test('q wraps a plain path in single quotes', () {
      expect(FfmpegCommands.q('/a/b/c.mp4'), "'/a/b/c.mp4'");
    });

    test('q escapes an embedded single quote', () {
      expect(FfmpegCommands.q("/a/b'c.mp4"), r"'/a/b'\''c.mp4'");
    });

    test('escapeFilterPath escapes filter-special characters', () {
      final out = FfmpegCommands.escapeFilterPath(r"C:\vid,eo's [1].mp4");
      expect(out, contains(r'\:'));
      expect(out, contains(r'\,'));
      expect(out, contains(r"\'"));
      expect(out, contains(r'\['));
      expect(out, contains(r'\]'));
      expect(out, contains(r'\\'));
    });
  });

  group('videoCodec', () {
    test('uses h264_mediacodec with height-scaled bitrate', () {
      expect(FfmpegCommands.videoCodec(hwH264: true, height: 720),
          '-c:v h264_mediacodec -b:v 3M');
      expect(FfmpegCommands.videoCodec(hwH264: true, height: 1080),
          '-c:v h264_mediacodec -b:v 6M');
    });

    test('throws typed unsupported instead of mpeg4 fallback', () {
      expect(
        () => FfmpegCommands.videoCodec(hwH264: false),
        throwsA(isA<FfmpegException>()
            .having((e) => e.kind, 'kind', FfmpegErrorKind.unsupported)),
      );
    });
  });

  group('trim', () {
    test('seeks and limits duration correctly', () {
      final cmd = FfmpegCommands.trim(
        input: '/v/in.mp4',
        startSec: 5,
        endSec: 15,
        output: '/v/out.mp4',
        hwH264: true,
      );
      expect(cmd, contains('-ss 5 '));
      expect(cmd, contains('-t 10 '));
      expect(cmd, contains('-i \'/v/in.mp4\''));
      expect(cmd, contains('h264_mediacodec'));
      expect(cmd, contains('-c:a aac'));
      expect(cmd, contains('+faststart'));
      expect(cmd, endsWith("'/v/out.mp4'"));
    });
  });

  group('concat', () {
    test('concatListBody emits one file line per input', () {
      expect(FfmpegCommands.concatListBody(['/a/1.mp4', '/a/2.mp4']),
          "file '/a/1.mp4'\nfile '/a/2.mp4'");
    });

    test('concat uses the concat demuxer safely', () {
      final cmd = FfmpegCommands.concat(
          listFile: '/t/join.txt', output: '/t/out.mp4', hwH264: true);
      expect(cmd, contains('-f concat -safe 0'));
      expect(cmd, contains("'/t/join.txt'"));
    });
  });

  group('compress', () {
    test('720p scales and picks the 3M bitrate', () {
      final cmd = FfmpegCommands.compress(
          input: '/v/in.mp4', height: 720, output: '/v/o.mp4', hwH264: true);
      expect(cmd, contains('scale=-2:720'));
      expect(cmd, contains('-b:v 3M'));
    });

    test('1080p picks the 6M bitrate', () {
      final cmd = FfmpegCommands.compress(
          input: '/v/in.mp4', height: 1080, output: '/v/o.mp4', hwH264: true);
      expect(cmd, contains('scale=-2:1080'));
      expect(cmd, contains('-b:v 6M'));
    });
  });

  group('aspect / rotate', () {
    test('toAspect 9:16 scales up and center-crops', () {
      final cmd = FfmpegCommands.toAspect(
          input: '/v/in.mp4',
          width: 1080,
          height: 1920,
          output: '/v/o.mp4',
          hwH264: true);
      expect(
          cmd,
          contains(
              'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920'));
      expect(cmd, contains('setsar=1'));
    });

    test('toAspect 1:1 produces a square frame', () {
      final cmd = FfmpegCommands.toAspect(
          input: '/v/in.mp4',
          width: 1080,
          height: 1080,
          output: '/v/o.mp4',
          hwH264: true);
      expect(cmd, contains('crop=1080:1080'));
    });

    test('rotate normalizes quarter turns', () {
      final cw = FfmpegCommands.rotate(
          input: '/v/in.mp4',
          quarterTurnsClockwise: 1,
          output: '/v/o.mp4',
          hwH264: true);
      expect(cw, contains('transpose=1'));
      final ccw = FfmpegCommands.rotate(
          input: '/v/in.mp4',
          quarterTurnsClockwise: -1,
          output: '/v/o.mp4',
          hwH264: true);
      expect(ccw, contains('transpose=2'));
    });
  });

  group('changeSpeed', () {
    test('2x uses a single atempo within the valid range', () {
      final cmd = FfmpegCommands.changeSpeed(
          input: '/v/in.mp4', factor: 2, output: '/v/o.mp4', hwH264: true);
      expect(cmd, contains('-af "atempo=2"'));
      expect(cmd, contains('setpts=0.5*PTS'));
    });

    test('4x chains atempo filters (each stays within 0.5-2.0)', () {
      final cmd = FfmpegCommands.changeSpeed(
          input: '/v/in.mp4', factor: 4, output: '/v/o.mp4', hwH264: true);
      expect(cmd, contains('-af "atempo=2.0,atempo=2.0"'));
      expect(cmd, contains('setpts=0.25*PTS'));
      expect(cmd, isNot(contains('atempo=4')));
    });

    test('0.5x slow motion stays a single filter', () {
      final cmd = FfmpegCommands.changeSpeed(
          input: '/v/in.mp4', factor: 0.5, output: '/v/o.mp4', hwH264: true);
      expect(cmd, contains('-af "atempo=0.5"'));
      expect(cmd, contains('setpts=2*PTS'));
    });
  });

  group('burnSubtitles', () {
    test('assColor converts 0xAARRGGBB to &HAABBGGRR', () {
      expect(FfmpegCommands.assColor(0xFFFFFFFF), '&HFFFFFFFF');
      expect(FfmpegCommands.assColor(0xCC000000), '&HCC000000');
      expect(FfmpegCommands.assColor(0xFFFF0000), '&HFF0000FF');
    });

    test('builds a subtitles filter with quoted force_style', () {
      final cmd = FfmpegCommands.burnSubtitles(
        input: '/v/in.mp4',
        srtPath: '/t/cap.srt',
        style: const CaptionStyle(),
        output: '/v/o.mp4',
        hwH264: true,
      );
      expect(cmd, contains('subtitles=/t/cap.srt'));
      expect(cmd, contains("force_style='FontSize=22,"));
      expect(cmd, contains('PrimaryColour=&HFFFFFFFF'));
      expect(cmd, contains('Alignment=2')); // bottom
      expect(cmd, contains('-c:a copy'));
    });

    test('escapes special characters in the srt path', () {
      final cmd = FfmpegCommands.burnSubtitles(
        input: '/v/in.mp4',
        srtPath: "/t/my cap's.srt",
        style: const CaptionStyle(position: CaptionPosition.top),
        output: '/v/o.mp4',
        hwH264: true,
      );
      expect(cmd, contains(r"my cap\'s.srt"));
      expect(cmd, contains('Alignment=8')); // top
    });
  });

  group('slideshow', () {
    test('slideshowListBody repeats the last file (demuxer quirk)', () {
      final body = FfmpegCommands.slideshowListBody(
          ['/p/1.jpg', '/p/2.jpg'], [3.0, 4.0]);
      expect(
          body,
          "file '/p/1.jpg'\nduration 3\n"
          "file '/p/2.jpg'\nduration 4\n"
          "file '/p/2.jpg'\n");
    });

    test('with audio maps aac and applies -shortest', () {
      final cmd = FfmpegCommands.slideshow(
        listFile: '/t/list.txt',
        output: '/t/o.mp4',
        hwH264: true,
        audioPath: '/t/m.mp3',
      );
      expect(cmd, contains("'/t/m.mp3'"));
      expect(cmd, contains('-c:a aac'));
      expect(cmd, contains('-shortest'));
      expect(cmd, contains('fps=30'));
    });

    test('without audio disables the audio track', () {
      final cmd = FfmpegCommands.slideshow(
          listFile: '/t/list.txt', output: '/t/o.mp4', hwH264: true);
      expect(cmd, contains('-an'));
    });
  });

  group('mixAudio', () {
    test('voice + music over base audio builds a ducking filter graph', () {
      final cmd = FfmpegCommands.mixAudio(
        video: '/v/in.mp4',
        voicePath: '/t/vo.m4a',
        musicPath: '/t/mu.mp3',
        baseHasAudio: true,
        output: '/t/o.mp4',
        hwH264: true,
      );
      expect(cmd, contains('-filter_complex'));
      expect(cmd, contains('amix=inputs=2'));
      expect(cmd, contains('-map 0:v -map "[aout]"'));
      expect(cmd, contains('-c:a aac'));
    });

    test('voice only without base audio maps the voice stream directly',
        () {
      final cmd = FfmpegCommands.mixAudio(
        video: '/v/in.mp4',
        voicePath: '/t/vo.m4a',
        baseHasAudio: false,
        output: '/t/o.mp4',
        hwH264: true,
      );
      expect(cmd, contains('-map 0:v -map 1:a'));
      expect(cmd, contains('-shortest'));
    });

    test('music volume is honored', () {
      final cmd = FfmpegCommands.mixAudio(
        video: '/v/in.mp4',
        musicPath: '/t/mu.mp3',
        musicVolume: 0.5,
        baseHasAudio: true,
        output: '/t/o.mp4',
        hwH264: true,
      );
      expect(cmd, contains('volume=0.5'));
    });

    test('throws typed invalidInput when nothing is mixed', () {
      expect(
        () => FfmpegCommands.mixAudio(
            video: '/v/in.mp4',
            baseHasAudio: false,
            output: '/t/o.mp4',
            hwH264: true),
        throwsA(isA<FfmpegException>()
            .having((e) => e.kind, 'kind', FfmpegErrorKind.invalidInput)),
      );
    });
  });

  group('extractAudio / thumbnail / gifPreview', () {
    test('extractAudio drops video and encodes aac', () {
      final cmd = FfmpegCommands.extractAudio(
          input: '/v/in.mp4', output: '/t/a.m4a');
      expect(cmd, contains('-vn'));
      expect(cmd, contains('-c:a aac'));
    });

    test('thumbnail grabs a single frame', () {
      final cmd = FfmpegCommands.thumbnail(
          input: '/v/in.mp4', atSec: 2.5, output: '/t/t.jpg');
      expect(cmd, contains('-frames:v 1'));
      expect(cmd, contains('-ss 2.5 '));
    });

    test('gifPreview builds a palette pipeline', () {
      final cmd = FfmpegCommands.gifPreview(
          input: '/v/in.mp4',
          startSec: 1,
          durationSec: 2,
          output: '/t/p.gif');
      expect(cmd, contains('palettegen'));
      expect(cmd, contains('paletteuse'));
      expect(cmd, contains('-t 2 '));
    });
  });
}
