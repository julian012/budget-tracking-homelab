import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/color_utils.dart';
import '../utils/icon_helper.dart';

class WalletCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onTap;

  const WalletCard({super.key, required this.card, required this.onTap});

  Color _darken(Color color, [double amount = 0.3]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  String _formatCurrency(double? v) {
    if (v == null) return '****';
    return '\$ ${NumberFormat.decimalPattern('es_CO').format(v.toInt())}';
  }

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(card['color']?.toString(), fallback: Colors.grey.shade800);
    final name = card['name'] as String? ?? '';
    final franchise = card['franchise']?.toString() ?? 'other';
    final limit = (card['credit_limit'] as num?)?.toDouble();

    return AspectRatio(
      aspectRatio: 1.58,
      child: LayoutBuilder(builder: (context, constraints) {
        final logoSize = constraints.maxWidth * 0.25;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, _darken(color)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  top: 48,
                  left: 16,
                  right: 16,
                  child: Text(
                    _formatCurrency(limit),
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Text(
                    'Corte: ${card['cut_off_day']} · Pago: ${card['payment_day']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(8),
                    child: franchiseIconWidget(franchise, size: logoSize - 16),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
