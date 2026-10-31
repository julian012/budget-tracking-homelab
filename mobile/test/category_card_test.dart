import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/widgets/category_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('CategoryCard', () {
    testWidgets('muestra nombre y aplica color hex al texto', (tester) async {
      await tester.pumpWidget(wrap(CategoryCard(
        category: const {'id': 'c1', 'name': 'Comida', 'icon': '🍔', 'color': '#EF4444'},
        onTap: () {},
      )));

      expect(find.text('Comida'), findsOneWidget);
      final text = tester.widget<Text>(find.text('Comida'));
      expect(text.style?.color, isNotNull);
    });

    testWidgets('icono emoji se renderiza como texto', (tester) async {
      await tester.pumpWidget(wrap(CategoryCard(
        category: const {'id': 'c1', 'name': 'Viajes', 'icon': '✈️', 'color': '#10B981'},
        onTap: () {},
      )));

      expect(find.text('✈️'), findsOneWidget);
    });

    testWidgets('invoca onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(CategoryCard(
        category: const {'id': 'c1', 'name': 'Hogar', 'icon': '🏠', 'color': '#8B5CF6'},
        onTap: () => taps++,
      )));

      await tester.tap(find.text('Hogar'));
      expect(taps, 1);
    });

    testWidgets('color inválido cae a gris sin excepción', (tester) async {
      await tester.pumpWidget(wrap(CategoryCard(
        category: const {'id': 'c1', 'name': 'Raro', 'icon': '🏷️', 'color': '#GGHHII'},
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Raro'), findsOneWidget);
    });
  });
}
