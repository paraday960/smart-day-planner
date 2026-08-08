import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/offline_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('استخراج tar.bz2 فایل‌ها را درست باز می‌کند', () async {
    // ساخت یک بایگانی tar.bz2 در حافظه (بدون وابستگی به فایل فیکسچر).
    final archive = Archive()
      ..addFile(ArchiveFile('src/', 0, Uint8List(0)))
      ..addFile(ArchiveFile('src/a.txt', 6, utf8.encode('hello\n')))
      ..addFile(ArchiveFile('src/sub/', 0, Uint8List(0)))
      ..addFile(ArchiveFile('src/sub/b.txt', 6, utf8.encode('world\n')));

    final tarBytes = TarEncoder().encode(archive);
    final bz2Bytes = BZip2Encoder().encode(tarBytes);

    // نوشتن فایل موقت
    final tmpBz2 = File('${Directory.systemTemp.path}/piper_fixture_$pid.tar.bz2');
    await tmpBz2.writeAsBytes(bz2Bytes);
    addTearDown(() async {
      if (await tmpBz2.exists()) await tmpBz2.delete();
    });

    // دایرکتوری مقصد
    final dest = Directory.systemTemp.createTempSync('piper_dest_$pid');
    addTearDown(() => dest.deleteSync(recursive: true));

    await extractTarBz2(tmpBz2.path, dest.path);

    // فایل‌ها باید استخراج شده باشند.
    expect(File('${dest.path}/src/a.txt').existsSync(), isTrue);
    expect(File('${dest.path}/src/sub/b.txt').existsSync(), isTrue);
    expect(File('${dest.path}/src/a.txt').readAsStringSync().trim(), 'hello');
    expect(File('${dest.path}/src/sub/b.txt').readAsStringSync().trim(), 'world');
  });
}
