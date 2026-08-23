import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:swol/l10n/app_localizations.dart';
import 'package:swol/screens/home/bottom_sheet_form.dart';
import 'package:swol/services/data.dart';

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.directory);

  final Directory directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory.path;
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('swol_form_test');
    PathProviderPlatform.instance = _TempPathProvider(temp);
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  Future<AppLocalizations> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      app(
        NetworkDeviceFormPage(
          title: 'Add device',
          device: NetworkDevice(),
          devices: const [],
          onSubmitDeviceCallback: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    return AppLocalizations.of(
      tester.element(find.byType(TextFormField).first),
    )!;
  }

  testWidgets('opens with no validation errors before any interaction', (
    tester,
  ) async {
    // Regression: AutovalidateMode.always painted every field red on open,
    // and the port chips called validate() during build, which did the same.
    final l10n = await pumpForm(tester);

    expect(find.text(l10n.formNameError), findsNothing);
    expect(find.text(l10n.formIpError), findsNothing);
    expect(find.text(l10n.formMacError), findsNothing);
    expect(find.text(l10n.formPortError), findsNothing);
  });

  testWidgets('saving an empty form lists every invalid field', (tester) async {
    final l10n = await pumpForm(tester);

    await tester.tap(find.text(l10n.formApplyButtonText));
    await tester.pumpAndSettle();

    // Scoped to the dialog: the field's own error text can share the same
    // string.
    Finder inDialog(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );

    expect(inDialog(l10n.formErrorMessageName), findsOneWidget);
    expect(inDialog(l10n.formErrorMessageIp), findsOneWidget);
    expect(inDialog(l10n.formErrorMessageMac), findsOneWidget);
    expect(inDialog(l10n.formErrorMessagePort), findsOneWidget);
    expect(inDialog(l10n.formErrorMessageType), findsOneWidget);
  });

  testWidgets('validates as the user types into a field', (tester) async {
    final l10n = await pumpForm(tester);

    // The IP field is the second TextFormField (name comes first).
    await tester.enterText(find.byType(TextFormField).at(1), '999.1.1.1');
    await tester.pumpAndSettle();

    expect(find.text(l10n.formIpError), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.10');
    await tester.pumpAndSettle();

    expect(find.text(l10n.formIpError), findsNothing);
  });
}
