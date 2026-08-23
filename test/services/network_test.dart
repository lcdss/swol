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
      // Regression: the unresolved hostname used to also be run through the
      // IP validator, producing a second, redundant error message.
      expect(messages.whereType<WolInvalidIp>(), isEmpty);
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

    test('accepts a MAC stored with hyphens', () async {
      // Regression: the form accepted AA-BB-..., but the send path validated
      // colons only, so the saved device could never actually be woken.
      final messages = await sendWolPackage(
        device: device(ipAddress: '256.1.1.1', macAddress: 'AA-BB-CC-DD-EE-FF'),
      ).toList();

      expect(messages.whereType<WolInvalidMac>(), isEmpty);
    });
  });

  group('sendWolPackage happy path', () {
    test('walks the full sequence against loopback', () async {
      // Loopback is always reachable, so the UDP send and the ping loop
      // both run for real without depending on the LAN.
      final messages = await sendWolPackage(
        device: device(ipAddress: '127.0.0.1'),
        // Off-subnet from the fake Wi-Fi, so only the unicast packet is sent
        // and nothing leaves the machine.
        wifi: () async => (ip: '10.0.0.5', submask: '255.0.0.0'),
      ).toList();

      expect(messages.first, isA<WolValid>());
      expect(messages.whereType<WolSending>(), hasLength(1));
      expect(
        messages.whereType<WolSent>().length +
            messages.whereType<WolSendFailed>().length,
        1,
        reason: 'exactly one send outcome',
      );
      expect(messages.whereType<PingStarted>(), hasLength(1));
      expect(messages.whereType<PingAttempt>(), isNotEmpty);
      expect(messages.last, isA<PingSucceeded>());
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('sends the broadcast when the target shares the subnet', () async {
      // Loopback's own "subnet": the broadcast resolves to 127.255.255.255,
      // which never leaves the machine either.
      final messages = await sendWolPackage(
        device: device(ipAddress: '127.0.0.1'),
        wifi: () async => (ip: '127.0.0.2', submask: '255.0.0.0'),
      ).toList();

      expect(
        messages.whereType<WolSent>().length +
            messages.whereType<WolSendFailed>().length,
        1,
        reason: 'exactly one send outcome',
      );
      expect(messages.last, isA<PingSucceeded>());
    }, timeout: const Timeout(Duration(minutes: 1)));
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
        '192.168.1.5',
        '255.255.255.0',
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
        '192.168.1.5',
        '255.255.255.0',
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
        '192.168.1.5',
        '255.255.255.0',
        (_) {},
        probe: fakeProbe(),
      ).toList();

      expect(devices, isEmpty);
    });

    test('sweeps the whole subnet when it is wider than /24', () async {
      // Regression: the sweep assumed /24, so on this /23 the upper half of
      // the network was never probed at all.
      final probedIps = <String>[];
      final devices = await findDevicesInNetwork(
        '192.168.150.18',
        '255.255.254.0',
        (_) {},
        probe: (ip) async {
          probedIps.add(ip);

          return const {'192.168.150.3', '192.168.151.200'}.contains(ip)
              ? NetworkDevice(ipAddress: ip)
              : null;
        },
      ).toList();

      expect(probedIps, hasLength(510));
      expect(probedIps, contains('192.168.150.1'));
      expect(probedIps, contains('192.168.151.254'));
      expect(probedIps, isNot(contains('192.168.150.0')));
      expect(probedIps, isNot(contains('192.168.151.255')));
      expect(devices.map((d) => d.ipAddress), {
        '192.168.150.3',
        '192.168.151.200',
      });
    });

    test('clamps very wide subnets to the /22 around the local IP', () async {
      var probed = 0;

      await findDevicesInNetwork(
        '10.1.37.9',
        '255.255.0.0',
        (_) {},
        probe: (_) async {
          probed++;

          return null;
        },
      ).toList();

      expect(probed, 1022);
    });
  });

  group('sendWolAndGetMessages', () {
    test('accumulates messages, yielding the list so far each time', () async {
      final snapshots = await sendWolAndGetMessages(
        device: device(ipAddress: '256.1.1.1'),
      ).toList();

      expect(snapshots, isNotEmpty);
      // Each yield is one longer than the last and preserves the prefix, so
      // a consumer can render any snapshot as "everything so far".
      for (var i = 1; i < snapshots.length; i++) {
        expect(snapshots[i].length, snapshots[i - 1].length + 1);
        expect(snapshots[i].sublist(0, snapshots[i - 1].length), [
          ...snapshots[i - 1],
        ]);
      }
      expect(snapshots.last.map((m) => m.runtimeType), [
        WolInvalidIp,
        WolInvalid,
      ]);
    });
  });
}
