import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFFF1F2F4);
  static const Color card = Color(0xFFF6F7F9);
  static const Color border = Color(0xFFD6D9DE);
  static const Color primaryBlue = Color(0xFF1B84F2);
  static const Color secondaryBlue = Color(0xFF3197E6);
  static const Color success = Color(0xFF2DAF64);

  static ThemeData get classicBlueTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.merriweather(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF111111),
      ),
      headlineMedium: GoogleFonts.merriweather(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF111111),
      ),
      titleLarge: GoogleFonts.merriweather(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF151515),
      ),
      titleMedium: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1B1E24),
      ),
      bodyLarge: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF2D333A),
      ),
      bodyMedium: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF4A4F55),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: secondaryBlue,
        surface: card,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: const BorderSide(color: primaryBlue),
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.merriweather(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF111111),
          fontSize: 34,
        ),
      ),
    );
  }
}
