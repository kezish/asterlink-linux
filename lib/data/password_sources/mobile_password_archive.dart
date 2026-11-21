import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive.dart' as zip;

import '../parser_rules/password_web_flow.dart';

/// Read the TXT specified by the public password guide. Never extract archive
/// entries to the filesystem, execute files or log the resulting password.
class MobilePasswordArchive {
  static const maxArchiveBytes = 16 * 1024 * 1024;
  static const maxTextBytes = 16 * 1024 * 1024;
  static const maxEntries = 128;

  static String fromText(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxTextBytes) {
      throw const FormatException('TXT 大小超出限制');
    }
    final text = utf8.decode(bytes).replaceFirst(RegExp(r'^\uFEFF'), '');
    final line = text.split(RegExp(r'\r\n|\n|\r')).first;
    final matches = RegExp(r'=+([^=\r\n]+)=+').allMatches(line).toList();
    if (matches.length != 1) {
      throw const FormatException('TXT 第一行没有唯一的等号间密码，请核对当天文件');
    }
    final value = matches.single[1]!.trim();
    if (!ParserPasswordWebResult.validPassword(value)) {
      throw const FormatException('TXT 第一行的密码格式无效');
    }
    return value;
  }

  static String fromZip(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxArchiveBytes) {
      throw const FormatException('ZIP 大小超出限制');
    }
    final dir = zip.ZipDirectory()..read(zip.InputMemoryStream(bytes));
    if (dir.fileHeaders.isEmpty ||
        dir.fileHeaders.length > maxEntries ||
        dir.numberOfThisDisk != 0 ||
        dir.diskWithTheStartOfTheCentralDirectory != 0) {
      throw const FormatException('ZIP 目录无效或过大');
    }
    final candidates = dir.fileHeaders.where((h) {
      final name = h.filename.replaceAll('\\', '/');
      return !name.startsWith('__MACOSX/') &&
          name.toLowerCase().endsWith('.txt') &&
          !name.split('/').last.startsWith('._');
    }).toList();
    if (candidates.length != 1) {
      throw const FormatException('ZIP 内须有唯一 TXT，请手动选择正确的 TXT');
    }
    final entry = candidates.single;
    final mode = entry.externalFileAttributes >> 16;
    if ((mode & 0xf000) == 0xa000 ||
        (entry.generalPurposeBitFlag & 1) != 0 ||
        entry.uncompressedSize <= 0 ||
        entry.uncompressedSize > maxTextBytes ||
        entry.compressedSize > bytes.length ||
        !{0, 8}.contains(entry.compressionMethod)) {
      throw const FormatException('ZIP 的 TXT 条目不受支持或超出限制');
    }
    final file = entry.file;
    if (file == null ||
        (file.flags & 1) != 0 ||
        file.uncompressedSize != entry.uncompressedSize) {
      throw const FormatException('ZIP 条目信息无效');
    }
    final raw = file.getStream(decompress: false).toUint8List();
    final sink = _BoundedSink();
    if (entry.compressionMethod == 0) {
      sink.add(raw);
    } else {
      final decoder = io.ZLibDecoder(raw: true).startChunkedConversion(sink);
      for (var i = 0; i < raw.length; i += 8192) {
        final end = i + 8192 < raw.length ? i + 8192 : raw.length;
        decoder.add(Uint8List.sublistView(raw, i, end));
      }
      decoder.close();
    }
    final decoded = sink.bytes.takeBytes();
    if (decoded.length != entry.uncompressedSize ||
        zip.getCrc32(decoded) != entry.crc32) {
      throw const FormatException('ZIP 数据校验失败');
    }
    return fromText(decoded);
  }
}

class _BoundedSink implements Sink<List<int>> {
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> data) {
    if (bytes.length + data.length > MobilePasswordArchive.maxTextBytes) {
      throw const FormatException('TXT 解压大小超出限制');
    }
    bytes.add(data);
  }

  @override
  void close() {}
}
