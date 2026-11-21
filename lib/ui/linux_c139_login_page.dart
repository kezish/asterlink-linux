import 'dart:async';
import 'dart:convert';

import 'package:asterlink_webview_linux/asterlink_webview_linux.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_services.dart';
import '../domain/auth.dart';
import '../domain/models.dart';
import '../diagnostics/web_login_diagnostics.dart';
import 'common.dart';

/// A separate native GTK window avoids unsupported Flutter platform views.
/// Authentication and account ownership remain in upstream AccountLoginService.
class LinuxC139LoginPage extends StatefulWidget {
  const LinuxC139LoginPage(
    this.services, {
    super.key,
    required this.accountId,
    required this.manualPage,
  });
  final AppServices services;
  final String? accountId;
  final WidgetBuilder manualPage;

  @override
  State<LinuxC139LoginPage> createState() => _LinuxC139LoginPageState();
}

class _LinuxC139LoginPageState extends State<LinuxC139LoginPage> {
  static const platform = CloudPlatform.c139;
  final target = WebLoginTarget.targets[platform]!;
  final host = LinuxWebViewHost.instance;
  final diagnostics = WebLoginDiagnostics(platform, flow: 'linux_native');
  LinuxWebViewSession? session;
  StreamSubscription<LinuxWebViewEvent>? events;
  bool opening = false, checking = false, completed = false, manual = false;
  String status = '请在单独的网页窗口正常登录，然后返回此处检测登录。';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  Future<void> _close() async {
    final old = session;
    session = null;
    final subscription = events;
    events = null;
    // This plugin is currently used only by this login route; close any SSO
    // popups as well as the main login window, releasing the ephemeral jar.
    if (old != null) {
      try {
        await host.closeAll();
      } catch (_) {}
    }
    await subscription?.cancel();
  }

