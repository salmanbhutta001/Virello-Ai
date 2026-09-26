// Basic smoke test: the app widget builds without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:virello/main.dart';

void main() {
  testWidgets('VirelloApp builds a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const VirelloApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
