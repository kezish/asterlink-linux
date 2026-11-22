import 'dart:io';
import 'package:asterlink/app_services.dart';
import 'package:asterlink/data/state_store.dart';
import 'package:asterlink/domain/models.dart';
import 'package:asterlink/platform/file_access.dart';
import 'package:asterlink/platform/native_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final executable = Platform.environment['ASTERLINK_GOPEED_TEST_EXECUTABLE'];
  test(
    'Linux downloads real bytes and shuts down without a native foreground channel',
    () async {
      HttpOverrides.global = null;
      final root = await Directory.systemTemp.createTemp(
        'asterlink-linux-transfer-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final payload = List<int>.generate(32768, (i) => i % 251);
      server.listen((request) async {
        final response = request.response;
        response.headers.set('accept-ranges', 'bytes');
        response.headers.set('etag', '"test-v1"');
        int start = 0, end = payload.length - 1;
        final range = request.headers.value('range');
        if (range != null) {
          final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
          if (match != null) {
            start = int.parse(match[1]!);
            if (match[2]!.isNotEmpty)
              end = int.parse(match[2]!).clamp(start, end);
            response.statusCode = 206;
            response.headers.set(
              'content-range',
              'bytes $start-$end/${payload.length}',
            );
          }
        }
        response.contentLength = end - start + 1;
        if (request.method != 'HEAD')
          response.add(payload.sublist(start, end + 1));
        await response.close();
      });
      final store = StateStore.memory();
      final native = DesktopGopeedTransport(executable: executable!);
      final destination = await Directory('${root.path}/saved').create();
      final services = AppServices(
        store: store,
        dataDirectory: root,
        cacheDirectory: await Directory('${root.path}/cache').create(),
        transport: native,
        files: PlatformFileAccess(native, destination, android: false),
        http: FakeHttp(),
        controlEnabled: false,
        platformFeatures: true,
      );
      try {
        await services.downloads.initialize();
        await services.transferActivity.sync();
        await services.downloads.pauseAll();
        final id = await services.downloads.enqueue(
          DownloadSpec(
            url: 'http://127.0.0.1:${server.port}/payload',
            fileName: 'fixture.bin',
            expectedSize: payload.length,
          ),
          connections: 1,
        );
        final until = DateTime.now().add(const Duration(seconds: 25));
        while (DateTime.now().isBefore(until)) {
          final task = services.downloads.task(id)!;
          if (task.terminal) break;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        final task = services.downloads.task(id)!;
        expect(
          task.savedPath,
          isNotNull,
          reason: 'status=${task.status} error=${task.error}',
        );
        expect(await File(task.savedPath!).readAsBytes(), payload);
        await services.downloads.pauseAll();
      } finally {
        try {
          await services.close();
        } finally {
          await server.close(force: true);
          store.dispose();
          await root.delete(recursive: true);
        }
      }
    },
    skip: !Platform.isLinux || executable == null,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
