import 'package:flutter_test/flutter_test.dart';

import 'package:swol/constants.dart';
import 'package:swol/services/utilities.dart';

void main() {
  group('ipToNumeric', () {
    test('packs the four octets big-endian', () {
      expect(ipToNumeric('0.0.0.0'), 0);
      expect(ipToNumeric('0.0.0.1'), 1);
      expect(ipToNumeric('0.0.1.0'), 256);
      expect(ipToNumeric('1.0.0.0'), 16777216);
      expect(ipToNumeric('255.255.255.255'), 4294967295);
    });

    test('orders addresses the way a human reads them', () {
      // The whole point of the function: '192.168.1.9' must sort before
      // '192.168.1.10', which a plain string compare gets wrong.
      expect(ipToNumeric('192.168.1.9') < ipToNumeric('192.168.1.10'), isTrue);
      expect(ipToNumeric('192.168.2.1') > ipToNumeric('192.168.1.254'), isTrue);
    });

    test('throws on input that is not a dotted quad', () {
      expect(() => ipToNumeric('192.168.1'), throwsA(anything));
      expect(() => ipToNumeric('nas.local'), throwsFormatException);
      expect(() => ipToNumeric(''), throwsFormatException);
    });
  });

  group('isHost', () {
    test('accepts dotted hostnames', () {
      expect(isHost('nas.local'), isTrue);
      expect(isHost('server.home.lan'), isTrue);
    });

    test('rejects addresses, so a typed IP is never resolved as a name', () {
      expect(isHost('192.168.1.10'), isFalse);
      expect(isHost('999.999.999.999'), isFalse);
    });

    test('rejects a bare label with no dot', () {
      expect(isHost('nas'), isFalse);
      expect(isHost(''), isFalse);
    });

    test('is case-insensitive, as DNS names are', () {
      expect(isHost('NAS.local'), isTrue);
      expect(isHost('Nas.Local'), isTrue);
    });

    test('accepts digits and hyphens in labels, per RFC 1123', () {
      expect(isHost('web1.local'), isTrue);
      expect(isHost('my-nas.lan'), isTrue);
      expect(isHost('nas-1.home.arpa'), isTrue);
    });

    test('rejects a label starting or ending with a hyphen', () {
      expect(isHost('-nas.local'), isFalse);
      expect(isHost('nas-.local'), isFalse);
    });

    test('never claims a dotted quad, which must skip the resolver', () {
      // isHost decides whether a value goes to the resolver, so it must not
      // claim '192.168.1.10' even though every label is RFC 1123 valid.
      expect(isHost('192.168.1.10'), isFalse);
      expect(isHost('999.999.999.999'), isFalse);
    });
  });

  group('ipValidationRegex', () {
    final regex = RegExp(AppConstants.ipValidationRegex);

    test('accepts addresses and hostnames', () {
      expect(regex.hasMatch('192.168.1.10'), isTrue);
      expect(regex.hasMatch('web1.local'), isTrue);
      expect(regex.hasMatch('my-nas.lan'), isTrue);
    });

    test('rejects what is neither an address nor a hostname', () {
      expect(regex.hasMatch('256.1.1.1'), isFalse);
      expect(regex.hasMatch('192.168.1.10.'), isFalse);
      expect(regex.hasMatch('nas'), isFalse);
      expect(regex.hasMatch('-nas.local'), isFalse);
      expect(regex.hasMatch(''), isFalse);
    });
  });

  group('hostToIp', () {
    test('returns null for a name that cannot resolve', () async {
      // .invalid is reserved by RFC 2606 and must never resolve.
      expect(await hostToIp('swol-test-host.invalid'), isNull);
    });

    test('resolves localhost to its IPv4 address', () async {
      expect(await hostToIp('localhost'), '127.0.0.1');
    });
  });

  group('subnet math', () {
    test('numericToIp round-trips with ipToNumeric', () {
      const ips = ['0.0.0.0', '10.1.37.9', '192.168.150.18', '255.255.255.255'];

      for (final ip in ips) {
        expect(numericToIp(ipToNumeric(ip)), ip);
      }
    });

    test('maskToPrefix reads contiguous masks', () {
      expect(maskToPrefix('255.255.255.0'), 24);
      expect(maskToPrefix('255.255.254.0'), 23);
      expect(maskToPrefix('255.255.255.252'), 30);
      expect(maskToPrefix('255.0.0.0'), 8);
      expect(maskToPrefix('0.0.0.0'), 0);
      expect(maskToPrefix('255.255.255.255'), 32);
    });

    test('maskToPrefix rejects a mask with holes', () {
      expect(maskToPrefix('255.0.255.0'), isNull);
      expect(maskToPrefix('0.255.255.255'), isNull);
    });

    test('sameSubnet honours the mask width', () {
      // The /23 from the upstream bug report: both halves are one subnet.
      expect(
        sameSubnet('192.168.150.18', '192.168.151.20', '255.255.254.0'),
        isTrue,
      );
      expect(
        sameSubnet('192.168.150.18', '192.168.152.1', '255.255.254.0'),
        isFalse,
      );
      expect(
        sameSubnet('192.168.150.18', '192.168.151.20', '255.255.255.0'),
        isFalse,
      );
    });

    test('broadcastAddress derives the real broadcast', () {
      expect(
        broadcastAddress('192.168.150.18', '255.255.254.0'),
        '192.168.151.255',
      );
      expect(
        broadcastAddress('192.168.1.10', '255.255.255.0'),
        '192.168.1.255',
      );
      expect(broadcastAddress('10.1.2.3', '255.0.0.0'), '10.255.255.255');
    });

    test('cidrNotation prints the network the phone is on', () {
      expect(cidrNotation('192.168.1.17', '255.255.255.0'), '192.168.1.0/24');
      expect(
        cidrNotation('192.168.151.20', '255.255.254.0'),
        '192.168.150.0/23',
      );
    });
  });
}
