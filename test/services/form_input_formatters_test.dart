import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swol/services/form_input_formatters.dart';

TextEditingValue value(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

/// Feeds [text] one character at a time, the way a keyboard would, so the
/// auto-separator behaviour is exercised rather than the paste shortcut.
String typeOut(TextInputFormatter formatter, String text) {
  var current = TextEditingValue.empty;
  for (final char in text.split('')) {
    final typed = value('${current.text}$char');
    current = formatter.formatEditUpdate(current, typed);
  }

  return current.text;
}

void main() {
  group('MACAddressFormatter', () {
    test('inserts a colon after every pair', () {
      expect(
        typeOut(MACAddressFormatter(), 'AABBCCDDEEFF'),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('does not add a trailing separator after the last pair', () {
      final formatted = typeOut(MACAddressFormatter(), 'AABBCCDDEEFF');

      expect(formatted.endsWith(':'), isFalse);
      expect(formatted.split(':'), hasLength(6));
    });

    test('accepts lowercase hex', () {
      expect(
        typeOut(MACAddressFormatter(), 'aabbccddeeff'),
        'aa:bb:cc:dd:ee:ff',
      );
    });

    test('rejects a non-hex character instead of inserting it', () {
      final formatter = MACAddressFormatter();
      final existing = value('AA:BB');

      expect(
        formatter.formatEditUpdate(existing, value('AA:BBZ')).text,
        'AA:BB',
      );
    });

    test('typing a dash switches the whole field to dashes', () {
      final formatter = MACAddressFormatter();
      final existing = value('AA:BB');

      expect(
        formatter.formatEditUpdate(existing, value('AA:BB-')).text,
        'AA-BB',
      );
    });

    test('falls back to a separator the preferred one cannot satisfy', () {
      // Regression: this branch used to append the whole separator set
      // ('AA:-') instead of the one that matched.
      final formatter = CustomSeparatorFormatter(
        separators: ':-',
        preferredSeparator: ':',
        allowedInput: RegExp(r'^(?:[0-9A-Fa-f]{2}-)*[0-9A-Fa-f]{0,2}$'),
      );

      expect(formatter.formatEditUpdate(value('A'), value('AA')).text, 'AA-');
    });

    test('lets a paste through without reformatting', () {
      final formatter = MACAddressFormatter();

      expect(
        formatter
            .formatEditUpdate(
              TextEditingValue.empty,
              value('AA:BB:CC:DD:EE:FF'),
            )
            .text,
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('stops accepting input past six pairs', () {
      final formatter = MACAddressFormatter();
      final full = value('AA:BB:CC:DD:EE:FF');

      expect(
        formatter.formatEditUpdate(full, value('AA:BB:CC:DD:EE:FFA')).text,
        'AA:BB:CC:DD:EE:FF',
      );
    });
  });

  group('IPAddressFormatter', () {
    test('accepts a dotted quad typed character by character', () {
      expect(typeOut(IPAddressFormatter(), '192.168.1.10'), '192.168.1.10');
    });

    test('does not insert dots on its own', () {
      // autoSeparate is off for IPs, so the user types the dots.
      expect(typeOut(IPAddressFormatter(), '192'), '192');
    });

    test('accepts hostname characters, leaving the shape to the validator', () {
      // The field takes an IP or a hostname, so per-keystroke filtering can
      // only restrict the character set; '256' may be the start of a name.
      expect(typeOut(IPAddressFormatter(), 'web1.local'), 'web1.local');
      expect(typeOut(IPAddressFormatter(), 'my-nas.lan'), 'my-nas.lan');
      expect(typeOut(IPAddressFormatter(), '256'), '256');
    });

    test('rejects characters that fit neither an IP nor a hostname', () {
      final formatter = IPAddressFormatter();

      expect(
        formatter.formatEditUpdate(value('192.168.'), value('192.168._')).text,
        '192.168.',
      );
      expect(
        formatter.formatEditUpdate(value('nas'), value('nas ')).text,
        'nas',
      );
    });
  });
}
