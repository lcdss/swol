import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swol/services/data.dart';
import 'package:swol/services/widget_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);

          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  StorageDevice device({String id = 'id-1', String hostName = 'nas'}) =>
      StorageDevice(
        id: id,
        hostName: hostName,
        ipAddress: '192.168.1.10',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        modified: DateTime.utc(2026, 1, 2),
      );

  test('saves only what the widget renders, then redraws it', () async {
    await syncDevicesToWidget([device()]);

    final save = calls.singleWhere((call) => call.method == 'saveWidgetData');
    final payload = json.decode(save.arguments['data']) as List;

    expect(payload, [
      {'id': 'id-1', 'hostName': 'nas'},
    ]);
    expect(save.arguments['id'], 'devices');
    expect(calls.last.method, 'updateWidget');
  });

  test('falls back to the address when a device has no name', () async {
    await syncDevicesToWidget([device(hostName: '')]);

    final save = calls.singleWhere((call) => call.method == 'saveWidgetData');
    final payload = json.decode(save.arguments['data']) as List;

    expect((payload.single as Map)['hostName'], '192.168.1.10');
  });

  test('mirrors the list sorted the way the app shows it', () async {
    await syncDevicesToWidget([
      device(id: 'z', hostName: 'zeta'),
      device(id: 'a', hostName: 'Alpha'),
    ]);

    final save = calls.singleWhere((call) => call.method == 'saveWidgetData');
    final payload = json.decode(save.arguments['data']) as List;

    expect(payload.map((entry) => entry['hostName']), ['Alpha', 'zeta']);
  });

  test('survives the platform side being absent', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    await syncDevicesToWidget([device()]);
  });
}
