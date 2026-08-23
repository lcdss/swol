import 'dart:async';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
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

/// Sweeps `networkPrefix.1` through `.254` with [_chainCount] concurrent
/// chains, reporting progress in [0, 1] after every probe.
Stream<NetworkDevice> findDevicesInNetwork(
  String networkPrefix,
  void Function(double) progressCallback, {
  DeviceProbe probe = probeDevice,
}) {
  const chainCount = 25;
  const lastIndex = 254;

  final controller = StreamController<NetworkDevice>();
  var probed = 0;
  var chainsLeft = chainCount;

  Future<void> scanChain(int start) async {
    for (var index = start; index <= lastIndex; index += chainCount) {
      final device = await probe('$networkPrefix.$index');

      if (device != null) {
        controller.add(device);
      }

      progressCallback(++probed / lastIndex);
    }

    // Close only once every chain is done. Closing when .254 completes, as
    // this used to, let a slower sibling chain add() to a closed controller.
    if (--chainsLeft == 0) {
      await controller.close();
    }
  }

  for (var start = 1; start <= chainCount; start++) {
    unawaited(scanChain(start));
  }

  return controller.stream;
}

/// sends the magic packet to the [device] that should receive a magic wol package in order to get woken up
Stream<Message> sendWolPackage({required NetworkDevice device}) async* {
  // Validate correct formatting of ip and mac addresses
  String ip = device.ipAddress;
  final mac = device.macAddress;
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
  }

  if (!IPAddress.validate(ip).state) {
    yield WolInvalidIp(ip);
    invalid = true;
  }

  if (!MACAddress.validate(mac).state) {
    yield WolInvalidMac(mac);
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

  // sometimes only a broadcast works to wake a device so a broadcast is sent additionally
  final subnet = ip.substring(0, ip.lastIndexOf("."));
  final ipv4Broadcast = IPAddress("$subnet.255");

  // The port range was validated above, so it is non-null from here on.
  final validPort = port!;

  try {
    await WakeOnLAN(ipv4Address, macAddress, port: validPort).wake(repeat: 3);
    await Future.delayed(const Duration(seconds: 1));
    await WakeOnLAN(ipv4Broadcast, macAddress, port: validPort).wake(repeat: 3);
    yield WolSent(ip);
  } catch (_) {
    yield WolSendFailed(ip);
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
}) async* {
  final List<Message> messages = [];
  await for (final message in sendWolPackage(device: device)) {
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
