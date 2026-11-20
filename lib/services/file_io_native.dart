import 'dart:io';

/// Native (Android / iOS / desktop) filesystem helpers used together with
/// `file_picker`, which returns a path on these platforms.
Future<List<int>?> readBytesFromFile(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> writeBytesToFile(String path, List<int> bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}
