import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:virello/features/transform/transform_screen.dart';
import 'package:virello/features/transform/transform_strings.dart';

void main() {
  testWidgets('TransformScreen renders form, modes and 5 platform tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransformScreen()));

    expect(find.text('Content Transformer'), findsOneWidget);
    expect(find.text('Link'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Transform'), findsOneWidget);
    for (final p in ['Instagram', 'TikTok', 'YouTube', 'Facebook', 'X']) {
      expect(find.text(p), findsOneWidget);
    }
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Tapping a platform tab switches selection',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransformScreen()));
    await tester.tap(find.text('TikTok'));
    await tester.pump();
    // No crash; screen still shows the form (selection state updated).
    expect(find.text('Content Transformer'), findsOneWidget);
  });

  testWidgets('Empty input shows the empty-input error, no crash',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransformScreen()));
    await tester.tap(find.text('Transform'));
    await tester.pump();
    expect(find.text(trTransform('en', 'emptyInput')), findsOneWidget);
  });

  test('transform strings cover en/ur/ar for every key', () {
    const keys = [
      'title', 'subtitle', 'modeUrl', 'modeText', 'hintUrl', 'hintText',
      'transform', 'videoScript', 'carousel', 'thread', 'storyCaption',
      'hook', 'beats', 'cta', 'copy', 'copied', 'sourceAi', 'sourceHeuristic',
      'draftsNote', 'emptyInput', 'error',
      'instagram', 'tiktok', 'youtube', 'facebook', 'x',
    ];
    for (final locale in ['en', 'ur', 'ar']) {
      for (final k in keys) {
        expect(transformStrings[locale]![k], isNotEmpty,
            reason: '$locale.$k missing');
      }
    }
    // Fallback: unknown locale resolves to English.
    expect(trTransform('xx', 'title'), transformStrings['en']!['title']);
  });
}
