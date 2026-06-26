import 'package:flutter/material.dart';
import '../core/storage/secure_storage.dart';
import '../core/theme/app_colors.dart';

/// Controls light/dark mode app-wide. Because every screen reads colours
/// from [AppColors]'s static getters rather than `Theme.of(context)`,
/// flipping the mode here sets [AppColors.isDark] AND calls
/// notifyListeners — main.dart wraps the whole app in a
/// Consumer<ThemeProvider> so that single notification forces every
/// widget in the tree to rebuild and re-evaluate those getters fresh.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Reads the saved preference (if any) and applies it. Called once at
  /// app startup, before the first frame that matters visually.
  Future<void> loadSaved() async {
    final saved = await SecureStorage.instance.getThemeMode();
    if (saved == 'dark') {
      _mode = ThemeMode.dark;
      AppColors.isDark = true;
    } else {
      _mode = ThemeMode.light;
      AppColors.isDark = false;
    }
    notifyListeners();
  }

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    AppColors.isDark = dark;
    notifyListeners();
    await SecureStorage.instance.setThemeMode(dark ? 'dark' : 'light');
  }

  Future<void> toggle() => setDark(!isDark);
}
