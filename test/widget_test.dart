import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:swol/l10n/app_localizations.dart';
import 'package:swol/main.dart';

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.directory);

  final Directory directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory.path;
}

/// Boot-level tests only, and deliberately with empty storage: the home screen
/// pings every stored device on load, and dart_ping shells out to the real
/// `ping` binary, which a widget test must not wait on. Device rendering is
/// covered in test/widgets/device_card_test.dart instead.
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('swol_widget_test');
    PathProviderPlatform.instance = _TempPathProvider(temp);
    // adaptive_theme persists the selected mode through shared_preferences.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Widget buildApp() => MyApp(
    savedThemeMode: AdaptiveThemeMode.light,
    packageInfo: PackageInfo(
      appName: 'swol',
      packageName: 'dev.lcss.swol',
      version: '1.2.1',
      buildNumber: '1',
    ),
  );

  /// The home screen starts a 12s periodic ping timer, so `pumpAndSettle`
  /// would never return; pump a bounded number of frames instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(NavigationBar)))!;

  testWidgets('boots to the home screen with all three tabs', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a corrupt devices.json does not stop the app booting', (
    tester,
  ) async {
    // This used to escape loadDevices as an uncaught TypeError from initState.
    // Real file I/O has to leave the fake-async zone or it never completes.
    await tester.runAsync(
      () => File('${temp.path}/devices.json').writeAsString('{"not":"a list"}'),
    );

    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('navigates to Settings', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);
    final l10n = l10nOf(tester);

    await tester.tap(find.byIcon(Icons.settings).last);
    await settle(tester);

    expect(find.text(l10n.settingsAppearanceTitle), findsOneWidget);
    expect(find.text(l10n.settingsAppDataTitle), findsOneWidget);
  });

  testWidgets('About shows the version it was given', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tester.tap(find.byIcon(Icons.info).last);
    await settle(tester);

    expect(find.textContaining('1.2.1'), findsWidgets);
  });

  testWidgets('the add-device button opens the discover screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);
    final l10n = l10nOf(tester);

    await tester.tap(find.text(l10n.homeAddDeviceButton));
    await settle(tester);

    expect(find.text(l10n.discoverTitle), findsOneWidget);
  });

  testWidgets('theme mode survives switching to dark', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    final context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.light);

    AdaptiveTheme.of(context).setDark();
    await settle(tester);

    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );
  });
}
