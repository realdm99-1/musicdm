import 'package:material_ui/material_ui.dart';

/// Element Plus inspired design tokens for Light and Dark modes.
class ElThemeTokens extends ThemeExtension<ElThemeTokens> {
  const ElThemeTokens({
    required this.primary,
    required this.bgColor,
    required this.bgColorPage,
    required this.textColorPrimary,
    required this.textColorRegular,
    required this.textColorSecondary,
    required this.borderColor,
    required this.successColor,
    required this.warningColor,
    required this.dangerColor,
  });

  final Color primary;
  final Color bgColor;
  final Color bgColorPage;
  final Color textColorPrimary;
  final Color textColorRegular;
  final Color textColorSecondary;
  final Color borderColor;
  final Color successColor;
  final Color warningColor;
  final Color dangerColor;

  static const double radiusCard = 8.0;
  static const double radiusButton = 4.0;
  static const double radiusThumbnail = 6.0;

  static const List<({String name, Color color})> accentPresets = [
    (name: 'Element Blue', color: Color(0xFF409EFF)),
    (name: 'Emerald', color: Color(0xFF67C23A)),
    (name: 'Amber', color: Color(0xFFE6A23C)),
    (name: 'Coral', color: Color(0xFFF56C6C)),
    (name: 'Purple', color: Color(0xFF8E44AD)),
  ];

  factory ElThemeTokens.light({Color primary = const Color(0xFF409EFF)}) {
    return ElThemeTokens(
      primary: primary,
      bgColor: const Color(0xFFFFFFFF),
      bgColorPage: const Color(0xFFF2F3F5),
      textColorPrimary: const Color(0xFF303133),
      textColorRegular: const Color(0xFF606266),
      textColorSecondary: const Color(0xFF909399),
      borderColor: const Color(0xFFDCDFE6),
      successColor: const Color(0xFF67C23A),
      warningColor: const Color(0xFFE6A23C),
      dangerColor: const Color(0xFFF56C6C),
    );
  }

  factory ElThemeTokens.dark({Color primary = const Color(0xFF409EFF)}) {
    return ElThemeTokens(
      primary: primary,
      bgColor: const Color(0xFF141414),
      bgColorPage: const Color(0xFF0A0A0A),
      textColorPrimary: const Color(0xFFE5EAF3),
      textColorRegular: const Color(0xFFCFD3DC),
      textColorSecondary: const Color(0xFFA3A6AD),
      borderColor: const Color(0xFF4C4D4F),
      successColor: const Color(0xFF67C23A),
      warningColor: const Color(0xFFE6A23C),
      dangerColor: const Color(0xFFF56C6C),
    );
  }

  @override
  ElThemeTokens copyWith({
    Color? primary,
    Color? bgColor,
    Color? bgColorPage,
    Color? textColorPrimary,
    Color? textColorRegular,
    Color? textColorSecondary,
    Color? borderColor,
    Color? successColor,
    Color? warningColor,
    Color? dangerColor,
  }) {
    return ElThemeTokens(
      primary: primary ?? this.primary,
      bgColor: bgColor ?? this.bgColor,
      bgColorPage: bgColorPage ?? this.bgColorPage,
      textColorPrimary: textColorPrimary ?? this.textColorPrimary,
      textColorRegular: textColorRegular ?? this.textColorRegular,
      textColorSecondary: textColorSecondary ?? this.textColorSecondary,
      borderColor: borderColor ?? this.borderColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      dangerColor: dangerColor ?? this.dangerColor,
    );
  }

  @override
  ElThemeTokens lerp(ThemeExtension<ElThemeTokens>? other, double t) {
    if (other is! ElThemeTokens) return this;
    return ElThemeTokens(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      bgColor: Color.lerp(bgColor, other.bgColor, t) ?? bgColor,
      bgColorPage: Color.lerp(bgColorPage, other.bgColorPage, t) ?? bgColorPage,
      textColorPrimary:
          Color.lerp(textColorPrimary, other.textColorPrimary, t) ??
          textColorPrimary,
      textColorRegular:
          Color.lerp(textColorRegular, other.textColorRegular, t) ??
          textColorRegular,
      textColorSecondary:
          Color.lerp(textColorSecondary, other.textColorSecondary, t) ??
          textColorSecondary,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
      successColor:
          Color.lerp(successColor, other.successColor, t) ?? successColor,
      warningColor:
          Color.lerp(warningColor, other.warningColor, t) ?? warningColor,
      dangerColor: Color.lerp(dangerColor, other.dangerColor, t) ?? dangerColor,
    );
  }
}

extension ElThemeBuildContext on BuildContext {
  ElThemeTokens get el =>
      Theme.of(this).extension<ElThemeTokens>() ?? ElThemeTokens.light();
}

ThemeData buildElThemeData({
  required Brightness brightness,
  required Color accentColor,
}) {
  final isDark = brightness == Brightness.dark;
  final tokens = isDark
      ? ElThemeTokens.dark(primary: accentColor)
      : ElThemeTokens.light(primary: accentColor);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: accentColor,
    brightness: brightness,
    primary: tokens.primary,
    surface: tokens.bgColor,
    error: tokens.dangerColor,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.bgColorPage,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.bgColor,
      foregroundColor: tokens.textColorPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: tokens.textColorPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      shape: Border(
        bottom: BorderSide(color: tokens.borderColor, width: 1),
      ),
    ),
    cardTheme: CardThemeData(
      color: tokens.bgColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ElThemeTokens.radiusCard),
        side: BorderSide(color: tokens.borderColor, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.bgColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ElThemeTokens.radiusCard),
        side: BorderSide(color: tokens.borderColor, width: 1),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.bgColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ElThemeTokens.radiusCard),
        ),
        side: BorderSide(color: tokens.borderColor, width: 1),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: tokens.borderColor,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElThemeTokens.radiusButton),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.textColorPrimary,
        side: BorderSide(color: tokens.borderColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElThemeTokens.radiusButton),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElThemeTokens.radiusButton),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.bgColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElThemeTokens.radiusButton),
        borderSide: BorderSide(color: tokens.borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElThemeTokens.radiusButton),
        borderSide: BorderSide(color: tokens.borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElThemeTokens.radiusButton),
        borderSide: BorderSide(color: tokens.primary, width: 1.5),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: tokens.primary,
      unselectedLabelColor: tokens.textColorRegular,
      indicatorColor: tokens.primary,
      dividerColor: tokens.borderColor,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: tokens.primary,
      inactiveTrackColor: tokens.borderColor,
      thumbColor: tokens.primary,
      overlayColor: tokens.primary.withValues(alpha: 0.16),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
  );
}
