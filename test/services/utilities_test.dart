import 'package:flutter_test/flutter_test.dart';

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

    test('rejects labels with digits so a dotted quad is never resolved', () {
      // isHost decides whether a value goes to the resolver, so it must not
      // claim '192.168.1.10'.
      expect(isHost('192.168.1.10'), isFalse);
      expect(isHost('nas-1.local'), isFalse);
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
}
