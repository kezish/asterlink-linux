import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asterlink/app_services.dart';
import 'package:asterlink/data/state_store.dart';
import 'package:asterlink/domain/models.dart';
import 'package:asterlink/ui/linux_c139_login_page.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Linux mobile login opens an isolated window and refuses incomplete login',
    (tester) async {
      const channel = MethodChannel('asterlink/webview_linux');
      const eventChannel = MethodChannel('asterlink/webview_linux/events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(eventChannel, (_) async => null);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'create' => 'fixture-window',
          'currentUrl' => 'https://yun.139.com/w/',
          'getCookies' => <Object?>[],
          _ => null,
        };
      });
      final dir = Directory.systemTemp.createTempSync(
        'asterlink-c139-linux-test-',
      );
      final store = StateStore.memory();
      final services = AppServices(
        store: store,
        dataDirectory: dir,
        cacheDirectory: Directory('${dir.path}/cache'),
        transport: FakeNative(),
        files: FakeFiles(Directory('${dir.path}/saved')),
        http: FakeHttp(),
        controlEnabled: false,
        platformFeatures: false,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        var closed = false;
        final closing = services.close().whenComplete(() => closed = true);
        for (var i = 0; i < 100 && !closed; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        expect(closed, isTrue);
        await closing;
        store.dispose();
        dir.deleteSync(recursive: true);
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(eventChannel, null);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: LinuxC139LoginPage(
            services,
            accountId: null,
            manualPage: (_) => const Scaffold(body: Text('manual fixture')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final create = calls.singleWhere((c) => c.method == 'create');
      expect(create.arguments['ephemeral'], true);
      expect(create.arguments['url'], 'https://yun.139.com/w/');
      await tester.tap(find.text('检测并保存登录'));
      await tester.pumpAndSettle();
      expect(find.text('登录尚未完成，请在网页进入网盘首页后重新检测。'), findsOneWidget);
      final reads = calls.where((c) => c.method == 'getCookies');
      expect(reads, isNotEmpty);
      expect(reads.every((c) => c.arguments['id'] == 'fixture-window'), true);
      expect(services.vault.credential(CloudPlatform.c139), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(calls.any((c) => c.method == 'closeAll'), true);
    },
  );
}
