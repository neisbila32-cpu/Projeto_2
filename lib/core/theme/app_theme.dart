import 'package:flutter/material.dart';

/// Tema visual do app: azul bebê, cantos arredondados, aparência minimalista.
class AppTheme {
  AppTheme._();

  static const Color _azul = Color(0xFF2570A8);

  static final ColorScheme _esquemaClaro = ColorScheme.fromSeed(
    seedColor: _azul,
    brightness: Brightness.light,
  ).copyWith(
    primary: _azul,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE3F1FB),
    onPrimaryContainer: const Color(0xFF1D5C8C),
    secondary: const Color(0xFF5A6874),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE3F1FB),
    onSecondaryContainer: const Color(0xFF1D5C8C),
    tertiary: const Color(0xFF9A4A2E),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFF6E7DF),
    onTertiaryContainer: const Color(0xFF6E3320),
    surface: const Color(0xFFF6F9FC),
    onSurface: const Color(0xFF1B2530),
    onSurfaceVariant: const Color(0xFF5A6874),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF1F5F9),
    surfaceContainer: const Color(0xFFEDF2F6),
    surfaceContainerHigh: const Color(0xFFE9EFF4),
    surfaceContainerHighest: const Color(0xFFE9EFF4),
    outline: const Color(0xFF8795A1),
    outlineVariant: const Color(0xFFE1E9EF),
  );

  static final ColorScheme _esquemaEscuro = ColorScheme.fromSeed(
    seedColor: _azul,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF8CC4EE),
    onPrimary: const Color(0xFF0A3555),
    primaryContainer: const Color(0xFF1D4F77),
    onPrimaryContainer: const Color(0xFFD6EBFB),
    secondary: const Color(0xFFA9B6C2),
    onSecondary: const Color(0xFF1B2530),
    secondaryContainer: const Color(0xFF1D4F77),
    onSecondaryContainer: const Color(0xFFD6EBFB),
    tertiary: const Color(0xFFE6A68C),
    onTertiary: const Color(0xFF4A2314),
    tertiaryContainer: const Color(0xFF5A2E1E),
    onTertiaryContainer: const Color(0xFFF6E7DF),
    surface: const Color(0xFF0F1720),
    onSurface: const Color(0xFFE4EAF0),
    onSurfaceVariant: const Color(0xFFA9B6C2),
    surfaceContainerLowest: const Color(0xFF0B1219),
    surfaceContainerLow: const Color(0xFF131C26),
    surfaceContainer: const Color(0xFF17212B),
    surfaceContainerHigh: const Color(0xFF1C2733),
    surfaceContainerHighest: const Color(0xFF222E3B),
    outline: const Color(0xFF6B7B89),
    outlineVariant: const Color(0xFF2A3641),
  );

  static final ThemeData lightTheme =
      _construir(_esquemaClaro, cartao: _esquemaClaro.surfaceContainerLowest);

  static final ThemeData darkTheme =
      _construir(_esquemaEscuro, cartao: _esquemaEscuro.surfaceContainer);

  static ThemeData _construir(ColorScheme cs, {required Color cartao}) {
    final campo = cs.surfaceContainerHigh;
    const pilula = StadiumBorder();
    const textoBotao = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    OutlineInputBorder bordaCampo(Color cor, double largura) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: largura == 0
              ? BorderSide.none
              : BorderSide(color: cor, width: largura),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: cs.brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cartao,
        elevation: 1,
        shadowColor: cs.shadow.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: campo,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: bordaCampo(cs.outlineVariant, 0),
        enabledBorder: bordaCampo(cs.outlineVariant, 0),
        disabledBorder: bordaCampo(cs.outlineVariant, 0),
        focusedBorder: bordaCampo(cs.primary, 1.5),
        errorBorder: bordaCampo(cs.error, 1),
        focusedErrorBorder: bordaCampo(cs.error, 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pilula,
          textStyle: textoBotao,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pilula,
          textStyle: textoBotao,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pilula,
          side: BorderSide(color: cs.outlineVariant),
          textStyle: textoBotao,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pilula,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 3,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: pilula,
      ),
      chipTheme: ChipThemeData(
        shape: pilula,
        side: BorderSide.none,
        showCheckmark: false,
        backgroundColor: cs.surfaceContainerHigh,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        selectedTileColor: cs.primaryContainer,
        selectedColor: cs.onPrimaryContainer,
        iconColor: cs.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
