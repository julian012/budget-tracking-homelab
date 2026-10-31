import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/widgets/filter_chips_bar.dart';

void main() {
  testWidgets('renders all options with correct labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilterChipsBar(
          options: const [
            (value: 'quarter', label: '3M'),
            (value: 'month', label: 'Mes'),
            (value: '7d', label: '7d'),
          ],
          selected: 'quarter',
          onChanged: (_) {},
        ),
      ),
    ));

    expect(find.text('3M'), findsOneWidget);
    expect(find.text('Mes'), findsOneWidget);
    expect(find.text('7d'), findsOneWidget);
  });

  testWidgets('marks the selected chip as selected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilterChipsBar(
          options: const [
            (value: 'a', label: 'A'),
            (value: 'b', label: 'B'),
          ],
          selected: 'b',
          onChanged: (_) {},
        ),
      ),
    ));

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    expect(chips[0].selected, isFalse);
    expect(chips[1].selected, isTrue);
  });

  testWidgets('invokes onChanged with the tapped value', (tester) async {
    String? changed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilterChipsBar(
          options: const [
            (value: 'quarter', label: '3M'),
            (value: 'month', label: 'Mes'),
          ],
          selected: 'quarter',
          onChanged: (v) => changed = v,
        ),
      ),
    ));

    await tester.tap(find.text('Mes'));
    await tester.pump();

    expect(changed, 'month');
  });

  testWidgets('renders the trailing widget when provided', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilterChipsBar(
          options: const [
            (value: 'a', label: 'A'),
          ],
          selected: 'a',
          onChanged: (_) {},
          trailing: const ActionChip(label: Text('Personalizado')),
        ),
      ),
    ));

    expect(find.text('Personalizado'), findsOneWidget);
  });

  testWidgets('applies the shared vertical padding and centers content', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilterChipsBar(
          options: const [
            (value: 'a', label: 'A'),
          ],
          selected: 'a',
          onChanged: (_) {},
        ),
      ),
    ));

    final outerPadding = find.byWidgetPredicate(
      (w) => w is Padding && w.child is Center,
    );
    final insets = tester.widget<Padding>(outerPadding).padding as EdgeInsets;
    expect(insets.top, 16.0);

    expect(find.byType(Center), findsWidgets);
  });
}
