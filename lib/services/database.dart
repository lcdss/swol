import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'data.dart';
import 'widget_sync.dart';

/// Decodes the persisted device list.
///
/// Throws [FormatException] for anything that is not a JSON list of device
/// objects, so a corrupt or hand-edited file cannot surface as a raw
/// [TypeError] from deep inside [StorageDevice.fromJson].
List<StorageDevice> parseStorageDevices(String contents) {
  final decoded = json.decode(contents);

  if (decoded is! List) {
    throw FormatException(
      'Expected a JSON list of devices, got ${decoded.runtimeType}',
    );
  }

  try {
    return decoded
        .map((item) => StorageDevice.fromJson(item as Map<String, dynamic>))
        .toList();
  } on TypeError catch (error) {
    throw FormatException('Malformed device entry: $error');
  }
}

class DeviceStorage {
  const DeviceStorage();

  static const _fileName = 'devices.json';

  Future<String> getFilePath() async {
    final appDocumentsDirectory = await getApplicationDocumentsDirectory();
    return '${appDocumentsDirectory.path}/$_fileName';
  }

  Future<List<StorageDevice>> loadDevices() async {
    try {
      final filePath = await getFilePath();
      final file = File(filePath);
      return parseStorageDevices(await file.readAsString());
    } on FileSystemException {
      return [];
    } on FormatException {
      // TODO: show error in ui
      return [];
    }
  }

  /// Saves a list of devices to the file [_fileName] in the app documents directory
  /// [devices] the list of devices to save
  Future<void> saveDevices(List<StorageDevice> devices) async {
    final filePath = await getFilePath();
    final jsonData = devices.map((item) => item.toJson()).toList();
    final jsonString = json.encode(jsonData);
    final file = File(filePath);
    await file.writeAsString(jsonString);
    await syncDevicesToWidget(devices);
  }

  /// Adds a new device to the list of devices
  /// [device] the device to add
  Future<(List<StorageDevice>, StorageDevice)> addDevice(
    NetworkDevice device,
    List<StorageDevice> devices,
  ) async {
    final storageDevice = device.toStorageDevice(
      id: const Uuid().v1(),
      modified: DateTime.now(),
    );
    final updatedDevices = [...devices, storageDevice];
    await saveDevices(updatedDevices);
    return (updatedDevices, storageDevice);
  }

  /// Updates a device in the list of devices
  /// [updatedDevice] the device to update
  /// [devices] the list of all devices
  Future<(List<StorageDevice>, StorageDevice)> updateDevice(
    StorageDevice updatedDevice,
    List<StorageDevice> devices,
  ) async {
    // Restamped once, so the returned device is the same one that was stored
    // -- not a twin with the old timestamp.
    final saved = updatedDevice.copyWith(modified: DateTime.now());
    final updatedDevices = devices
        .map((device) => device.id == saved.id ? saved : device)
        .toList();
    await saveDevices(updatedDevices);
    return (updatedDevices, saved);
  }

  /// Deletes a device from the list of devices
  /// [deviceId] the id of the device to delete
  Future<List<StorageDevice>> deleteDevice(
    String deviceId,
    List<StorageDevice> devices,
  ) async {
    final updatedDevices = devices
        .where((device) => device.id != deviceId)
        .toList();
    await saveDevices(updatedDevices);
    return updatedDevices;
  }

  /// Deletes the devices file
  Future<void> deleteAllDevices() async {
    try {
      final filePath = await getFilePath();
      final file = File(filePath);
      await file.delete();
    } on FileSystemException {
      // Already gone, which is the desired end state.
    }

    await syncDevicesToWidget(const []);
  }
}