  Future<void> _open() async {
    if (opening || checking || manual || completed) return;
    setState(() {
      opening = true;
      status = '正在开启 Linux 原生网页窗口…';
    });
    try {
      widget.services.control.checkCloud(platform);
      await _close();
      final view = await host.create(
        url: target.url,
        userAgent: target.userAgent,
        title: '中国移动云盘 · 网页登录',
        ephemeral: true,
        arbitrateNavigation: false,
      );
      if (!mounted) {
        await host.closeAll();
        return;
      }
      session = view;
      events = view.events.listen((event) {
        if (!mounted || completed || !identical(session, view)) return;
        if (event.type == LinuxWebViewEvent.loadFinished) {
          unawaited(_probeLayout(view));
        } else if (event.type == LinuxWebViewEvent.closed) {
          setState(() => status = '网页已关闭，请重新打开并在关闭前检测登录。');
          unawaited(_close());
        } else if (event.type == LinuxWebViewEvent.loadFailed ||
            event.type == LinuxWebViewEvent.processTerminated) {
          diagnostics.record(
            'native_load_failed',
            stage: 'network',
            fields: {'type': event.type},
          );
          setState(() => status = '网页加载有异常，请重试或使用手动登录。');
        }
      });
      diagnostics.record('native_window_opened', stage: 'initialize');
      setState(() => status = '请在网页窗口完成登录并进入网盘首页，随后点击「检测并保存登录」。');
    } catch (e) {
      diagnostics.record(
        'native_initialize_failed',
        stage: 'initialize',
        fields: {'type': e.runtimeType.toString()},
      );
      if (mounted) setState(() => status = 'Linux 网页窗口初始化失败，请重试或使用手动登录。');
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  // Read geometry only: never collect input values, cookies or page text.
  Future<void> _probeLayout(LinuxWebViewSession view) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || !identical(session, view) || completed) return;
      try {
        final result = await view
            .evaluate('''
          JSON.stringify({
            width: window.innerWidth, height: window.innerHeight,
            visibleInputs: Array.from(document.querySelectorAll('input')).filter(e => {
              const r = e.getBoundingClientRect();
              const cs = getComputedStyle(e);
              return r.width > 0 && r.height > 0 && r.left < innerWidth &&
                r.right > 0 && r.top < innerHeight && r.bottom > 0 &&
                cs.visibility !== 'hidden' && cs.display !== 'none' &&
                e.type !== 'hidden';
            }).length
          })
        ''')
            .timeout(const Duration(seconds: 4));
        final layout = jsonDecode(result as String) as Map<String, dynamic>;
        final w = layout['width'] as num;
        final h = layout['height'] as num;
        final count = layout['visibleInputs'] as num;
        if (!mounted || !identical(session, view) || completed) return;
        diagnostics.record(
          'native_layout',
          stage: 'renderer',
          fields: {'width': w, 'height': h, 'visibleInputs': count},
        );
        if (w > 0 && h > 0 && count > 0) {
          debugPrint(
            'ASTERLINK_C139_LAYOUT_READY width=$w height=$h visibleInputs=$count',
          );
          return;
        }
        if (w <= 0 || h <= 0) {
          setState(() => status = '网页视口异常，请查看 Linux 渲染诊断。');
          return;
        }
      } catch (_) {
        return;
      }
    }
  }

  Future<void> _check() async {
    final view = session;
    if (view == null || checking || opening || manual || completed) return;
    setState(() {
      checking = true;
      status = '正在检测并验证移动云盘登录…';
    });
    try {
      widget.services.control.checkCloud(platform);
      final page = await view.currentUrl().timeout(const Duration(seconds: 4));
      if (!mounted || !identical(session, view)) return;
      final values = <String>[];
      for (final url in target.cookieUrls(page?.toString())) {
        final entries = await host
            .cookies(session: view.id, url: url)
            .timeout(const Duration(seconds: 5));
        if (!mounted || !identical(session, view)) return;
        values.add(
          entries.map((entry) => '${entry.name}=${entry.value}').join('; '),
        );
      }
      final candidate = LoginCredentials.fromBrowser(platform, cookies: values);
      if (!LoginCredentials.c139WebReady(candidate)) {
        setState(() => status = '登录尚未完成，请在网页进入网盘首页后重新检测。');
        return;
      }
      await widget.services.login.submitWeb(
        platform,
        candidate,
        accountId: widget.accountId,
        browserUserAgent: target.userAgent,
      );
      if (!mounted || !identical(session, view)) return;
      completed = true;
      diagnostics.record('validation_succeeded', stage: 'validation');
      await _close();
      if (mounted) {
        message(context, '移动云盘登录成功');
        Navigator.pop(context);
      }
    } catch (e) {
      diagnostics.record(
        'validation_failed',
        stage: 'validation',
        fields: {'type': e.runtimeType.toString()},
      );
      if (mounted) setState(() => status = '登录信息尚未通过验证，请检查网页登录状态后重试。');
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _manual() async {
    setState(() => manual = true);
    await _close();
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: widget.manualPage),
    );
    if (!mounted) return;
    if (saved == true) {
      completed = true;
      Navigator.pop(context);
    } else {
      setState(() => manual = false);
    }
  }

  @override
  void dispose() {
    if (!completed) widget.services.login.invalidate(platform);
    diagnostics.close(completed: completed);
    unawaited(_close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '139 网页登录（Linux）',
    actions: [
      TextButton(
        onPressed: opening || checking || manual ? null : _manual,
        child: const Text('手动'),
      ),
    ],
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_browser, size: 48),
              const SizedBox(height: 16),
              Text(status, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (opening || checking) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: session == null || checking || opening || manual
                    ? null
                    : _check,
                child: const Text('检测并保存登录'),
              ),
              TextButton(
                onPressed: opening || checking || manual ? null : _open,
                child: const Text('重新打开登录网页'),
              ),
              TextButton(
                onPressed: session == null || manual
                    ? null
                    : () async {
                        try {
                          await session?.present();
                        } catch (_) {}
                      },
                child: const Text('显示登录窗口'),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(target.url),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('在系统浏览器打开（仅备用，需手动配置）'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
