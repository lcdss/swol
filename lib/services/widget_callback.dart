import 'package:home_widget/home_widget.dart';

import 'data.dart';
import 'database.dart';
import 'network.dart';
import 'widget_sync.dart';

Future<void> registerWidgetInteractivity() async {
  try {
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  } catch (_) {}
}

/// Runs in a background isolate when a widget row is tapped: sends the wake
/// packets for that device without opening the app, narrating through the
/// status entries the widget renders.
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

  final device = matches.first;
  final name = device.hostName.isEmpty ? device.ipAddress : device.hostName;

  await _showStatus('waking', name);

  Message outcome = const WolInvalid();

  await for (final message in sendWakePackets(
    device: device.toNetworkDevice(),
  )) {
    outcome = message;
  }

  if (outcome is WolSent) {
    await _showStatus(null, null);
  } else {
    // Long enough to read before the line disappears again.
    await _showStatus('failed', name);
    await Future.delayed(const Duration(seconds: 4));
    await _showStatus(null, null);
  }
}

Future<void> _showStatus(String? kind, String? name) async {
  try {
    await HomeWidget.saveWidgetData('statusKind', kind);
    await HomeWidget.saveWidgetData('statusName', name);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  } catch (_) {}
}
