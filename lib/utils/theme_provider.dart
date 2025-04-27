import 'package:flutter/material.dart';

// 🌟 ThemeProvider to manage theme state across the app
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme

  // 📋 Getter for the current theme mode
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    // 📅 Initialize with system theme (can load from storage if needed)
    _themeMode = ThemeMode.system;
  }

  // 🎨 Set the theme mode and notify listeners to rebuild the UI
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}