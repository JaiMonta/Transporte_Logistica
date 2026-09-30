import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens del sistema de diseño (alto contraste utilitario).
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF3C5AA0);
  static const Color primaryContainer = Color(0xFF5673BB);
  static const Color secondary = Color(0xFF865223);
  static const Color secondaryContainer = Color(0xFFFDB880);
  static const Color tertiary = Color(0xFF00694F);
  static const Color tertiaryContainer = Color(0xFF008565);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  static const Color surface = Color(0xFFFAF8FF);
  static const Color onSurface = Color(0xFF1A1B20);
  static const Color onSurfaceVariant = Color(0xFF444651);
  static const Color outline = Color(0xFF747782);
  static const Color outlineVariant = Color(0xFFC4C6D2);

  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFEEEDF4);
  static const Color surfaceContainerHigh = Color(0xFFE8E7EE);

  static const Color bordeCampo = Color(0xFFCBD5E1);

  /// Verde para estados positivos (activo/aprobado).
  static const Color exito = Color(0xFF2FB58D);

  /// Rojo de peligro (inactivo/rechazado).
  static const Color peligro = Color(0xFFDC2626);
}

/// Espaciados base (en píxeles lógicos).
class AppSpacing {
  const AppSpacing._();

  static const double xs = 6;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double margen = 16;
  static const double alturaControl = 56;
}

/// Radios base.
class AppRadius {
  const AppRadius._();

  static const double sm = 4;
  static const double base = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    final scheme = base.copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: const Color(0xFF2E1500),
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: const Color(0xFF410002),
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: _textTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        constraints: const BoxConstraints(minHeight: AppSpacing.alturaControl),
        border: _campoBorde(AppColors.bordeCampo),
        enabledBorder: _campoBorde(AppColors.bordeCampo),
        focusedBorder: _campoBorde(AppColors.primary),
        errorBorder: _campoBorde(AppColors.error),
        focusedErrorBorder: _campoBorde(AppColors.error),
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.alturaControl),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.outlineVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.alturaControl),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outlineVariant, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.outlineVariant, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.onSurface,
        contentTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
      ),
    );
  }

  static OutlineInputBorder _campoBorde(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.base),
        borderSide: BorderSide(color: color, width: 2),
      );

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      bodyLarge: GoogleFonts.hankenGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      ),
      bodyMedium: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      ),
      bodySmall: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      labelMedium: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      labelSmall: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}
