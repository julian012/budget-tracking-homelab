import '../services/api_service.dart';

const defaultCategories = [
  {'name': 'Comida', 'icon': '🍽️', 'color': '#EF4444', 'type': 0, 'requires_description': true},
  {'name': 'Transporte', 'icon': '🚌', 'color': '#F59E0B', 'type': 0, 'requires_description': true},
  {'name': 'Servicios', 'icon': '⚡', 'color': '#8B5CF6', 'type': 0, 'requires_description': true},
  {'name': 'Entretenimiento', 'icon': '🎬', 'color': '#EC4899', 'type': 0, 'requires_description': true},
  {'name': 'Ropa', 'icon': '👕', 'color': '#F97316', 'type': 0, 'requires_description': true},
  {'name': 'Salud', 'icon': '💊', 'color': '#06B6D4', 'type': 0, 'requires_description': true},
  {'name': 'Hogar', 'icon': '🏠', 'color': '#10B981', 'type': 1, 'requires_description': true},
];

Future<void> ensureDefaultCategories(String token, String baseUrl) async {
  try {
    final api = ApiService(baseUrl);
    final cats = await api.getCategories(token);
    if (cats.isNotEmpty) return;

    for (final c in defaultCategories) {
      await api.createCategory(token, {
        'name': c['name'],
        'icon': c['icon'],
        'color': c['color'],
        'type': c['type'],
      });
    }
  } catch (_) {}
}
