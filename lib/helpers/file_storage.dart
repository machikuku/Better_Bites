import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class FileStorageHelper {
  static Future<String> getFilePath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }

  static Future<String> saveFile(File file) async {
    debugPrint('Saving file: $file');
    final storageDirectory = (await getApplicationDocumentsDirectory()).path;
    final generatedFileName =
        'food_image_${DateTime.now().millisecondsSinceEpoch.toString()}.jpg';

    file.copy(join(storageDirectory, generatedFileName));
    debugPrint('Saved file: $generatedFileName');
    return generatedFileName;
  }

  static Future<File> getFile(String fileName) async {
    final path = await getFilePath(fileName);
    final file = File(path);

    if (!file.existsSync()) {
      throw Exception('File not found: $path');
    }

    return file;
  }

  static Future<bool> deleteFile(String fileName) async {
    final path = await getFilePath(fileName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}
