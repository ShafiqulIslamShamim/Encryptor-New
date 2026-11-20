/// Web stub. On the web `file_picker` already reads/writes the bytes itself,
/// so no filesystem access is needed here.
Future<List<int>?> readBytesFromFile(String path) async => null;

Future<void> writeBytesToFile(String path, List<int> bytes) async {}
