import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enum matching system options
enum AppThemeMode { light, dark, system }

/// Provider for theme mode state
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.light) {
    _load();
  }

  static const _key = 'app_theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case 'dark':
        state = AppThemeMode.dark;
        break;
      case 'system':
        state = AppThemeMode.system;
        break;
      default:
        state = AppThemeMode.light;
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Resets theme to default (light) and clears stored preference.
  /// Called on logout to prevent theme leaking between users.
  Future<void> resetToDefault() async {
    state = AppThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Convert AppThemeMode to Flutter ThemeMode
ThemeMode toFlutterThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}
