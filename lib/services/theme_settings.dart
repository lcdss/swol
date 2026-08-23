import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the app follows the system's Material You palette. A global
/// notifier so the running MaterialApp rebuilds when Settings flips it.
final useDynamicColor = ValueNotifier<bool>(true);

/// The wallpaper-derived schemes, resolved once before the first frame; null
/// on devices without Material You (pre-Android 12).
ColorScheme? lightDynamicScheme;
ColorScheme? darkDynamicScheme;

/// Settings hides the System Colors switch when there is nothing to switch to.
bool get dynamicColorSupported => lightDynamicScheme != null;

const _useDynamicColorKey = 'useDynamicColor';

Future<void> loadThemeSettings() async {
  final prefs = await SharedPreferences.getInstance();

  useDynamicColor.value = prefs.getBool(_useDynamicColorKey) ?? true;

  try {
    final corePalette = await DynamicColorPlugin.getCorePalette();
    lightDynamicScheme = corePalette?.toColorScheme();
    darkDynamicScheme = corePalette?.toColorScheme(brightness: Brightness.dark);
  } catch (_) {
    // No plugin (tests, desktop) or no palette: the seed fallback covers it.
  }
}

Future<void> setUseDynamicColor(bool value) async {
  useDynamicColor.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_useDynamicColorKey, value);
}
