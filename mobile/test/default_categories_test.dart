import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/default_categories.dart';

void main() {
  group('defaultCategories', () {
    test('contiene las 7 categorías sugeridas', () {
      expect(defaultCategories.length, 7);
      expect(
        defaultCategories.map((c) => c['name']),
        containsAll(['Comida', 'Transporte', 'Servicios', 'Entretenimiento', 'Ropa', 'Salud', 'Hogar']),
      );
    });

    test('todas tienen nombre, icono y color hex válido', () {
      for (final c in defaultCategories) {
        expect(c['name'], isNotEmpty);
        expect(c['icon'], isNotNull);
        expect(c['color'], matches(RegExp(r'^#[0-9A-Fa-f]{6}$')));
      }
    });

    test('solo Hogar es fija (type 1), el resto variable (type 0)', () {
      for (final c in defaultCategories) {
        final wantType = c['name'] == 'Hogar' ? 1 : 0;
        expect(c['type'], wantType, reason: 'tipo inesperado en ${c['name']}');
      }
    });

    test('nombres sin duplicados', () {
      final names = defaultCategories.map((c) => c['name'] as String).toSet();
      expect(names.length, defaultCategories.length);
    });
  });

  group('ensureDefaultCategories', () {
    test('no lanza aunque el servidor sea inalcanzable (best-effort)', () async {
      await expectLater(
        ensureDefaultCategories('fake-token', 'http://10.255.255.1:1'),
        completes,
      );
    });
  });
}
