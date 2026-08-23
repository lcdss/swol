import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:swol/constants.dart';
import 'package:swol/widgets/layout_elements.dart';
import 'package:swol/widgets/universal_ui_components.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, DeviceCard card) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));

  group('DeviceCard', () {
    testWidgets('shows the host name and address', (tester) async {
      await pumpCard(
        tester,
        const DeviceCard(
          title: 'my-nas',
          subtitle: '192.168.1.10',
          deviceType: 'server',
        ),
      );

      expect(find.text('my-nas'), findsOneWidget);
      expect(find.text('192.168.1.10'), findsOneWidget);
    });

    testWidgets('draws the icon for the device type', (tester) async {
      await pumpCard(
        tester,
        const DeviceCard(title: 'my-nas', deviceType: 'printer'),
      );

      expect(find.byIcon(Icons.print_rounded), findsOneWidget);
    });

    testWidgets('draws no type icon when the type is unknown', (tester) async {
      await pumpCard(
        tester,
        const DeviceCard(title: 'my-nas', deviceType: 'not-a-type'),
      );

      expect(find.byIcon(Icons.print_rounded), findsNothing);
      expect(find.text('my-nas'), findsOneWidget);
    });

    testWidgets('reports taps', (tester) async {
      var taps = 0;
      await pumpCard(tester, DeviceCard(title: 'my-nas', onTap: () => taps++));

      await tester.tap(find.text('my-nas'));
      expect(taps, 1);
    });

    testWidgets('renders for online, offline and unknown status', (
      tester,
    ) async {
      for (final status in <bool?>[true, false, null]) {
        await pumpCard(
          tester,
          DeviceCard(title: 'my-nas', deviceType: 'server', isOnline: status),
        );

        expect(tester.takeException(), isNull, reason: 'isOnline: $status');
        expect(find.text('my-nas'), findsOneWidget);
      }
    });

    testWidgets('shows its trailing widget', (tester) async {
      await pumpCard(
        tester,
        const DeviceCard(
          title: 'my-nas',
          trailing: Icon(Icons.power_settings_new_outlined),
        ),
      );

      expect(find.byIcon(Icons.power_settings_new_outlined), findsOneWidget);
    });
  });

  group('getIcon', () {
    test('maps every configured device type to an icon', () {
      for (final type in AppConstants.deviceTypeIcons.keys) {
        expect(getIcon(type), isNotNull, reason: type);
      }
    });

    test('returns null for an unknown or absent type', () {
      expect(getIcon('not-a-type'), isNull);
      expect(getIcon(null), isNull);
    });

    test('agrees with the chip list it is derived from', () {
      for (final chip in AppConstants.getChipsDeviceTypes()) {
        expect(getIcon(chip.value), chip.icon, reason: chip.value);
      }
    });
  });

  group('TextTitle', () {
    testWidgets('does not mutate the children list it is given', (
      tester,
    ) async {
      // It used to insert spacers into this list on every build, which throws
      // on a const list and accumulates spacers across rebuilds.
      const children = [Text('a'), Text('b'), Text('c')];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextTitle(title: 'Section', children: children),
          ),
        ),
      );
      await tester.pump();

      expect(children, hasLength(3));
      expect(find.text('a'), findsOneWidget);
      expect(find.text('Section'), findsOneWidget);
    });
  });

  group('SpacedRow', () {
    testWidgets('does not mutate the children list it is given', (
      tester,
    ) async {
      const children = [Text('left'), Text('right')];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SpacedRow(children: children)),
        ),
      );
      await tester.pump();

      expect(children, hasLength(2));
      expect(find.text('left'), findsOneWidget);
      expect(find.text('right'), findsOneWidget);
    });
  });
}
