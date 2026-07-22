import 'package:flutter/material.dart';

// ponytail: production-grade eye-catching theme & vibrant background

class AppTheme {
  static const _fontFamily = 'Inter';

  // Eye-catching deep midnight slate & vibrant neon accents
  static const Color bg1 = Color(0xFF0B0F19);
  static const Color bg2 = Color(0xFF14192B);
  static const Color bg3 = Color(0xFF1F263E);
  static const Color surface = Color(0xFF161B2E);
  static const Color surfaceLight = Color(0xFF222942);
  static const Color border = Color(0xFF2C3555);
  static const Color borderLight = Color(0xFF3F4C77);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFA0AEC0);
  static const Color textMuted = Color(0xFF64748B);
  static const Color accent = Color(0xFFD946EF); // Vibrant Neon Fuchsia/Magenta
  static const Color accentLight = Color(0xFFF0ABFC);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color gold = Color(0xFFFFD700);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  );

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        fontFamily: _fontFamily,
        scaffoldBackgroundColor: bg1,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: success,
          surface: surface,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
          ),
        ),
      );

  // Premium eye-catching glass card decoration
  static BoxDecoration glassCard({Color? glowColor}) => BoxDecoration(
        color: surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (glowColor ?? borderLight).withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          if (glowColor != null) ...[
            BoxShadow(
              color: glowColor.withValues(alpha: 0.18),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ],
      );

  // Eye-catching vibrant dark background gradients & artistic background
  static const boardBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B0F19),
      Color(0xFF14192B),
      Color(0xFF1B1B36),
    ],
  );

  static BoxDecoration artisticBackground() => const BoxDecoration(
        color: bg1,
        image: DecorationImage(
          image: AssetImage('assets/images/artistic_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.35,
        ),
      );

  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0B0F19),
      Color(0xFF161B2E),
      Color(0xFF0B0F19),
    ],
  );

  static BoxShadow playerGlow(Color color) => BoxShadow(
        color: color.withValues(alpha: 0.4),
        blurRadius: 16,
        spreadRadius: 2,
      );
}
