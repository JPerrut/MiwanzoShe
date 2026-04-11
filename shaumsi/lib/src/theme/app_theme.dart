import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _pearlWhite = Color(0xFFF8FDFF);
  static const Color _seaFoam = Color(0xFFE1F3FB);
  static const Color _lagoonBlue = Color(0xFF91D3EE);
  static const Color _tideBlue = Color(0xFF2F7FB8);
  static const Color _deepOcean = Color(0xFF0F3B59);

  static ThemeData get lightTheme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _tideBlue,
          primary: _tideBlue,
          secondary: _lagoonBlue,
          surface: _pearlWhite,
          brightness: Brightness.light,
        ).copyWith(
          primary: _tideBlue,
          onPrimary: Colors.white,
          secondary: _lagoonBlue,
          tertiary: _seaFoam,
          surface: _pearlWhite,
          onSurface: _deepOcean,
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
        foregroundColor: _deepOcean,
      ),
      cardTheme: CardThemeData(
        color: _pearlWhite.withValues(alpha: 0.84),
        shadowColor: _deepOcean.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _tideBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _deepOcean,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _pearlWhite.withValues(alpha: 0.92),
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
          borderSide: BorderSide(color: _tideBlue.withValues(alpha: 0.55)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _pearlWhite.withValues(alpha: 0.9),
        indicatorColor: _seaFoam,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _deepOcean);
          }
          return IconThemeData(color: _deepOcean.withValues(alpha: 0.65));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _deepOcean,
            );
          }

          return GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _deepOcean.withValues(alpha: 0.65),
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _deepOcean,
        contentTextStyle: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: const [
        ShauMsiColors(
          pearlWhite: _pearlWhite,
          seaFoam: _seaFoam,
          lagoonBlue: _lagoonBlue,
          tideBlue: _tideBlue,
          deepOcean: _deepOcean,
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
        color: _deepOcean,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: _deepOcean,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _deepOcean,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _deepOcean,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        height: 1.45,
        color: _deepOcean,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        height: 1.45,
        color: _deepOcean.withValues(alpha: 0.9),
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _deepOcean,
      ),
    );
  }
}

@immutable
class ShauMsiColors extends ThemeExtension<ShauMsiColors> {
  const ShauMsiColors({
    required this.pearlWhite,
    required this.seaFoam,
    required this.lagoonBlue,
    required this.tideBlue,
    required this.deepOcean,
  });

  final Color pearlWhite;
  final Color seaFoam;
  final Color lagoonBlue;
  final Color tideBlue;
  final Color deepOcean;

  @override
  ThemeExtension<ShauMsiColors> copyWith({
    Color? pearlWhite,
    Color? seaFoam,
    Color? lagoonBlue,
    Color? tideBlue,
    Color? deepOcean,
  }) {
    return ShauMsiColors(
      pearlWhite: pearlWhite ?? this.pearlWhite,
      seaFoam: seaFoam ?? this.seaFoam,
      lagoonBlue: lagoonBlue ?? this.lagoonBlue,
      tideBlue: tideBlue ?? this.tideBlue,
      deepOcean: deepOcean ?? this.deepOcean,
    );
  }

  @override
  ThemeExtension<ShauMsiColors> lerp(
    covariant ThemeExtension<ShauMsiColors>? other,
    double t,
  ) {
    if (other is! ShauMsiColors) {
      return this;
    }

    return ShauMsiColors(
      pearlWhite: Color.lerp(pearlWhite, other.pearlWhite, t) ?? pearlWhite,
      seaFoam: Color.lerp(seaFoam, other.seaFoam, t) ?? seaFoam,
      lagoonBlue: Color.lerp(lagoonBlue, other.lagoonBlue, t) ?? lagoonBlue,
      tideBlue: Color.lerp(tideBlue, other.tideBlue, t) ?? tideBlue,
      deepOcean: Color.lerp(deepOcean, other.deepOcean, t) ?? deepOcean,
    );
  }
}

extension ShauMsiThemeContext on BuildContext {
  ShauMsiColors get shaumsiColors => Theme.of(this).extension<ShauMsiColors>()!;
}
