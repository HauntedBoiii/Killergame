import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) => ThemeNotifier());

class ThemeNotifier extends StateNotifier<bool> {
  static const _key = 'dark_mode';
  bool _isToggling = false;

  ThemeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    if (_isToggling) return;
    _isToggling = true;
    try {
      state = !state;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, state);
    } finally {
      _isToggling = false;
    }
  }
}
