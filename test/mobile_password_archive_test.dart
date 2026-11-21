import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asterlink/data/password_sources/mobile_password_archive.dart';

Uint8List makeZip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.add(ArchiveFile.string(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('reads only first line with BOM and CRLF', () {
    expect(
      MobilePasswordArchive.fromText(
        utf8.encode('\uFEFF===测试口令===\r\n=ignored='),
      ),
      '测试口令',
    );
  });
  test('extracts TXT from ZIP without writing paths', () {
    expect(
      MobilePasswordArchive.fromZip(
        makeZip({'folder/today.txt': '===demo-test===\ncontent'}),
      ),
      'demo-test',
    );
  });
  test('rejects multiple TXT files', () {
    expect(
      () => MobilePasswordArchive.fromZip(
        makeZip({'a.txt': '=one=', 'b.txt': '=two='}),
      ),
      throwsFormatException,
    );
  });
  test('rejects missing or ambiguous first-line password', () {
    for (final text in ['no password\n=second-line=', '=one= =two=', '====']) {
      expect(
        () => MobilePasswordArchive.fromText(utf8.encode(text)),
        throwsFormatException,
      );
    }
  });
  test('rejects invalid ZIP', () {
    expect(
      () => MobilePasswordArchive.fromZip(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
  });
}
