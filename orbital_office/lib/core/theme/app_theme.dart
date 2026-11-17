import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ORBITAL OFFICE design tokens (Part 1 of the specification).
class AppColors {
  const AppColors._();
  static const Color forestGreen = Color(0xFF073D2D);
  static const Color deepGreen = Color(0xFF0B513B);
  static const Color warmIvory = Color(0xFFF5F0E5);
  static const Color premiumGold = Color(0xFFD5A044);
  static const Color white = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF202A26);
  static const Color lightGrey = Color(0xFFF3F4F1);

  // Dark-theme surfaces derived from the brand palette.
  static const Color darkSurface = Color(0xFF12271F);
  static const Color darkCard = Color(0xFF1A3328);
  static const Color mutedText = Color(0xFF6B7A72);
}

class AppTheme {
  const AppTheme._();

  static const double radiusCard = 20;
  static const double radiusSmall = 12;
  static const double space = 16;

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    // Headings: Manrope. Body: Inter. Tabular numerals for numbers are
    // enabled on numeric text styles via FontFeature.tabularFigures below.
    final headings = GoogleFonts.manropeTextTheme(base);
    final body = GoogleFonts.interTextTheme(base);
    return body.copyWith(
      displaySmall: headings.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium:
          headings.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall:
          headings.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: headings.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: headings.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: headings.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: headings.labelLarge,
    );
  }

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepGreen,
      primary: AppColors.forestGreen,
      secondary: AppColors.deepGreen,
      tertiary: AppColors.premiumGold,
      surface: AppColors.white,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.warmIvory,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.charcoal,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: AppColors.charcoal.withValues(alpha: 0.06)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forestGreen,
          foregroundColor: AppColors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: AppColors.charcoal.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: AppColors.charcoal.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: AppColors.deepGreen, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepGreen,
      primary: const Color(0xFF7FC8A9),
      secondary: AppColors.premiumGold,
      tertiary: AppColors.premiumGold,
      surface: AppColors.darkSurface,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0C1F17),
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: AppColors.white.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepGreen,
          foregroundColor: AppColors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: AppColors.premiumGold, width: 1.6),
        ),
      ),
    );
  }
}
