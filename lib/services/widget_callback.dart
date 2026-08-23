import 'package:home_widget/home_widget.dart';

import 'database.dart';
import 'network.dart';

Future<void> registerWidgetInteractivity() async {
  try {
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  } catch (_) {}
}

/// Runs in a background isolate when a widget row is tapped: sends the wake
/// packets for that device without opening the app.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null || uri.host != 'wake') {
    return;
  }

  final id = uri.queryParameters['id'];
  final devices = await const DeviceStorage().loadDevices();
  final matches = devices.where((device) => device.id == id);

  if (matches.isEmpty) {
    return;
  }

  await sendWakePackets(device: matches.first.toNetworkDevice()).drain<void>();
}
