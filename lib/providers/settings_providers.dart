import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

// ─── Theme Mode ───

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      switch (value) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        default:
          state = ThemeMode.system;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

// ─── Font Size ───

enum FontSizePreference {
  small(AppStrings.fontSmall),
  medium(AppStrings.fontMedium),
  large(AppStrings.fontLarge);

  final String label;
  const FontSizePreference(this.label);
}

final fontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, FontSizePreference>(
      (ref) => FontSizeNotifier(),
    );

class FontSizeNotifier extends StateNotifier<FontSizePreference> {
  FontSizeNotifier() : super(FontSizePreference.medium) {
    _load();
  }

  static const _key = 'font_size';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = FontSizePreference.values.firstWhere(
        (e) => e.name == value,
        orElse: () => FontSizePreference.medium,
      );
    }
  }

  Future<void> setFontSize(FontSizePreference size) async {
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, size.name);
  }
}
