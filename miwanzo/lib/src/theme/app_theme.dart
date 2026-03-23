import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _eggShell = Color(0xFFF5EEDD);
  static const Color _mistRose = Color(0xFFF7DCE6);
  static const Color _indigoNight = Color(0xFF2D3354);
  static const Color _deepLavender = Color(0xFF7469B6);
  static const Color _powderBlue = Color(0xFFAAC6D5);

  static ThemeData get lightTheme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _deepLavender,
          primary: _deepLavender,
          secondary: _powderBlue,
          surface: Colors.white,
          brightness: Brightness.light,
        ).copyWith(
          primary: _deepLavender,
          secondary: _powderBlue,
          tertiary: _mistRose,
          surface: Colors.white,
          onSurface: _indigoNight,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _indigoNight,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.82),
        shadowColor: _indigoNight.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _deepLavender.withValues(alpha: 0.6)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _indigoNight);
          }
          return IconThemeData(color: _indigoNight.withValues(alpha: 0.65));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _indigoNight,
            );
          }

          return GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _indigoNight.withValues(alpha: 0.65),
          );
        }),
      ),
      extensions: const [
        MiwanzoColors(
          eggShell: _eggShell,
          mistRose: _mistRose,
          indigoNight: _indigoNight,
          deepLavender: _deepLavender,
          powderBlue: _powderBlue,
        ),
      ],
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.dmSansTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 36,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: _indigoNight,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: _indigoNight,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _indigoNight,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _indigoNight,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        height: 1.45,
        color: _indigoNight,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        height: 1.45,
        color: _indigoNight.withValues(alpha: 0.9),
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _indigoNight,
      ),
    );
  }
}

@immutable
class MiwanzoColors extends ThemeExtension<MiwanzoColors> {
  const MiwanzoColors({
    required this.eggShell,
    required this.mistRose,
    required this.indigoNight,
    required this.deepLavender,
    required this.powderBlue,
  });

  final Color eggShell;
  final Color mistRose;
  final Color indigoNight;
  final Color deepLavender;
  final Color powderBlue;

  @override
  ThemeExtension<MiwanzoColors> copyWith({
    Color? eggShell,
    Color? mistRose,
    Color? indigoNight,
    Color? deepLavender,
    Color? powderBlue,
  }) {
    return MiwanzoColors(
      eggShell: eggShell ?? this.eggShell,
      mistRose: mistRose ?? this.mistRose,
      indigoNight: indigoNight ?? this.indigoNight,
      deepLavender: deepLavender ?? this.deepLavender,
      powderBlue: powderBlue ?? this.powderBlue,
    );
  }

  @override
  ThemeExtension<MiwanzoColors> lerp(
    covariant ThemeExtension<MiwanzoColors>? other,
    double t,
  ) {
    if (other is! MiwanzoColors) {
      return this;
    }

    return MiwanzoColors(
      eggShell: Color.lerp(eggShell, other.eggShell, t) ?? eggShell,
      mistRose: Color.lerp(mistRose, other.mistRose, t) ?? mistRose,
      indigoNight: Color.lerp(indigoNight, other.indigoNight, t) ?? indigoNight,
      deepLavender:
          Color.lerp(deepLavender, other.deepLavender, t) ?? deepLavender,
      powderBlue: Color.lerp(powderBlue, other.powderBlue, t) ?? powderBlue,
    );
  }
}

extension MiwanzoThemeContext on BuildContext {
  MiwanzoColors get miwanzoColors => Theme.of(this).extension<MiwanzoColors>()!;
}
