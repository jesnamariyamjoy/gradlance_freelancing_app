import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false; // Default to Light Mode

  bool get isDark => _isDark;

  ThemeMode get themeMode =>
      _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme(bool value) {
    _isDark = value;
    notifyListeners();
  }
}
