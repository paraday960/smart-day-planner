import 'dart:io';
import 'dart:typed_data';

abstract class ShareFileServicePort {
  Future<File> saveBytes({required String fileName, required Uint8List bytes});
  Future<File> saveText({required String fileName, required String text});
  Future<void> shareFile(File file, {String? text});
}
