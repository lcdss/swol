import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:swol/services/data.dart';
import 'package:swol/services/database.dart';

/// Points path_provider at a real temporary directory so DeviceStorage can be
/// exercised end to end without a platform channel.
class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.directory);

  final Directory directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory.path;
}

StorageDevice device({
  String id = 'id-1',
  String hostName = 'nas',
  String ipAddress = '192.168.1.10',
}) => StorageDevice(
  id: id,
  hostName: hostName,
  ipAddress: ipAddress,
  macAddress: 'AA:BB:CC:DD:EE:FF',
  wolPort: 9,
  deviceType: 'server',
  modified: DateTime.utc(2026, 1, 1),
);

void main() {
  group('parseStorageDevices', () {
    test('reads a well-formed list', () {
      final devices = parseStorageDevices(
        json.encode([device(id: 'a').toJson(), device(id: 'b').toJson()]),
      );

      expect(devices.map((d) => d.id), ['a', 'b']);
    });

    test('accepts an empty list', () {
      expect(parseStorageDevices('[]'), isEmpty);
    });

    test('throws FormatException when the root is an object, not a list', () {
      // This is what used to escape as an uncaught TypeError and take the app
      // down from initState.
      expect(
        () => parseStorageDevices(json.encode(device().toJson())),
        throwsFormatException,
      );
    });

    test('throws FormatException on a missing required field', () {
      final incomplete = device().toJson()..remove('ipAddress');

      expect(
        () => parseStorageDevices(json.encode([incomplete])),
        throwsFormatException,
      );
    });

    test('throws FormatException on an unparsable timestamp', () {
      final bad = device().toJson()..['modified'] = 'not a date';

      expect(
        () => parseStorageDevices(json.encode([bad])),
        throwsFormatException,
      );
    });

    test('throws FormatException on a field of the wrong type', () {
      final bad = device().toJson()..['hostName'] = 42;

      expect(
        () => parseStorageDevices(json.encode([bad])),
        throwsFormatException,
      );
    });

    test('throws FormatException on input that is not JSON at all', () {
      expect(() => parseStorageDevices('not json'), throwsFormatException);
      expect(() => parseStorageDevices(''), throwsFormatException);
    });

    test('throws FormatException on a list of non-objects', () {
      expect(() => parseStorageDevices('[1, 2, 3]'), throwsFormatException);
    });
  });

  group('DeviceStorage', () {
    late Directory temp;
    const storage = DeviceStorage();

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('swol_storage_test');
      PathProviderPlatform.instance = _TempPathProvider(temp);
    });

    tearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    test('returns an empty list when nothing has been saved yet', () async {
      expect(await storage.loadDevices(), isEmpty);
    });

    test(
      'returns an empty list instead of throwing on a corrupt file',
      () async {
        await File('${temp.path}/devices.json')
            .writeAsString('{"not": "a list"}');

        expect(await storage.loadDevices(), isEmpty);
      },
    );

    test('saves and reloads a device', () async {
      await storage.saveDevices([device()]);
      final loaded = await storage.loadDevices();

      expect(loaded, hasLength(1));
      expect(loaded.single.hostName, 'nas');
      expect(loaded.single.ipAddress, '192.168.1.10');
    });

    test('saveDevices replaces the previous list completely', () async {
      // The import flow relies on a save being a full overwrite, with no
      // delete step to race against.
      await storage.saveDevices([device(id: 'old-1'), device(id: 'old-2')]);
      await storage.saveDevices([device(id: 'new-1')]);

      final reloaded = await storage.loadDevices();
      expect(reloaded.map((d) => d.id), ['new-1']);
    });

    test('saveDevices round-trips an empty list', () async {
      // What an export with no devices now produces.
      await storage.saveDevices(const []);

      expect(await storage.loadDevices(), isEmpty);
    });

    test('addDevice assigns an id and returns the new list', () async {
      final (devices, added) = await storage.addDevice(
        NetworkDevice(
          hostName: 'printer',
          ipAddress: '192.168.1.20',
          macAddress: 'AA:BB:CC:DD:EE:00',
        ),
        [device()],
      );

      expect(devices, hasLength(2));
      expect(added.id, isNotEmpty);
      expect(await storage.loadDevices(), hasLength(2));
    });

    test('updateDevice replaces only the matching id', () async {
      final original = device(id: 'keep', hostName: 'before');
      final other = device(id: 'other', hostName: 'untouched');
      await storage.saveDevices([original, other]);

      final (devices, _) = await storage.updateDevice(
        device(id: 'keep', hostName: 'after'),
        [original, other],
      );

      expect(devices.firstWhere((d) => d.id == 'keep').hostName, 'after');
      expect(devices.firstWhere((d) => d.id == 'other').hostName, 'untouched');
    });

    test('updateDevice returns the device exactly as stored', () async {
      final original = device();
      final (devices, returned) = await storage.updateDevice(original, [
        original,
      ]);

      // Same instance, so the caller never sees a stale `modified`.
      expect(identical(returned, devices.single), isTrue);
    });

    test('updateDevice restamps modified', () async {
      final original = device(id: 'keep');
      final (devices, _) = await storage.updateDevice(original, [original]);

      expect(devices.single.modified.isAfter(original.modified), isTrue);
    });

    test('deleteDevice removes just that device', () async {
      final a = device(id: 'a');
      final b = device(id: 'b');
      await storage.saveDevices([a, b]);

      final remaining = await storage.deleteDevice('a', [a, b]);

      expect(remaining.map((d) => d.id), ['b']);
      expect(await storage.loadDevices(), hasLength(1));
    });

    test('deleteAllDevices empties storage and is safe to repeat', () async {
      await storage.saveDevices([device()]);

      await storage.deleteAllDevices();
      expect(await storage.loadDevices(), isEmpty);

      // The file is already gone; deleting again must not throw.
      await storage.deleteAllDevices();
      expect(await storage.loadDevices(), isEmpty);
    });

    test('survives a full export/import cycle', () async {
      final devices = [device(id: 'a'), device(id: 'b', hostName: 'printer')];
      await storage.saveDevices(devices);

      final exported = await File(await storage.getFilePath()).readAsString();
      final imported = parseStorageDevices(exported);

      expect(imported.map((d) => d.id), ['a', 'b']);
      expect(imported.last.hostName, 'printer');
    });
  });
}
