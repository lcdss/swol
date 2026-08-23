import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:swol/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:swol/constants.dart';
import 'package:swol/screens/about/about.dart';
import 'package:swol/screens/home/home.dart';
import 'package:swol/screens/settings/settings.dart';
import 'package:swol/services/theme_settings.dart';
import 'package:swol/services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get saved theme mode
  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  await loadThemeSettings();
  await registerWidgetInteractivity();

  // Get package info
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  runApp(MyApp(savedThemeMode: savedThemeMode, packageInfo: packageInfo));
}

class MyApp extends StatelessWidget {
  final AdaptiveThemeMode? savedThemeMode;
  final PackageInfo packageInfo;
  const MyApp({
    super.key,
    required this.savedThemeMode,
    required this.packageInfo,
  });

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) =>
          ValueListenableBuilder<bool>(
            valueListenable: useDynamicColor,
            builder: (context, dynamicOn, _) {
              final lightScheme = dynamicOn && lightDynamic != null
                  ? lightDynamic
                  : ColorScheme.fromSeed(seedColor: AppConstants.seedColor);
              final darkScheme = dynamicOn && darkDynamic != null
                  ? darkDynamic
                  : ColorScheme.fromSeed(
                      seedColor: AppConstants.seedColor,
                      brightness: Brightness.dark,
                    );

              return AdaptiveTheme(
                light: ThemeData(colorScheme: lightScheme),
                dark: ThemeData(colorScheme: darkScheme),
                initial: savedThemeMode ?? AdaptiveThemeMode.system,
                builder: (ThemeData light, ThemeData dark) => MaterialApp(
                  onGenerateTitle: (context) =>
                      AppLocalizations.of(context)!.appTitle,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  supportedLocales: const [
                    Locale('en'), // English
                  ],
                  theme: light,
                  darkTheme: dark,
                  home: MyHomePage(packageInfo: packageInfo),
                ),
              );
            },
          ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.packageInfo});
  final PackageInfo packageInfo;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // current selected navigation index
  int selectedNavigationIndex = 0;

  // values from homePage which should be stored in memory while the app is running
  SortingOrder selectedMenu = SortingOrder.alphabetical;
  List<bool> deviceTypesValues = List<bool>.filled(
    AppConstants.deviceTypeIcons.length,
    true,
  );

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomePage(
        title: AppLocalizations.of(context)!.homePageTitle,
        onSelectedMenuChange: (SortingOrder order) {
          setState(() {
            selectedMenu = order;
          });
        },
        selectedMenu: selectedMenu,
        onSelectedDeviceTypesChange: (List<bool> values) {
          setState(() {
            deviceTypesValues = values;
          });
        },
        deviceTypesValues: deviceTypesValues,
      ),
      SettingsPage(title: AppLocalizations.of(context)!.settingsPageTitle),
      AboutPage(
        title: AppLocalizations.of(context)!.aboutPageTitle,
        packageInfo: widget.packageInfo,
      ),
    ];
    // Icons have to contrast with the surface behind them, so they invert
    // relative to the theme's own brightness.
    final overlayIconBrightness =
        Theme.of(context).brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: overlayIconBrightness,
        systemNavigationBarIconBrightness: overlayIconBrightness,
      ),
      child: Scaffold(
        body: screens[selectedNavigationIndex],
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (int index) {
            setState(() {
              selectedNavigationIndex = index;
            });
          },
          selectedIndex: selectedNavigationIndex,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            NavigationDestination(
              icon: const Icon(AppConstants.homeIcon),
              label: AppLocalizations.of(context)!.homePageLabel,
            ),
            NavigationDestination(
              icon: const Icon(AppConstants.settingsIcon),
              label: AppLocalizations.of(context)!.settingsPageTitle,
            ),
            NavigationDestination(
              icon: const Icon(AppConstants.aboutIcon),
              label: AppLocalizations.of(context)!.aboutPageTitle,
            ),
          ],
        ),
      ),
    );
  }
}
