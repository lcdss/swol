import 'dart:io';

import 'package:swol/constants.dart';

int ipToNumeric(String ipAddress) {
  final parts = ipAddress.split('.');
  final octets = parts.map(int.parse).toList();
  final numeric =
      (octets[0] << 24) + (octets[1] << 16) + (octets[2] << 8) + octets[3];
  return numeric;
}

String numericToIp(int numeric) =>
    '${(numeric >> 24) & 255}.${(numeric >> 16) & 255}.'
    '${(numeric >> 8) & 255}.${numeric & 255}';

/// Whether [value] is a well-formed dotted-decimal IPv4 address.
bool isValidIpv4(String value) {
  final parts = value.split('.');

  if (parts.length != 4) return false;

  for (final part in parts) {
    final octet = int.tryParse(part);

    if (octet == null || octet < 0 || octet > 255 || part != octet.toString()) {
      return false;
    }
  }

  return true;
}

/// The prefix length of a dotted-decimal submask, or null when the mask is
/// malformed or not a contiguous run of ones (e.g. 255.0.255.0). The null
/// return doubles as the "is this submask usable at all" check, so junk from
/// getWifiSubmask never reaches the subnet math.
int? maskToPrefix(String submask) {
  if (!isValidIpv4(submask)) return null;

  final numeric = ipToNumeric(submask);

  for (var prefix = 0; prefix <= 32; prefix++) {
    final expected = prefix == 0
        ? 0
        : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

    if (numeric == expected) return prefix;
  }

  return null;
}

bool sameSubnet(String a, String b, String submask) {
  final mask = ipToNumeric(submask);

  return (ipToNumeric(a) & mask) == (ipToNumeric(b) & mask);
}

String broadcastAddress(String ip, String submask) {
  final mask = ipToNumeric(submask);

  return numericToIp((ipToNumeric(ip) & mask) | (~mask & 0xFFFFFFFF));
}

/// e.g. ('192.168.1.17', '255.255.255.0') -> '192.168.1.0/24'
///
/// [submask] must satisfy [maskToPrefix]; callers check before formatting.
String cidrNotation(String ip, String submask) {
  final network = ipToNumeric(ip) & ipToNumeric(submask);

  return '${numericToIp(network)}/${maskToPrefix(submask)}';
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
