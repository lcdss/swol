import 'package:flutter_test/flutter_test.dart';

import 'package:swol/services/data.dart';

StorageDevice buildStorageDevice({
  String id = 'id-1',
  String hostName = 'nas',
  String ipAddress = '192.168.1.10',
  String macAddress = 'AA:BB:CC:DD:EE:FF',
  int? wolPort = 9,
  String? deviceType = 'server',
  bool? isOnline,
}) => StorageDevice(
  id: id,
  hostName: hostName,
  ipAddress: ipAddress,
  macAddress: macAddress,
  wolPort: wolPort,
  deviceType: deviceType,
  isOnline: isOnline,
  modified: DateTime.utc(2026, 1, 2, 3, 4, 5),
);

void main() {
  group('StorageDevice JSON', () {
    test('round-trips through the documented export schema', () {
      final device = buildStorageDevice();
      final restored = StorageDevice.fromJson(device.toJson());

      expect(restored.id, device.id);
      expect(restored.hostName, device.hostName);
      expect(restored.ipAddress, device.ipAddress);
      expect(restored.macAddress, device.macAddress);
      expect(restored.wolPort, device.wolPort);
      expect(restored.deviceType, device.deviceType);
      expect(restored.modified, device.modified);
    });

    test('emits exactly the keys the README publishes', () {
      // README documents this shape for export/import, so it is a contract
      // with anyone who has hand-edited or scripted a devices.json.
      expect(buildStorageDevice().toJson().keys.toSet(), {
        'id',
        'hostName',
        'ipAddress',
        'macAddress',
        'wolPort',
        'deviceType',
        'modified',
      });
    });

    test('keeps a null port and type', () {
      final restored = StorageDevice.fromJson(
        buildStorageDevice(wolPort: null, deviceType: null).toJson(),
      );

      expect(restored.wolPort, isNull);
      expect(restored.deviceType, isNull);
    });
  });

  group('compareTo', () {
    test('orders by numeric address, not lexically', () {
      final low = buildStorageDevice(ipAddress: '192.168.1.9');
      final high = buildStorageDevice(ipAddress: '192.168.1.10');

      expect(low.compareTo(high), lessThan(0));
      expect(high.compareTo(low), greaterThan(0));
      expect(low.compareTo(low), 0);
    });

    test('compares two StorageDevices directly', () {
      // Before Device was Comparable<Device> this did not typecheck, so
      // sorting a stored list needed a conversion first.
      final devices = [
        buildStorageDevice(ipAddress: '192.168.1.20'),
        buildStorageDevice(ipAddress: '192.168.1.3'),
      ]..sort();

      expect(devices.first.ipAddress, '192.168.1.3');
    });
  });

  group('conversions', () {
    test('toNetworkDevice keeps the addressable fields', () {
      final network = buildStorageDevice().toNetworkDevice();

      expect(network.ipAddress, '192.168.1.10');
      expect(network.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(network.wolPort, 9);
    });

    test('toStorageDevice stamps the id and timestamp it is given', () {
      final modified = DateTime.utc(2026, 5, 6);
      final stored = NetworkDevice(
        hostName: 'nas',
        ipAddress: '192.168.1.10',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      ).toStorageDevice(id: 'fresh', modified: modified);

      expect(stored.id, 'fresh');
      expect(stored.modified, modified);
    });
  });

  group('Message', () {
    test('maps each variant to the severity the dialog colours by', () {
      expect(const WolInvalid().type, MsgType.error);
      expect(const WolInvalidIp('x').type, MsgType.error);
      expect(const WolInvalidMac('x').type, MsgType.error);
      expect(const WolInvalidPort('').type, MsgType.error);
      expect(const WolHostUnresolved('x').type, MsgType.error);
      expect(const WolSendFailed('x').type, MsgType.error);
      expect(const PingFailed().type, MsgType.error);

      expect(const WolSent('x').type, MsgType.check);
      expect(const PingSucceeded().type, MsgType.online);
      expect(const PingAttempt(1).type, MsgType.ping);

      expect(const WolValid().type, MsgType.other);
      expect(const WolSending().type, MsgType.other);
      expect(const PingStarted().type, MsgType.other);
    });

    test('carries its payload instead of a rendered string', () {
      expect(const PingAttempt(7).attempt, 7);
      expect(const WolSent('192.168.1.10').ip, '192.168.1.10');
      expect(const WolHostUnresolved('nas.local').host, 'nas.local');
    });
  });
}
