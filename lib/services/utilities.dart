import 'dart:io';

import 'package:swol/constants.dart';

int ipToNumeric(String ipAddress) {
  final parts = ipAddress.split('.');
  final octets = parts.map(int.parse).toList();
  final numeric =
      (octets[0] << 24) + (octets[1] << 16) + (octets[2] << 8) + octets[3];
  return numeric;
}

bool isHost(String value) {
  return RegExp(AppConstants.hostValidationRegex).hasMatch(value);
}

Future<String?> hostToIp(String host) async {
  try {
    final addresses = await InternetAddress.lookup(host);

    for (final address in addresses) {
      if (address.type == InternetAddressType.IPv4) return address.address;
    }

    // Resolvable, but only to IPv6 -- unusable for the IPv4 magic packet.
    return null;
  } on SocketException {
    return null;
  }
}
