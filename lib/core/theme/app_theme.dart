import 'package:flutter/material.dart';

/// Every surface colour the app needs, in one place so light and night stay in
/// sync. Widgets read it through [ZovvThemeX.palette].
@immutable
class ZovvPalette extends ThemeExtension<ZovvPalette> {
  const ZovvPalette({
    required this.canvas,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBorder,
    required this.glassShadow,
    required this.isDark,
  });
  final Color canvas;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;

  /// Flat glass: the refit keeps gradients tight and shadows almost invisible.
  final Color glassTop;
  final Color glassBottom;
  final Color glassBorder;
  final Color glassShadow;
  final bool isDark;

  static const light = ZovvPalette(
    canvas: Color(0xFFF7F8FB),
    ink: Color(0xFF1C1E24),
    muted: Color(0xFF7E838F),
    line: Color(0xFFE6E9F1),
    accent: Color(0xFF6F86D8),
    glassTop: Color(0xEFFFFFFF),
    glassBottom: Color(0xA6FFFFFF),
    glassBorder: Color(0xE6FFFFFF),
    glassShadow: Color(0xFF5B6B92),
    isDark: false,
  );

  static const dark = ZovvPalette(
    canvas: Color(0xFF0B0C10),
    ink: Color(0xFFF1F2F7),
    muted: Color(0xFF8B91A0),
    line: Color(0xFF23262E),
    accent: Color(0xFF93A9F2),
    glassTop: Color(0xF21C2027),
    glassBottom: Color(0xE612151A),
    glassBorder: Color(0x24FFFFFF),
    glassShadow: Color(0xFF000000),
    isDark: true,
  );

  static ZovvPalette of(BuildContext context) =>
      Theme.of(context).extension<ZovvPalette>() ?? light;

  @override
  ZovvPalette copyWith({
    Color? canvas,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? glassTop,
    Color? glassBottom,
    Color? glassBorder,
    Color? glassShadow,
    bool? isDark,
  }) => ZovvPalette(
    canvas: canvas ?? this.canvas,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    accent: accent ?? this.accent,
    glassTop: glassTop ?? this.glassTop,
    glassBottom: glassBottom ?? this.glassBottom,
    glassBorder: glassBorder ?? this.glassBorder,
    glassShadow: glassShadow ?? this.glassShadow,
    isDark: isDark ?? this.isDark,
  );

  @override
  ZovvPalette lerp(ThemeExtension<ZovvPalette>? other, double t) {
    if (other is! ZovvPalette) return this;
    return ZovvPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      glassTop: Color.lerp(glassTop, other.glassTop, t)!,
      glassBottom: Color.lerp(glassBottom, other.glassBottom, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      isDark: t < .5 ? isDark : other.isDark,
    );
  }
}

extension ZovvThemeX on BuildContext {
  ZovvPalette get palette => ZovvPalette.of(this);
}

abstract final class AppColors {
  /// Playback is always dark, independent of the app theme.
  static const night = Color(0xFF08090A);

  /// Fixed accent for controls that live on the always-dark player surface.
  static const accent = Color(0xFF7C93E4);
}

abstract final class AppTheme {
  static ThemeData get light => _build(ZovvPalette.light);
  static ThemeData get dark => _build(ZovvPalette.dark);

  static ThemeData _build(ZovvPalette palette) => ThemeData(
    useMaterial3: true,
    brightness: palette.isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: palette.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: palette.isDark ? Brightness.dark : Brightness.light,
      surface: palette.canvas,
      onSurface: palette.ink,
    ),
    fontFamily: 'sans-serif',
    textTheme: TextTheme(bodyMedium: TextStyle(color: palette.ink)),
    extensions: [palette],
    splashFactory: NoSplash.splashFactory,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.ink,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.ink,
        backgroundColor: palette.glassBottom,
        side: BorderSide(color: palette.glassBorder, width: .7),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(color: palette.canvas, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
  );
}
