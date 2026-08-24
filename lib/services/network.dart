import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_ping/dart_ping.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:swol/services/utilities.dart';
import 'package:wake_on_lan/wake_on_lan.dart';

import 'package:swol/constants.dart';

import 'data.dart';

/// Probes a single address, returning the device when it answers the ping and
/// null when it does not. The hostname comes from a best-effort reverse
/// lookup.
typedef DeviceProbe = Future<NetworkDevice?> Function(String ipAddress);

Future<NetworkDevice?> probeDevice(String ipAddress) async {
  final ping = Ping(ipAddress, count: 1, timeout: AppConstants.homePingTimeout);

  await for (final event in ping.stream) {
    if (event is PingResponse) {
      String host = "";
      try {
        host = (await InternetAddress(ipAddress).reverse()).host;
      } on SocketException {
        host = "";
      }

      return NetworkDevice(ipAddress: ipAddress, hostName: host);
    }
  }

  return null;
}

/// Reads the phone's Wi-Fi IPv4 address and submask; null when there is no
/// usable Wi-Fi connection.
typedef WifiNetwork = Future<({String? ip, String? submask})> Function();

Future<({String? ip, String? submask})> wifiNetwork() async {
  final info = NetworkInfo();

  return (ip: await info.getWifiIP(), submask: await info.getWifiSubmask());
}

