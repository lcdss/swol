import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:swol/constants.dart';

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

/// The themes the app runs with: the wallpaper palette when available and
/// enabled, the seed palette otherwise. Single source for the startup
/// AdaptiveTheme config and the Settings toggle's runtime setTheme call.
ThemeData appLightTheme(bool dynamicOn) => ThemeData(
  colorScheme: dynamicOn && lightDynamicScheme != null
      ? lightDynamicScheme!
      : ColorScheme.fromSeed(seedColor: AppConstants.seedColor),
);

ThemeData appDarkTheme(bool dynamicOn) => ThemeData(
  colorScheme: dynamicOn && darkDynamicScheme != null
      ? darkDynamicScheme!
      : ColorScheme.fromSeed(
          seedColor: AppConstants.seedColor,
          brightness: Brightness.dark,
        ),
);

Future<void> setUseDynamicColor(bool value) async {
  useDynamicColor.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_useDynamicColorKey, value);
}
