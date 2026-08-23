import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'data.dart';
import 'database.dart';
import 'network.dart';

const _androidWidgetName = 'DeviceListWidgetProvider';

/// Mirrors [devices] into the home screen widget and redraws it. A no-op
/// wherever the plugin is absent (tests, desktop): the widget is cosmetic,
/// never worth failing a save over.
Future<void> syncDevicesToWidget(List<StorageDevice> devices) async {
  final payload = [
    for (final device in devices)
      {
        'id': device.id,
        'hostName': device.hostName.isEmpty
            ? device.ipAddress
            : device.hostName,
      },
  ];

  try {
    await HomeWidget.saveWidgetData('devices', json.encode(payload));
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  } catch (_) {}
}

Future<void> registerWidgetInteractivity() async {
  try {
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  } catch (_) {}
}

/// Runs in a background isolate when a widget row is tapped: sends the wake
/// packets for that device. Stops once the send settles -- the ping loop
/// after it would keep a headless engine alive for minutes.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null || uri.host != 'wake') {
    return;
  }

  final id = uri.queryParameters['id'];
  final matches = await const DeviceStorage().loadDevices().then(
    (devices) => devices.where((device) => device.id == id),
  );

  if (matches.isEmpty) {
    return;
  }

  await for (final message in sendWolPackage(
    device: matches.first.toNetworkDevice(),
  )) {
    final settled =
        message is WolSent || message is WolSendFailed || message is WolInvalid;

    if (settled) {
      break;
    }
  }
}
