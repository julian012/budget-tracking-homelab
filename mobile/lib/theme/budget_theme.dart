import 'package:flutter/material.dart';

const _seedColor = Color(0xFF0F52BA);
const _scrimColor = Color(0xFF1A1C1E);

// Colores de superficie para el modo oscuro.
const _darkSurface = Color(0xFF121316);
const _darkCard = Color(0xFF1D1F24);
const _darkInputFill = Color(0xFF272A30);
const _darkAppBar = Color(0xFF161D2E);
const _darkTextSecondary = Color(0xFF9BA1AA);

extension BudgetColors on ColorScheme {
  bool get _isDark => brightness == Brightness.dark;

  Color get income => const Color(0xFF00A86B);

  Color get expense => const Color(0xFFE53935);

  Color get cardSurface => _isDark ? _darkCard : const Color(0xFFFFFFFF);

  Color get textSecondary =>
      _isDark ? _darkTextSecondary : const Color(0xFF73777F);
}

class BudgetTheme {
  BudgetTheme._();

  static const spacing8 = 8.0;
  static const spacing16 = 16.0;
  static const spacing24 = 24.0;

  static const borderRadiusSmall = 8.0;
  static const borderRadiusMedium = 16.0;
  static const borderRadiusLarge = 28.0;
  static const borderRadiusPill = 100.0;

  static const cardElevation = 1.0;
  static const cardPadding = 16.0;

  static const buttonHeight = 48.0;
  static const compactButtonHeight = 40.0;

  static const listItemHeight = 72.0;
  static const listItemPaddingHorizontal = 16.0;

  static const categoryIconSize = 24.0;
  static const categoryCircleAvatarOpacity = 0.12;
  static const actionIconSize = 20.0;
  static const emptyStateMaxHeight = 180.0;

  /// FilledButton para usar dentro de un Row/ListTile.trailing. El tema global
  /// fuerza `minimumSize.width = infinity` (botones de formulario a ancho
  /// completo), lo que rompe el layout si el ancho no está acotado (#81).
  static final ButtonStyle compactFilledButton = FilledButton.styleFrom(
    minimumSize: const Size(0, compactButtonHeight),
  );

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    ).copyWith(
      surface: isDark ? _darkSurface : const Color(0xFFF8F9FA),
      onSurface: isDark ? const Color(0xFFF2F3F5) : _scrimColor,
    );

    final primary = ThemeData(brightness: brightness, useMaterial3: true);
    final baseText = primary.textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _darkAppBar : colorScheme.primary,
        foregroundColor: isDark ? Colors.white : colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: isDark ? _darkCard : Colors.white,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusPill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkInputFill : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadiusLarge)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: listItemPaddingHorizontal),
        minVerticalPadding: 0,
      ),
      textTheme: baseText.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: isDark ? _darkTextSecondary : const Color(0xFF73777F),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: isDark ? _darkTextSecondary : const Color(0xFF73777F),
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}