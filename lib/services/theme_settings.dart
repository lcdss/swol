import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the app follows the system's Material You palette. A global
/// notifier so the running MaterialApp rebuilds when Settings flips it.
final useDynamicColor = ValueNotifier<bool>(true);

const _useDynamicColorKey = 'useDynamicColor';

Future<void> loadThemeSettings() async {
  final prefs = await SharedPreferences.getInstance();

  useDynamicColor.value = prefs.getBool(_useDynamicColorKey) ?? true;
}

Future<void> setUseDynamicColor(bool value) async {
  useDynamicColor.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_useDynamicColorKey, value);
}
