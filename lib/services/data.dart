import 'package:swol/services/utilities.dart';

sealed class Device implements Comparable<Device> {
  final String hostName;
  final String ipAddress;
  final String macAddress;
  final int? wolPort;
  final String? deviceType;

  /// Six hex pairs, like a MAC; appended to the magic packet when set.
  final String? secureOnPassword;

  Device({
    required this.hostName,
    required this.ipAddress,
    required this.macAddress,
    this.wolPort,
    this.deviceType,
    this.secureOnPassword,
  });

  Device copyWith({
    String? id,
    String? hostName,
    String? ipAddress,
    String? macAddress,
    int? wolPort,
    DateTime? modified,
    String? deviceType,
    String? secureOnPassword,
  });

  Map<String, dynamic> toJson();
}

class StorageDevice extends Device {
  final String id;
  final DateTime modified;
  bool? isOnline;

  StorageDevice({
    required super.hostName,
    required super.ipAddress,
    required super.macAddress,
    super.wolPort,
    super.deviceType,
    super.secureOnPassword,
    required this.id,
    required this.modified,
    this.isOnline,
  });

  @override
  int compareTo(Device other) {
    return ipToNumeric(ipAddress).compareTo(ipToNumeric(other.ipAddress));
  }

  @override
  StorageDevice copyWith({
    String? id,
    String? hostName,
    String? ipAddress,
    String? macAddress,
    int? wolPort,
    DateTime? modified,
    String? deviceType,
    String? secureOnPassword,
    bool? isOnline,
  }) {
    return StorageDevice(
      id: id ?? this.id,
      hostName: hostName ?? this.hostName,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      wolPort: wolPort ?? this.wolPort,
      modified: modified ?? this.modified,
      deviceType: deviceType ?? this.deviceType,
      secureOnPassword: secureOnPassword ?? this.secureOnPassword,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      "hostName": hostName,
      "ipAddress": ipAddress,
      "macAddress": macAddress,
      "wolPort": wolPort,
      "deviceType": deviceType,
      "secureOnPassword": secureOnPassword,
      "modified": modified.toIso8601String(),
    };
  }

  factory StorageDevice.fromJson(Map<String, dynamic> json) {
    return StorageDevice(
      id: json['id'],
      hostName: json['hostName'],
      ipAddress: json['ipAddress'],
      macAddress: json['macAddress'],
      wolPort: json['wolPort'],
      modified: DateTime.parse(json['modified']),
      deviceType: json['deviceType'],
      secureOnPassword: json['secureOnPassword'],
    );
  }

  NetworkDevice toNetworkDevice() {
    return NetworkDevice(
      hostName: hostName,
      ipAddress: ipAddress,
      macAddress: macAddress,
      wolPort: wolPort,
      deviceType: deviceType,
      secureOnPassword: secureOnPassword,
    );
  }
}

class NetworkDevice extends Device {
  NetworkDevice({
    super.hostName = '',
    super.ipAddress = '',
    super.macAddress = '',
    super.wolPort,
    super.deviceType,
    super.secureOnPassword,
  });

  @override
  int compareTo(Device other) {
    return ipToNumeric(ipAddress).compareTo(ipToNumeric(other.ipAddress));
  }

  // TODO: not all parameters are necessary
  @override
  Device copyWith({
    String? id,
    String? hostName,
    String? ipAddress,
    String? macAddress,
    int? wolPort,
    DateTime? modified,
    String? deviceType,
    String? secureOnPassword,
  }) {
    return NetworkDevice(
      hostName: hostName ?? this.hostName,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      wolPort: wolPort ?? this.wolPort,
      deviceType: deviceType ?? this.deviceType,
      secureOnPassword: secureOnPassword ?? this.secureOnPassword,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'ipAddress': ipAddress,
      'macAddress': macAddress,
      'hostName': hostName,
      "wolPort": wolPort,
      "deviceType": deviceType,
      "secureOnPassword": secureOnPassword,
    };
  }

  StorageDevice toStorageDevice({
    required String id,
    String? name,
    String? ipAddress,
    String? macAddress,
    int? wolPort,
    required DateTime modified,
    String? deviceType,
    String? secureOnPassword,
  }) {
    return StorageDevice(
      id: id,
      hostName: name ?? hostName,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      wolPort: wolPort ?? this.wolPort,
      modified: modified,
      deviceType: deviceType ?? this.deviceType,
      secureOnPassword: secureOnPassword ?? this.secureOnPassword,
    );
  }
}

enum MsgType { error, check, ping, online, other }

/// A step in the wake sequence.
///
/// Variants carry the data the step is about rather than a rendered string, so
/// the service producing them never needs a [BuildContext] to describe its own
/// progress -- localization happens where the message is displayed.
sealed class Message {
  const Message();

  MsgType get type => MsgType.other;
}

/// A hostname was given but could not be resolved to an address.
final class WolHostUnresolved extends Message {
  const WolHostUnresolved(this.host);

  final String host;

  @override
  MsgType get type => MsgType.error;
}

final class WolInvalidIp extends Message {
  const WolInvalidIp(this.ip);

  final String ip;

  @override
  MsgType get type => MsgType.error;
}

final class WolInvalidMac extends Message {
  const WolInvalidMac(this.mac);

  final String mac;

  @override
  MsgType get type => MsgType.error;
}

final class WolInvalidSecureOn extends Message {
  const WolInvalidSecureOn(this.password);

  final String password;

  @override
  MsgType get type => MsgType.error;
}

final class WolInvalidPort extends Message {
  const WolInvalidPort(this.port);

  /// Empty when no port was set at all.
  final String port;

  @override
  MsgType get type => MsgType.error;
}

/// Summary emitted after any of the validation failures above.
final class WolInvalid extends Message {
  const WolInvalid();

  @override
  MsgType get type => MsgType.error;
}

final class WolValid extends Message {
  const WolValid();
}

final class WolSending extends Message {
  const WolSending();
}

final class WolSent extends Message {
  const WolSent(this.ip);

  final String ip;

  @override
  MsgType get type => MsgType.check;
}

final class WolSendFailed extends Message {
  const WolSendFailed(this.ip);

  final String ip;

  @override
  MsgType get type => MsgType.error;
}

final class PingStarted extends Message {
  const PingStarted();
}

/// Emitted once per probe; [attempt] is 1-based.
final class PingAttempt extends Message {
  const PingAttempt(this.attempt);

  final int attempt;

  @override
  MsgType get type => MsgType.ping;
}

final class PingSucceeded extends Message {
  const PingSucceeded();

  @override
  MsgType get type => MsgType.online;
}

final class PingFailed extends Message {
  const PingFailed();

  @override
  MsgType get type => MsgType.error;
}
