import 'package:flutter/material.dart';

/// Palet warna Smart Campus Universitas Mulia:
/// biru tua kehitaman (dark navy) dengan aksen emas, seperti tampilan
/// website Biro Akademik Universitas Mulia.
class AppColors {
  const AppColors._();

  static const Color navy900 = Color(0xFF07101F); // paling gelap (header/footer)
  static const Color navy800 = Color(0xFF0B1D38); // kartu gelap & tabel
  static const Color navy700 = Color(0xFF123059); // tombol utama
  static const Color navy600 = Color(0xFF1B3F70); // hover / aksen
  static const Color gold = Color(0xFFFFC93C); // aksen emas
  static const Color goldLight = Color(0xFFFFE08A);
  static const Color teal = Color(0xFF22C1A4); // status berhasil
  static const Color danger = Color(0xFFE2574C);
  static const Color ink = Color(0xFF0D1B2A);
  static const Color muted = Color(0xFF5B6B80);
  static const Color line = Color(0xFFE3E8F0);
  static const Color bg = Color(0xFFF2F5FA);
  static const Color white = Color(0xFFFFFFFF);

  /// Gradien hero (biru tua kehitaman).
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[navy800, navy900],
  );

  /// Gradien footer emas.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[goldLight, gold],
  );
}

/// Tema aplikasi.
class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy700,
      primary: AppColors.navy700,
      secondary: AppColors.gold,
      surface: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy900,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navy900,
        indicatorColor: AppColors.navy700,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
              (Set<WidgetState> states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : const Color(0xFFA9C0DD),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
              (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : const Color(0xFFA9C0DD),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy700,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy700,
          side: const BorderSide(color: AppColors.navy700, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navy600, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF3FB),
        side: const BorderSide(color: Color(0xFFD5E0F2)),
        labelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.navy700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.navy800,
        contentTextStyle: TextStyle(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
