import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asterlink/data/parser_rules/hub.dart';
import 'package:asterlink/data/providers/baidu_public_parser.dart';
import 'package:asterlink/data/state_store.dart';
import 'package:asterlink/ui/parser_site_picker.dart';
import 'baidu_public_parser_support.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParserRuleHub hub;
  late StateStore state;
  late DateTime now;
  late BaiduPublicFixture fixture;
  late FakeHttp http;

  setUp(() {
    now = DateTime.utc(2026, 11, 21, 12);
    fixture = BaiduPublicFixture();
    http = FakeHttp(fixture.respond);
    state = StateStore.memory();
    hub = ParserRuleHub(
      store: Vault(state),
      directory: Directory('builtin-password-fixture'),
      url: '',
      apiKey: '',
      publicKey: '',
      backupUrl: '',
      clock: () => now,
    );
  });
  tearDown(() => hub.close());

  test('no grant prevents any parser request', () async {
    final parser = BaiduPublicParser(http, hub: hub);
    await expectLater(
      parser.openShare(fixture.link),
      throwsA(isA<ParserPasswordRequired>()),
    );
    expect(http.calls, isEmpty);
  });

  test(
    'manual grant reaches real parser logic and is scoped and revoked',
    () async {
      final grant = await hub.grantBuiltinPassword(BaiduPublicFixture.password);
      expect(hub.grantedPassword('another_site', grant), isNull);
      final parser = BaiduPublicParser(http, hub: hub);
      final session = await parser.openShare(
        fixture.link,
        passwordGrant: grant,
      );
      final files = await parser.list(session, '/');
      expect(files, isNotEmpty);
      expect(
        http.calls.first.json['parse_password'],
        BaiduPublicFixture.password,
      );
      await parser.download(session, files.first);
      expect(
        http.calls.last.json['parse_password'],
        BaiduPublicFixture.password,
      );
      expect(
        state.data.toString(),
        isNot(contains(BaiduPublicFixture.password)),
      );
      await hub.revokePasswordGrant(grant);
      expect(hub.grantedPassword('mf_dg22', grant), isNull);
    },
  );

  test('original parser rejection revokes manual password grant', () async {
    final rejecting = FakeHttp(
      (request) =>
          jsonResponse({'code': 20016, 'message': 'password rejected'}, 400),
    );
    final grant = await hub.grantBuiltinPassword('incorrect-test-password');
    final parser = BaiduPublicParser(rejecting, hub: hub);
    await expectLater(
      parser.openShare(fixture.link, passwordGrant: grant),
      throwsA(isA<ParserPasswordRequired>()),
    );
    expect(rejecting.calls, hasLength(1));
    expect(hub.grantedPassword('mf_dg22', grant), isNull);
  });

  test('manual grant expires at Beijing midnight', () async {
    final grant = await hub.grantBuiltinPassword(BaiduPublicFixture.password);
    now = DateTime.utc(2026, 11, 21, 16);
    expect(hub.grantedPassword('mf_dg22', grant), isNull);
  });

  test(
    'configured Hub cannot be replaced with built-in manual grants',
    () async {
      final configured = ParserRuleHub(
        store: Vault(StateStore.memory()),
        directory: Directory('builtin-password-fixture'),
        url: 'https://example.org',
        apiKey: 'test',
        publicKey: 'test',
        backupUrl: '',
      );
      try {
        expect(configured.configured, isTrue);
        await expectLater(
          configured.grantBuiltinPassword('合法测试密码'),
          throwsA(anything),
        );
      } finally {
        await configured.close();
      }
    },
  );

  testWidgets('public community build offers the manual password dialog', (
    tester,
  ) async {
    String? grant;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  grant = await showParserPasswordDialog(
                    context,
                    hub,
                    'mf_dg22',
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('百度公益解析 · 手动密码'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('builtin-parser-password-input')),
      BaiduPublicFixture.password,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('builtin-parser-password-submit')),
    );
    await tester.pumpAndSettle();
    expect(grant, isNotNull);
    expect(
      hub.grantedPassword('mf_dg22', grant)?.value,
      BaiduPublicFixture.password,
    );
  });
}
