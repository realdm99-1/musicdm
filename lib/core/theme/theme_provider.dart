import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'el_theme.dart';

const _kThemeModeKey = 'musicdm_theme_mode';
const _kAccentColorKey = 'musicdm_accent_color';

class ThemeSettings {
  const ThemeSettings({
    required this.themeMode,
    required this.accentColor,
  });

  final ThemeMode themeMode;
  final Color accentColor;

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

class ThemeController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() {
    _loadSaved();
    return const ThemeSettings(
      themeMode: ThemeMode.light,
      accentColor: Color(0xFF409EFF),
    );
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_kThemeModeKey);
    final accentValue = prefs.getInt(_kAccentColorKey);

    final savedMode = (modeIndex != null &&
            modeIndex >= 0 &&
            modeIndex < ThemeMode.values.length)
        ? ThemeMode.values[modeIndex]
        : ThemeMode.light;

    state = ThemeSettings(
      themeMode: savedMode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
      accentColor: accentValue != null
          ? Color(accentValue)
          : ElThemeTokens.accentPresets.first.color,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, mode.index);
  }

  Future<void> setAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentColorKey, color.toARGB32());
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);
