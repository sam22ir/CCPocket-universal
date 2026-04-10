// ============================================================
// app_theme.dart — Design System من Stitch MCP
// ألوان مستخرجة مباشرة من Stitch project: 12077632945023875675
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Stitch Design Tokens
// ─────────────────────────────────────────────

class CCColors {
  // PRIMARY — Cyan
  static const primary           = Color(0xFFA4E6FF);
  static const primaryContainer  = Color(0xFF00D1FF);
  static const primaryFixed      = Color(0xFFB7EAFF);
  static const primaryFixedDim   = Color(0xFF4CD6FF);
  static const onPrimary         = Color(0xFF003543);
  static const onPrimaryContainer = Color(0xFF00566A);

  // SECONDARY — Purple
  static const secondary          = Color(0xFFF9ABFF);
  static const secondaryContainer = Color(0xFF86039C);
  static const onSecondary        = Color(0xFF570066);

  // TERTIARY — Amber/Yellow (tool cards)
  static const tertiary          = Color(0xFFFFD785);
  static const tertiaryContainer = Color(0xFFF3B600);
  static const onTertiary        = Color(0xFF402D00);
  static const onTertiaryContainer = Color(0xFF654A00);

  // SURFACE
  static const background            = Color(0xFF0D0D0F);
  static const surface               = Color(0xFF131315);
  static const surfaceContainer      = Color(0xFF201F21);
  static const surfaceContainerHigh  = Color(0xFF2A2A2C);
  static const surfaceContainerHighest = Color(0xFF353437);
  static const surfaceBright         = Color(0xFF39393B);
  static const surfaceVariant        = Color(0xFF353437);

  // ON SURFACE
  static const onSurface        = Color(0xFFE5E1E4);
  static const onSurfaceVariant = Color(0xFFBBC9CF);
  static const outline          = Color(0xFF859399);
  static const outlineVariant   = Color(0xFF3C494E);

  // ERROR
  static const error            = Color(0xFFFFB4AB);
  static const errorContainer   = Color(0xFF93000A);
  static const onError          = Color(0xFF690005);

  // SEMANTIC
  static const success          = Color(0xFF4CAF50);
  static const cyan             = Color(0xFF00D1FF);
  static const cyanGlow         = Color(0x2200D1FF);
  static const userBubbleStart  = Color(0xFF7B2FBE);
  static const userBubbleEnd    = Color(0xFF4A0D8C);

  // LIGHT MODE COLORS
  static const lightBackground         = Color(0xFFF5F9FA);
  static const lightSurface            = Color(0xFFFFFFFF);
  static const lightSurfaceContainer   = Color(0xFFEEF2F4);
  static const lightOnSurface          = Color(0xFF1A1C1E);
  static const lightOnSurfaceVariant   = Color(0xFF42484C);
  static const lightOutlineVariant     = Color(0xFFCDD7DD);

  // GRADIENTS
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF00D1FF), Color(0xFF4A0D8C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get userBubbleGradient => const LinearGradient(
    colors: [Color(0xFF7B2FBE), Color(0xFF4A0D8C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class CCSpacing {
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;
  static const double radius  = 8.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
}

// ─────────────────────────────────────────────
// ThemeData
// ─────────────────────────────────────────────

class CCTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: CCColors.background,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: CCColors.primary,
        primaryContainer: CCColors.primaryContainer,
        onPrimary: CCColors.onPrimary,
        onPrimaryContainer: CCColors.onPrimaryContainer,
        secondary: CCColors.secondary,
        secondaryContainer: CCColors.secondaryContainer,
        onSecondary: CCColors.onSecondary,
        tertiary: CCColors.tertiary,
        tertiaryContainer: CCColors.tertiaryContainer,
        onTertiary: CCColors.onTertiary,
        onTertiaryContainer: CCColors.onTertiaryContainer,
        surface: CCColors.surface,
        onSurface: CCColors.onSurface,
        onSurfaceVariant: CCColors.onSurfaceVariant,
        outline: CCColors.outline,
        outlineVariant: CCColors.outlineVariant,
        error: CCColors.error,
        onError: CCColors.onError,
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        GoogleFonts.interTextTheme(base.textTheme),
      ).apply(bodyColor: CCColors.onSurface, displayColor: CCColors.onSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: CCColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: CCColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: CCColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CCSpacing.radiusLg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CCColors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CCSpacing.radiusXl),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: CCSpacing.md, vertical: CCSpacing.sm),
        hintStyle: const TextStyle(color: CCColors.outline),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(CCColors.onSurfaceVariant),
        ),
      ),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: CCColors.lightBackground,
      colorScheme: ColorScheme.light(
        brightness: Brightness.light,
        primary: const Color(0xFF006783),
        primaryContainer: const Color(0xFFB7ECFF),
        onPrimary: Colors.white,
        secondary: const Color(0xFF7B2FBE),
        surface: CCColors.lightSurface,
        onSurface: CCColors.lightOnSurface,
        onSurfaceVariant: CCColors.lightOnSurfaceVariant,
        outline: const Color(0xFF72787C),
        outlineVariant: CCColors.lightOutlineVariant,
        error: const Color(0xFFBA1A1A),
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        GoogleFonts.interTextTheme(base.textTheme),
      ).apply(bodyColor: CCColors.lightOnSurface, displayColor: CCColors.lightOnSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: CCColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: CCColors.lightOnSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: CCColors.lightSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CCSpacing.radiusLg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CCColors.lightSurfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CCSpacing.radiusXl),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: CCSpacing.md, vertical: CCSpacing.sm),
      ),
    );
  }
}


