import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _formatter = NumberFormat.currency(
  symbol: '\$',
  decimalDigits: 2,
);

String formatCurrency(double amount) => _formatter.format(amount);

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    final formatted = NumberFormat.decimalPattern('es_CO').format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
