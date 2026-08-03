import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app-wide [ThemeMode] and persists the user's choice.
class ThemeModeController extends Notifier<ThemeMode> {
  static const String _key = 'app.themeMode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? name = prefs.getString(_key);
    if (name == null) return;
    state = ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
