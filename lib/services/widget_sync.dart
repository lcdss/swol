import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'data.dart';

/// The manifest receiver class the update is addressed to.
const androidWidgetName = 'DeviceListWidgetReceiver';

/// Mirrors [devices] into the home screen widget and redraws it, sorted the
/// way the app's own list opens (alphabetical) since the widget has no sort
/// menu. A no-op wherever the plugin is absent (tests, desktop): the widget
/// is cosmetic, never worth failing a save over.
Future<void> syncDevicesToWidget(List<StorageDevice> devices) async {
  final entries = [
    for (final device in devices)
      (
        id: device.id,
        name: device.hostName.isEmpty ? device.ipAddress : device.hostName,
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final payload = [
    for (final entry in entries) {'id': entry.id, 'hostName': entry.name},
  ];

  try {
    await HomeWidget.saveWidgetData('devices', json.encode(payload));
    // Clears any "Waking..." left behind by a background callback that was
    // killed mid-send; otherwise it would sit on the widget forever.
    await HomeWidget.saveWidgetData('statusKind', null);
    await HomeWidget.saveWidgetData('statusName', null);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  } catch (_) {}
}
