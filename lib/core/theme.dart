import 'package:flutter/material.dart';

import 'botanical.dart';

/// Material 3 green agricultural theme (PRD Phase 1), restyled to the dark
/// "botanical" reference: near-black green gradient surfaces, lime accents,
/// pill buttons. Light theme stays a clean M3 green for the Dark Mode off
/// state (FR-14).
class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFF2E7D32); // deep agricultural green

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52), // large tap targets (NFR-6)
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: BotanicalColors.accent,
          onPrimary: const Color(0xFF12250F),
          secondary: BotanicalColors.accent,
          surface: BotanicalColors.bgTop,
          onSurface: BotanicalColors.textPrimary,
          surfaceContainerHighest: const Color(0xFF1B3524),
          onSurfaceVariant: BotanicalColors.textSecondary,
          outlineVariant: BotanicalColors.cardBorder,
        ),
        scaffoldBackgroundColor: BotanicalColors.bgBottom,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: BotanicalColors.textPrimary,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF132A1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: BotanicalColors.cardBorder),
          ),
        ),
        dividerTheme: DividerThemeData(color: BotanicalColors.cardBorder),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: const StadiumBorder(),
            backgroundColor: BotanicalColors.accentDeep,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: const StadiumBorder(),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
            foregroundColor: BotanicalColors.textPrimary,
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return const Color(0xFF9DB5A1);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BotanicalColors.accentDeep;
            }
            return const Color(0xFF2A4434);
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF152B1C),
          selectedColor: BotanicalColors.accent,
          checkmarkColor: const Color(0xFF12250F),
          labelStyle: const TextStyle(
            color: BotanicalColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          secondaryLabelStyle: const TextStyle(
            color: Color(0xFF12250F),
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide(color: BotanicalColors.cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: BotanicalColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
          bodyLarge: TextStyle(color: BotanicalColors.textPrimary),
          bodyMedium: TextStyle(color: BotanicalColors.textSecondary),
        ),
      );
}
