import 'package:flutter_test/flutter_test.dart';

import 'package:swol/l10n/app_localizations_en.dart';
import 'package:swol/screens/home/home.dart';
import 'package:swol/services/data.dart';

void main() {
  final l10n = AppLocalizationsEn();

  const messages = <Message>[
    WolHostUnresolved('nas.local'),
    WolInvalidIp('256.1.1.1'),
    WolInvalidMac('nope'),
    WolInvalidPort('70000'),
    WolInvalid(),
    WolValid(),
    WolSending(),
    WolSent('192.168.1.10'),
    WolSendFailed('192.168.1.10'),
    PingStarted(),
    PingAttempt(3),
    PingSucceeded(),
    PingFailed(),
  ];

  group('messageText', () {
    test('renders every variant to non-empty text', () {
      for (final message in messages) {
        expect(
          messageText(l10n, message),
          isNotEmpty,
          reason: '${message.runtimeType} rendered nothing',
        );
      }
    });

    test('interpolates the payload into the text', () {
      expect(
        messageText(l10n, const WolHostUnresolved('nas.local')),
        contains('nas.local'),
      );
      expect(
        messageText(l10n, const WolInvalidIp('256.1.1.1')),
        contains('256.1.1.1'),
      );
      expect(messageText(l10n, const WolInvalidMac('nope')), contains('nope'));
      expect(
        messageText(l10n, const WolInvalidPort('70000')),
        contains('70000'),
      );
      expect(
        messageText(l10n, const WolSent('192.168.1.10')),
        contains('192.168.1.10'),
      );
      expect(messageText(l10n, const PingAttempt(3)), contains('3'));
    });

    test('gives each variant its own wording', () {
      final rendered = messages.map((m) => messageText(l10n, m)).toSet();

      expect(rendered, hasLength(messages.length));
    });
  });
}
