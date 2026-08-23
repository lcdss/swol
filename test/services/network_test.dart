import 'package:flutter_test/flutter_test.dart';

import 'package:swol/services/data.dart';
import 'package:swol/services/network.dart';

NetworkDevice device({
  String ipAddress = '192.168.1.10',
  String macAddress = 'AA:BB:CC:DD:EE:FF',
  int? wolPort = 9,
}) => NetworkDevice(
  hostName: 'nas',
  ipAddress: ipAddress,
  macAddress: macAddress,
  wolPort: wolPort,
);

void main() {
  // These only cover the branches that bail out before any packet is sent, so
  // nothing here touches the network. They are possible at all because
  // sendWolPackage no longer takes a BuildContext.
  group('sendWolPackage validation', () {
    test('reports an unusable IP and stops', () async {
      final messages = await sendWolPackage(
        device: device(ipAddress: '256.1.1.1'),
      ).toList();

      expect(messages.whereType<WolInvalidIp>().single.ip, '256.1.1.1');
      expect(messages.last, isA<WolInvalid>());
    });

    test('reports an unusable MAC and stops', () async {
      final messages = await sendWolPackage(
        device: device(macAddress: 'not-a-mac'),
      ).toList();

      expect(messages.whereType<WolInvalidMac>().single.mac, 'not-a-mac');
      expect(messages.last, isA<WolInvalid>());
    });

    test('reports a missing port as an empty string', () async {
      final messages = await sendWolPackage(device: device(wolPort: null))
          .toList();

      expect(messages.whereType<WolInvalidPort>().single.port, '');
      expect(messages.last, isA<WolInvalid>());
    });

    test('reports an out-of-range port', () async {
      final messages = await sendWolPackage(device: device(wolPort: 70000))
          .toList();

      expect(messages.whereType<WolInvalidPort>().single.port, '70000');
    });

    test('collects every problem before giving up', () async {
      final messages = await sendWolPackage(
        device: device(ipAddress: '256.1.1.1', macAddress: 'nope', wolPort: -1),
      ).toList();

      expect(messages.whereType<WolInvalidIp>(), hasLength(1));
      expect(messages.whereType<WolInvalidMac>(), hasLength(1));
      expect(messages.whereType<WolInvalidPort>(), hasLength(1));
      expect(messages.last, isA<WolInvalid>());
    });

    test('reports a hostname that will not resolve', () async {
      // .invalid is reserved by RFC 2606, so this never reaches a real host.
      final messages = await sendWolPackage(
        device: device(ipAddress: 'unresolvable.invalid'),
      ).toList();

      expect(
        messages.whereType<WolHostUnresolved>().single.host,
        'unresolvable.invalid',
      );
      expect(messages.last, isA<WolInvalid>());
    });

    test('emits nothing past WolInvalid', () async {
      final messages = await sendWolPackage(device: device(ipAddress: 'bad'))
          .toList();

      // No send and no ping once validation has failed.
      expect(messages.whereType<WolSending>(), isEmpty);
      expect(messages.whereType<WolSent>(), isEmpty);
      expect(messages.whereType<PingAttempt>(), isEmpty);
    });
  });

  group('findDevicesInNetwork', () {
    /// A probe that answers for [alive] addresses, taking [delays] into
    /// account so chain-finishing order can be forced.
    DeviceProbe fakeProbe({
      Set<int> alive = const {},
      Map<int, Duration> delays = const {},
    }) => (String ipAddress) async {
      final index = int.parse(ipAddress.split('.').last);
      final delay = delays[index];

      if (delay != null) await Future.delayed(delay);

      if (!alive.contains(index)) return null;

      return NetworkDevice(ipAddress: ipAddress);
    };

    test('probes all 254 addresses and finishes at 100%', () async {
      final progress = <double>[];
      final devices = await findDevicesInNetwork(
        '192.168.1',
        progress.add,
        probe: fakeProbe(alive: {1, 42, 254}),
      ).toList();

      expect(devices.map((d) => d.ipAddress), {
        '192.168.1.1',
        '192.168.1.42',
        '192.168.1.254',
      });
      expect(progress, hasLength(254));
      expect(progress.last, 1.0);
    });

    test('a device found after .254 completes still arrives', () async {
      // Regression: the stream used to close as soon as the chain containing
      // .254 finished, so a slower sibling chain would add() to a closed
      // controller (StateError) and its device was lost.
      final devices = await findDevicesInNetwork(
        '192.168.1',
        (_) {},
        probe: fakeProbe(
          alive: {253},
          delays: {253: const Duration(milliseconds: 100)},
        ),
      ).toList();

      expect(devices.single.ipAddress, '192.168.1.253');
    });

    test('reports an empty subnet with no devices and no error', () async {
      final devices = await findDevicesInNetwork(
        '192.168.1',
        (_) {},
        probe: fakeProbe(),
      ).toList();

      expect(devices, isEmpty);
    });
  });

  group('sendWolAndGetMessages', () {
    test('accumulates messages, yielding the list so far each time', () async {
      final snapshots = await sendWolAndGetMessages(
        device: device(ipAddress: '256.1.1.1'),
      ).toList();

      expect(snapshots, isNotEmpty);
      // Each yield is one longer than the last.
      for (var i = 1; i < snapshots.length; i++) {
        expect(snapshots[i].length, snapshots[i - 1].length + 1);
      }
      expect(snapshots.last.last, isA<WolInvalid>());
    });
  });
}
