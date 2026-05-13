import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.jungle,
        primary: AppColors.jungle,
        secondary: AppColors.fawn,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );

    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      displayLarge:  GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: AppColors.text),
      displayMedium: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: AppColors.text),
      headlineLarge: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.text),
      headlineMedium:GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.text),
      titleLarge:    GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.text),
      titleMedium:   GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.text),
      bodyLarge:     GoogleFonts.dmSans(color: AppColors.text),
      bodyMedium:    GoogleFonts.dmSans(color: AppColors.textMuted),
      bodySmall:     GoogleFonts.dmSans(color: AppColors.textMuted),
      labelLarge:    GoogleFonts.dmSans(fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,       // iOS: dark icons
          statusBarIconBrightness: Brightness.dark,    // Android: dark icons
        ),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.jungle,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.jungle,
          side: const BorderSide(color: AppColors.jungle),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.jungle, width: 2),
        ),
        labelStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
        hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadowColor.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.jungle,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
        highlightElevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.jungle : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.jungle.withValues(alpha: 0.4)
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.jungle : null,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1),
    );
  }
}
