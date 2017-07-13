import 'dart:io';

/// Class for testing. This can be mocked to provide mock files.
class FileService {
  File newFile(String path) => new File(path);
}
