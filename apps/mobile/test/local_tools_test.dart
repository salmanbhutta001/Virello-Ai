import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:virello/services/local_tools/caption_tools.dart';
import 'package:virello/services/local_tools/image_tools.dart';
import 'package:virello/services/local_tools/templates_engine.dart';

img.Image _sample(int w, int h) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(200, 100, 50));
  return im;
}

void main() {
  group('CaptionTools', () {
    test('timedCaptions splits words and keeps timing sequential', () {
      final words =
          List.generate(20, (i) => 'word$i').join(' ');
      final lines = CaptionTools.timedCaptions(
        words,
        wordsPerSecond: 2.5,
        maxWordsPerLine: 8,
      );
      expect(lines.length, 3); // 8 + 8 + 4
      expect(lines[0].text.split(' ').length, 8);
      expect(lines[1].start, lines[0].end);
      expect(lines[2].start, lines[1].end);
      for (final l in lines) {
        expect(l.end, greaterThan(l.start));
      }
    });

    test('empty script yields no lines', () {
      expect(CaptionTools.timedCaptions('   '), isEmpty);
    });

    test('estimateDuration math', () {
      final words = List.generate(25, (i) => 'w$i').join(' ');
      expect(
        CaptionTools.estimateDuration(words, wordsPerSecond: 2.5),
        closeTo(10.0, 0.001),
      );
    });

    test('formatSrtTime', () {
      expect(CaptionTools.formatSrtTime(1.5), '00:00:01,500');
      expect(CaptionTools.formatSrtTime(61.25), '00:01:01,250');
      expect(CaptionTools.formatSrtTime(0), '00:00:00,000');
    });

    test('toSrt numbering and arrows', () {
      final lines = CaptionTools.timedCaptions(
        'hello world foo bar',
        wordsPerSecond: 2.0,
        maxWordsPerLine: 2,
      );
      final srt = CaptionTools.toSrt(lines);
      expect(srt, contains('1\n00:00:00,000 --> 00:00:01,000\nhello world'));
      expect(srt, contains('\n2\n'));
    });
  });

  group('TemplatesEngine', () {
    test('ships the five required templates', () {
      final ids = TemplatesEngine.builtIn.map((t) => t.id).toSet();
      expect(
        ids,
        containsAll(
            ['pov', 'before-after', 'tutorial', 'unboxing', 'quick-review']),
      );
    });

    test('byId resolves and misses cleanly', () {
      expect(TemplatesEngine.byId('tutorial')?.name, 'Tutorial');
      expect(TemplatesEngine.byId('nope'), isNull);
    });

    test('buildProject timing is cumulative and keeps empty slots visible', () {
      final t = TemplatesEngine.byId('before-after')!;
      final p = TemplatesEngine.buildProject(
        template: t,
        slotValues: {'before': 'messy room', 'process': '', 'after': ''},
      );
      expect(p.shots.length, 3);
      expect(p.shots[0].start, 0);
      expect(p.shots[1].start, p.shots[0].end);
      expect(p.shots[2].start, p.shots[1].end);
      // Empty slots keep their hint so nothing silently drops.
      expect(p.shots[1].content, contains('['));
      // Captions only from filled values.
      expect(p.captions, isNotEmpty);
      expect(p.shotList(), contains('Shot 1'));
      expect(p.shotList(), contains('CTA:'));
      final json = p.toJson();
      expect(json['templateId'], 'before-after');
      expect((json['shots'] as List).length, 3);
    });

    test('default CTA used when override blank', () {
      final t = TemplatesEngine.byId('pov')!;
      final p = TemplatesEngine.buildProject(
        template: t,
        slotValues: const {},
        cta: '   ',
      );
      expect(p.cta, t.defaultCta);
    });
  });

  group('ImageTools', () {
    test('decode round-trips PNG bytes', () {
      final bytes = img.encodePng(_sample(100, 60));
      final decoded = ImageTools.decode(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 100);
      expect(decoded.height, 60);
    });

    test('decode returns null for garbage', () {
      expect(ImageTools.decode(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });

    test('cropCenterSquare / rotate90 / flip dimensions', () {
      final im = _sample(100, 60);
      final sq = ImageTools.cropCenterSquare(im);
      expect(sq.width, 60);
      expect(sq.height, 60);
      final rot = ImageTools.rotate90(im);
      expect(rot.width, 60);
      expect(rot.height, 100);
      final fh = ImageTools.flipHorizontal(im);
      expect(fh.width, 100);
      expect(fh.height, 60);
    });

    test('grayscale makes r==g==b', () {
      final g = ImageTools.applyFilter(_sample(10, 10), ImageFilter.grayscale);
      final px = g.getPixel(5, 5);
      expect(px.r, px.g);
      expect(px.g, px.b);
    });

    test('filters preserve dimensions', () {
      for (final f in ImageFilter.values) {
        final out = ImageTools.applyFilter(_sample(40, 30), f);
        expect(out.width, 40, reason: f.name);
        expect(out.height, 30, reason: f.name);
      }
    });

    test('textOverlay and watermark preserve dimensions', () {
      final im = _sample(200, 120);
      expect(ImageTools.textOverlay(im, text: 'hi').width, 200);
      expect(ImageTools.watermark(im, 'virello').height, 120);
    });

    test('blurBackground916 outputs 1080x1920', () {
      final out = ImageTools.blurBackground916(_sample(800, 600));
      expect(out.width, 1080);
      expect(out.height, 1920);
      final tall = ImageTools.blurBackground916(_sample(600, 1200));
      expect(tall.width, 1080);
      expect(tall.height, 1920);
    });

    test('downscaleForUpload caps longest side', () {
      final big = ImageTools.downscaleForUpload(_sample(4000, 3000));
      expect(big.width, 2048);
      final small = ImageTools.downscaleForUpload(_sample(800, 600));
      expect(small.width, 800);
    });
  });
}
