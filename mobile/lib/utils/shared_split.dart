/// Utilidades puro-Dart para dividir un gasto compartido.
library;

/// Calcula partes iguales (en pesos enteros) para las `selectedCount`
/// personas seleccionadas. La parte del usuario es `total - sum(amounts)`.
/// Ej: total 50000, selectedCount 1 -> [25000] (usuario 25000)
/// Ej: total 50000, selectedCount 2 -> [16666, 16666] (usuario 16668)
List<double> equalSelectedAmounts(double total, int selectedCount) {
  if (selectedCount <= 0 || total <= 0) return [];
  final base = (total / (selectedCount + 1)).floorToDouble();
  return List<double>.filled(selectedCount, base);
}

/// Devuelve la parte que le corresponde al usuario pagador.
double userPart(double total, List<double> personAmounts) {
  final sum = personAmounts.fold<double>(0, (s, a) => s + a);
  return (total - sum).clamp(0.0, total);
}

/// Valida que cada monto sea positivo y que la suma no supere el total.
String? validateSplit(double total, List<double> personAmounts) {
  if (personAmounts.isEmpty) return 'Seleccioná al menos una persona';
  for (final a in personAmounts) {
    if (a <= 0) return 'Cada monto debe ser mayor a cero';
  }
  final sum = personAmounts.fold<double>(0, (s, a) => s + a);
  if (sum > total) return 'La suma de las partes supera el gasto';
  return null;
}

/// Arma el body para enviar al backend.
Map<String, dynamic> buildShareBody(String personId, double amount) {
  return {'person_id': personId, 'amount': amount};
}
