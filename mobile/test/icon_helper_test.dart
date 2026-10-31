import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/icon_helper.dart';

void main() {
  group('isEmojiIcon', () {
    test('returns true for single-rune emoji', () {
      expect(isEmojiIcon('🚌'), isTrue);
      expect(isEmojiIcon('⚡'), isTrue);
      expect(isEmojiIcon('👕'), isTrue);
    });

    test('returns true for emoji with variation selector (2 runes)', () {
      expect(isEmojiIcon('✈️'), isTrue);
      expect(isEmojiIcon('🍽️'), isTrue);
    });

    test('returns false for Lucide icon names', () {
      expect(isEmojiIcon('plane'), isFalse);
      expect(isEmojiIcon('utensils'), isFalse);
      expect(isEmojiIcon(''), isFalse);
      expect(isEmojiIcon('tag'), isFalse);
    });
  });

  group('categoryIconWidget', () {
    testWidgets('renders Text for emoji with variation selector', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: categoryIconWidget('✈️')),
      ));

      expect(find.text('✈️'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders Lucide icon for name-based icons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: categoryIconWidget('plane')),
      ));

      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