/// Sweeps every host address of the subnet [localIp] sits on with 25
/// concurrent chains, reporting progress in [0, 1] after every probe.
/// The swept block is clamped to [/22, /30]: wider subnets scan only the
/// /22 around [localIp] so the sweep stays bounded, and point-to-point
/// /31-/32 masks widen to the surrounding /30. Devices outside the block
/// can still be added manually.
Stream<NetworkDevice> findDevicesInNetwork(
  String localIp,
  String submask,
  void Function(double) progressCallback, {
  DeviceProbe probe = probeDevice,
}) {
  const chainCount = 25;

  final prefix = (maskToPrefix(submask) ?? 24).clamp(22, 30);
  final network =
      ipToNumeric(localIp) & ((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF);
  final firstHost = network + 1;
  final hostCount = (1 << (32 - prefix)) - 2;

  final controller = StreamController<NetworkDevice>();
  var probed = 0;
  var chainsLeft = chainCount;

  Future<void> scanChain(int offset) async {
    try {
      for (var index = offset; index < hostCount; index += chainCount) {
        NetworkDevice? device;

        try {
          device = await probe(numericToIp(firstHost + index));
        } catch (_) {
          // An erroring probe is indistinguishable from silence: that
          // address just is not a reachable device.
          device = null;
        }

        if (device != null) {
          controller.add(device);
        }

        progressCallback(++probed / hostCount);
      }
    } finally {
      // Close only once every chain is done -- even one that died, or the
      // stream never ends. Closing when the last address completes, as this
      // used to, let a slower sibling chain add() to a closed controller.
      if (--chainsLeft == 0) {
        await controller.close();
      }
    }
  }

  for (var offset = 0; offset < chainCount; offset++) {
    unawaited(scanChain(offset));
  }

  return controller.stream;
}

/// [findDevicesInNetwork], but run on its own isolate. Each probe spawns a
/// ping process, and parsing the output of 25 concurrent chains on the UI
/// isolate drops frames whenever a transition animates over a running scan.
/// Cancelling the subscription kills the isolate mid-sweep.
Stream<NetworkDevice> findDevicesInNetworkIsolated(
  String localIp,
  String submask,
  void Function(double) progressCallback,
) {
  final controller = StreamController<NetworkDevice>();
  final results = ReceivePort();
  final spawning = Isolate.spawn(
    _scanIsolateMain,
    (results.sendPort, localIp, submask),
    // Crash backstop: the VM posts null here if the isolate dies without
    // reaching its own Isolate.exit sentinel. After a normal exit the first
    // null closes the port, so this duplicate is dropped.
    onExit: results.sendPort,
  );

  results.listen((message) {
    switch (message) {
      case final double progress:
        progressCallback(progress);
      case final NetworkDevice device:
        controller.add(device);
      case null:
        results.close();
        controller.close();
    }
  });

  unawaited(
    spawning.then(
      (_) {},
      onError: (Object _) {
        results.close();
        controller.close();
      },
    ),
  );

  controller.onCancel = () async {
    results.close();

    try {
      (await spawning).kill(priority: Isolate.immediate);
    } catch (_) {
      // Spawning already failed and closed the stream; nothing to kill.
    }
  };

  return controller.stream;
}

Future<void> _scanIsolateMain((SendPort, String, String) args) async {
  final (port, localIp, submask) = args;
  final devices = findDevicesInNetwork(localIp, submask, port.send);

  await for (final device in devices) {
    port.send(device);
  }

  // The ping processes leave watchers behind that keep this isolate alive
  // after the sweep, so exit explicitly; it also delivers the sentinel.
  Isolate.exit(port, null);
}

/// Validates [device] and sends its magic packets -- unicast, plus the
/// subnet broadcast when the target is local. Ends with [WolSent] or
/// [WolSendFailed], or [WolInvalid] when validation fails.
Stream<Message> sendWakePackets({
  required NetworkDevice device,
  WifiNetwork wifi = wifiNetwork,
}) async* {
  // Validate correct formatting of ip and mac addresses
  String ip = device.ipAddress;
  // Stored MACs may use hyphens; MACAddress only accepts colons.
  final mac = device.macAddress.replaceAll('-', ':');
  final secureOn = device.secureOnPassword?.replaceAll('-', ':');
  final int? port = device.wolPort;
  bool invalid = false;

  if (isHost(ip)) {
    final result = await hostToIp(ip);

    if (result == null) {
      yield WolHostUnresolved(ip);
      invalid = true;
    } else {
      ip = result;
    }
  } else if (!IPAddress.validate(ip).state) {
    // Skipped for hostnames: an unresolved one has already been reported,
    // and a resolved one is a valid address by construction.
    yield WolInvalidIp(ip);
    invalid = true;
  }

  if (!MACAddress.validate(mac).state) {
    // The stored text, not the normalized one -- it is what the user typed.
    yield WolInvalidMac(device.macAddress);
    invalid = true;
  }

  if (secureOn != null && !SecureONPassword.validate(secureOn).state) {
    yield WolInvalidSecureOn(device.secureOnPassword!);
    invalid = true;
  }

  if (port == null || port < 0 || port > 65535) {
    yield WolInvalidPort(port?.toString() ?? '');
    invalid = true;
  }

  if (invalid) {
    yield const WolInvalid();
    return;
  }

  // if no error occurred: try to send wol package
  yield const WolValid();
  yield const WolSending();

  final ipv4Address = IPAddress(ip);
  final macAddress = MACAddress(mac);
  final password = secureOn == null ? null : SecureONPassword(secureOn);

  // The port range was validated above, so it is non-null from here on.
  final validPort = port!;

  // Sometimes only a broadcast works to wake a device, so one is sent
  // additionally -- to the real subnet broadcast, since assuming /24 sent it
  // nowhere on wider networks. An off-subnet target (wake over WAN through a
  // port forward) gets unicast only; a subnet broadcast cannot reach it.
  ({String? ip, String? submask}) local;

  try {
    local = await wifi();
  } catch (_) {
    local = (ip: null, submask: null);
  }

  final localIp = local.ip;
  final submask = local.submask;
  String? broadcast;

  final wifiUnusable =
      localIp == null ||
      !isValidIpv4(localIp) ||
      submask == null ||
      maskToPrefix(submask) == null;

  if (wifiUnusable) {
    // No usable interface info: keep the /24 guess this app always used.
    broadcast = '${ip.substring(0, ip.lastIndexOf("."))}.255';
  } else if (sameSubnet(ip, localIp, submask)) {
    broadcast = broadcastAddress(localIp, submask);
  }

  try {
    await WakeOnLAN(
      ipv4Address,
      macAddress,
      password: password,
      port: validPort,
    ).wake(repeat: 3);

    if (broadcast != null) {
      await Future.delayed(const Duration(seconds: 1));
      await WakeOnLAN(
        IPAddress(broadcast),
        macAddress,
        password: password,
        port: validPort,
      ).wake(repeat: 3);
    }

    yield WolSent(ip);
  } catch (_) {
    yield WolSendFailed(ip);
  }
}

/// Sends the wake packets, then pings [device] until it answers, reporting
/// every step. The widget's background callback uses [sendWakePackets]
/// directly: the confirmation loop would keep a headless engine alive for
/// minutes.
Stream<Message> sendWolPackage({
  required NetworkDevice device,
  WifiNetwork wifi = wifiNetwork,
}) async* {
  Message outcome = const WolInvalid();

  await for (final message in sendWakePackets(device: device, wifi: wifi)) {
    outcome = message;
    yield message;
  }

  final ip = switch (outcome) {
    WolSent(:final ip) => ip,
    WolSendFailed(:final ip) => ip,
    _ => null,
  };

  if (ip == null) {
    return;
  }

  // ping device until it is online
  yield const PingStarted();
  bool online = false;
  int tries = 0;
  const maxPings = 25;
  while (!online && tries < maxPings) {
    tries++;
    yield PingAttempt(tries);

    final ping = Ping(ip, count: 1, timeout: 5);

    // Wait for the current ping to complete
    await for (final event in ping.stream) {
      if (event is PingResponse) {
        online = true;
      }
    }
  }

  yield online ? const PingSucceeded() : const PingFailed();
}

/// returns a list of Messages by using the sendWolPackage function
/// accumulates the messages in a list and yields the list after each message
Stream<List<Message>> sendWolAndGetMessages({
  required NetworkDevice device,
  WifiNetwork wifi = wifiNetwork,
}) async* {
  final List<Message> messages = [];
  await for (final message in sendWolPackage(device: device, wifi: wifi)) {
    // a ping attempt supersedes the previous one instead of stacking up
    if (messages.isNotEmpty &&
        messages.last is PingAttempt &&
        message is PingAttempt) {
      messages.removeLast();
    }
    messages.add(message);
    // A copy, so a consumer holding an earlier event does not see it mutate.
    yield List.unmodifiable(messages);
  }
}

/// ping a list of devices and return their status
Future<bool> pingDevice({required String ipAddress}) async {
  final ping = Ping(ipAddress, count: 1, timeout: 3);

  // Wait for the current ping to complete
  await for (final event in ping.stream) {
    if (event is PingResponse) {
      return true;
    }
  }
  return false;
}
