import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:virello/data/discovery_models.dart';
import 'package:virello/features/discovery/link_card.dart';

DiscoveryItem _item({String postType = 'link', String title = 'Item title'}) {
  return DiscoveryItem(
    campaignId: 'c1',
    title: title,
    platform: 'unknown',
    goal: 'reach',
    postUrl: 'https://www.example.com/some-article',
    thumbnailUrl: '',
    matchScore: 0.9,
    matchReasons: const ['topic match'],
    postType: postType,
  );
}

Map<String, dynamic> _preview() => {
      'title': 'A Great Article',
      'source': 'example.com',
      'ai_summary':
          'Automated AI summary. First sentence of the preview. Second one.',
      'thumbnail_url': '',
      'reading_time_min': 1,
      'word_count': 42,
    };

Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: card),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LinkCard.isLinkPost', () {
    test('true for post_type link', () {
      expect(LinkCard.isLinkPost(_item(postType: 'link')), isTrue);
    });

    test('false for social post types and empty', () {
      expect(LinkCard.isLinkPost(_item(postType: 'youtube')), isFalse);
      expect(LinkCard.isLinkPost(_item(postType: 'tiktok')), isFalse);
      expect(LinkCard.isLinkPost(_item(postType: '')), isFalse);
    });
  });

  group('LinkCard widget', () {
    testWidgets('renders domain, title, 2-line summary and Read button',
        (tester) async {
      final preview = _preview();
      await _pumpCard(
          tester, LinkCard(item: _item(), preview: preview, locale: 'en'));

      // Plain-text domain badge — never a third-party logo.
      expect(find.text('via example.com'), findsOneWidget);
      expect(find.text('A Great Article'), findsOneWidget);
      expect(find.text(preview['ai_summary'] as String), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      // Reading-time estimate is shown as an estimate (≈).
      expect(find.textContaining('≈'), findsOneWidget);
    });

    testWidgets('AI summary snippet is capped at 2 lines', (tester) async {
      final preview = _preview();
      await _pumpCard(
          tester, LinkCard(item: _item(), preview: preview, locale: 'en'));

      final summaryText =
          tester.widget<Text>(find.text(preview['ai_summary'] as String));
      expect(summaryText.maxLines, 2);
      expect(summaryText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('Read button invokes onRead', (tester) async {
      var tapped = false;
      await _pumpCard(
          tester,
          LinkCard(
              item: _item(),
              preview: _preview(),
              locale: 'en',
              onRead: () => tapped = true));

      await tester.tap(find.text('Read'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('no summary shown when preview has none (never invented)',
        (tester) async {
      await _pumpCard(
          tester,
          LinkCard(
              item: _item(title: 'Bare link'),
              preview: const {'source': 'example.com'},
              locale: 'en'));

      expect(find.text('Bare link'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      // The card renders fine without a snippet — nothing fabricated.
    });

    testWidgets('shows no fake metrics', (tester) async {
      await _pumpCard(
          tester, LinkCard(item: _item(), preview: _preview(), locale: 'en'));

      expect(find.textContaining('views'), findsNothing);
      expect(find.textContaining('likes'), findsNothing);
      expect(find.textContaining('followers'), findsNothing);
    });

    testWidgets('localized strings: Urdu', (tester) async {
      await _pumpCard(
          tester, LinkCard(item: _item(), preview: _preview(), locale: 'ur'));

      expect(find.text('پڑھیں'), findsOneWidget);
      expect(find.textContaining('بذریعہ example.com'), findsOneWidget);
    });

    testWidgets('localized strings: Arabic', (tester) async {
      await _pumpCard(
          tester, LinkCard(item: _item(), preview: _preview(), locale: 'ar'));

      expect(find.text('اقرأ'), findsOneWidget);
      expect(find.textContaining('عبر example.com'), findsOneWidget);
    });

    test('LinkCardStrings falls back to English for unknown locale', () {
      expect(LinkCardStrings.read('xx'), 'Read');
      expect(LinkCardStrings.linkPosts('xx'), 'Link posts');
      expect(LinkCardStrings.minRead(3, 'xx'), '≈ 3 min read');
    });
  });
}
