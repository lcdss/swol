import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/database.dart';

Future<void> shareJsonFile() async {
  final deviceStorage = DeviceStorage();
  final filePath = await deviceStorage.getFilePath();

  final file = File(filePath);
  if (!await file.exists()) {
    await file.create();
  }

  await SharePlus.instance.share(
    ShareParams(files: [XFile(filePath)], subject: 'devices.json'),
  );
}

Future<File?> getJsonFile() async {
  final picked = await FilePicker.pickFile();
  final path = picked?.path;

  if (path == null) return null;

  return File(path);
}
