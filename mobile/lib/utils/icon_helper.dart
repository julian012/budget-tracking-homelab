import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const categoryIconMap = {
  'utensils': LucideIcons.utensils, 'car': LucideIcons.car, 'zap': LucideIcons.zap,
  'film': LucideIcons.film, 'home': LucideIcons.house, 'tag': LucideIcons.tag,
  'shopping-cart': LucideIcons.shopping_cart, 'heart': LucideIcons.heart,
  'book': LucideIcons.book, 'plane': LucideIcons.plane, 'shirt': LucideIcons.shirt,
  'heart-pulse': LucideIcons.heart_pulse,
};

bool isEmojiIcon(String icon) =>
    icon.isNotEmpty && icon.runes.every((r) => r > 255);

Widget categoryIconWidget(String? icon, {double size = 18, Color? color}) {
  if (icon == null || icon.isEmpty) return Icon(LucideIcons.tag, size: size, color: color);
  if (isEmojiIcon(icon)) return Text(icon, style: TextStyle(fontSize: size));
  return Icon(categoryIconMap[icon] ?? LucideIcons.tag, size: size, color: color);
}

Widget franchiseIconWidget(String franchise, {double size = 18, Color color = Colors.white}) {
  switch (franchise) {
    case 'visa':
      return FaIcon(FontAwesomeIcons.ccVisa, color: color, size: size);
    case 'mastercard':
      return FaIcon(FontAwesomeIcons.ccMastercard, color: color, size: size);
    case 'amex':
      return FaIcon(FontAwesomeIcons.ccAmex, color: color, size: size);
    case 'diners':
      return FaIcon(FontAwesomeIcons.ccDinersClub, color: color, size: size);
    default:
      return Icon(LucideIcons.credit_card, color: color, size: size);
  }
}
