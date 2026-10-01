import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virello/core/strings.dart';
import 'package:virello/features/tour/app_tour.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('buildTourSteps', () {
    test('covers welcome, 6 tabs, in-page controls, Ask, done', () {
      final s = AppStrings('en');
      final steps = buildTourSteps(s);
      expect(steps.length, 15);
      // Welcome + done have no target.
      expect(steps.first.target, isNull);
      expect(steps.last.target, isNull);
      // Every tab 0..5 is visited.
      final tabs = steps.map((e) => e.tabIndex).toSet();
      for (var i = 0; i <= 5; i++) {
        expect(tabs, contains(i));
      }
      // All targeted steps have a non-null target key.
      final targeted = steps.where((e) => e.target != null).toList();
      expect(targeted.length, 13);
      // Titles resolve in EN/UR/AR without throwing.
      for (final code in ['en', 'ur', 'ar']) {
        final ss = AppStrings(code);
        for (final st in steps) {
          expect(st.title(ss).isNotEmpty, isTrue);
          expect(st.description(ss).isNotEmpty, isTrue);
        }
      }
    });
  });

  group('AppTourService', () {
    test('per-account keys: fresh account has not seen the tour', () async {
      expect(await AppTourService.hasSeenTour(), isFalse);
      await AppTourService.markTourSeen();
      expect(await AppTourService.hasSeenTour(), isTrue);
      await AppTourService.resetTour();
      expect(await AppTourService.hasSeenTour(), isFalse);
    });
  });

  group('AppTourOverlay', () {
    testWidgets('welcome -> next switches tab and spotlights measured target',
        (tester) async {
      final switched = <int>[];
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Mount the home-tab target so measurement succeeds fast.
                Positioned(
                  left: 40,
                  bottom: 20,
                  child: SizedBox(
                    key: TourTargets.homeTab,
                    width: 60,
                    height: 60,
                  ),
                ),
                AppTourOverlay(
                  onTabSwitch: switched.add,
                  onComplete: () => completed = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(); // overlay init
      await tester.pump(const Duration(milliseconds: 100));

      // Welcome card, centered, no spotlight yet.
      expect(find.text('Welcome to Virello'), findsOneWidget);

      // Next -> step 1 (Home tab): tab switch + measured spotlight.
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(switched, contains(0));
      expect(find.text('Home'), findsOneWidget);

      // Back returns to welcome without a tab switch.
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Welcome to Virello'), findsOneWidget);

      // Skip finishes the tour and persists the seen flag.
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(completed, isTrue);
      expect(await AppTourService.hasSeenTour(), isTrue);
    });
  });
}
