import 'package:flutter_test/flutter_test.dart';

import 'package:virello/features/collab/collab_strings.dart';

void main() {
  group('CollabStrings', () {
    test('English defaults', () {
      const s = CollabStrings('en');
      expect(s.title, 'Creator Collabs');
      expect(s.tabFind, 'Find Creators');
      expect(s.sendRequest, 'Send request');
      expect(s.selfDeclared, 'self-declared');
    });

    test('Urdu strings present', () {
      const s = CollabStrings('ur');
      expect(s.title, 'کریئیٹر تعاون');
      expect(s.tabInbox, 'ان باکس');
      expect(s.selfDeclared, isNotEmpty);
    });

    test('Arabic strings present', () {
      const s = CollabStrings('ar');
      expect(s.title, 'تعاون المبدعين');
      expect(s.tabMine, 'طلباتي');
      expect(s.selfDeclared, isNotEmpty);
    });

    test('status labels resolve per status', () {
      const s = CollabStrings('en');
      expect(s.statusPending('pending'), 'Pending');
      expect(s.statusAccepted('accepted'), 'Accepted');
      expect(s.statusDeclined('declined'), 'Declined');
      expect(s.statusShared('shared'), 'Shared');
      expect(s.statusPending('weird'), 'Pending'); // unknown -> pending
    });

    test('unknown locale falls back to English', () {
      const s = CollabStrings('xx');
      expect(s.title, 'Creator Collabs');
    });
  });
}
