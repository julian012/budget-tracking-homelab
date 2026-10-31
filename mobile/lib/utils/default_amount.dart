import 'package:intl/intl.dart';

double? parseDefaultAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return null;
  return double.tryParse(digits) ?? 0;
}

String formatAmountInput(double value) {
  if (value <= 0) return '';
  return NumberFormat.decimalPattern('es_CO').format(value.toInt());
}

bool shouldOfferDefaultUpdate({double? currentDefault, required double amount}) {
  if (currentDefault == null || currentDefault <= 0) return false;
  return amount != currentDefault;
}
