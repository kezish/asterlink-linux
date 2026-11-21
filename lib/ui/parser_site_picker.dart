import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_services.dart';
import '../core/json.dart';
import '../data/parser_rules/hub.dart';
import '../domain/models.dart';
import '../domain/c139_passcode.dart';
import '../data/password_sources/mobile_password_archive.dart';
import '../data/password_sources/mobile_password_guide.dart';
import 'cloud_command_page.dart';
import 'common.dart';
import 'parser_password_web_page.dart';
import 'announcement_markdown.dart';

class ParserSitePicker extends StatelessWidget {
  const ParserSitePicker({
    super.key,
    required this.services,
    this.siteId,
    this.onSelected,
    this.onPasswordReady,
    this.enabled = true,
    this.platform = CloudPlatform.baidu,
  });
  final AppServices services;
  final String? siteId;
  final ValueChanged<String>? onSelected;
  final ValueChanged<String>? onPasswordReady;
  final bool enabled;
  final CloudPlatform platform;

  @override
  Widget build(BuildContext context) {
    final hub = services.parserRules;
    if (!hub.configured) {
      if (platform != CloudPlatform.baidu || !hub.builtinPasswordAvailable) {
        return const SizedBox.shrink();
      }
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('内置公益通道（手动密码）'),
          TextButton.icon(
            key: const ValueKey('parser-password-button'),
            icon: const Icon(Icons.key_outlined, size: 17),
            label: const Text('解析密码'),
            onPressed: !enabled
                ? null
                : () async {
                    final grant = await showParserPasswordDialog(
                      context,
                      hub,
                      'mf_dg22',
                      services: services,
                    );
                    if (grant != null && context.mounted) {
                      onPasswordReady?.call(grant);
                    }
                  },
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        if (!hub.publicParsingAllowed(platform)) return const SizedBox.shrink();
        final sites = hub.sitesFor(platform);
        final selected =
            sites
                .where((s) => s.id == (siteId ?? hub.selectedFor(platform)))
                .firstOrNull ??
            (siteId == null ? sites.firstOrNull : null);
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              key: const ValueKey('parser-site-picker'),
              icon: const Icon(Icons.hub_outlined, size: 17),
              label: Text(
                '${selected?.name ?? (hub.hasManifest && sites.isEmpty
                        ? '暂无可用通道'
                        : siteId == null
                        ? platform == CloudPlatform.baidu
                              ? '公益通道一'
                              : '选择解析通道'
                        : '当前解析通道')} ▾',
              ),
              onPressed: enabled
                  ? () async {
                      await hub.refresh();
                      if (!context.mounted) return;
                      if (hub.sitesFor(platform).isEmpty) {
                        message(
                          context,
                          hub.hasManifest || platform != CloudPlatform.baidu
                              ? '暂无可用解析通道，请使用账号下载或稍后再试'
                              : '暂未获取到远程通道，当前可继续使用内置公益解析',
                        );
                        return;
                      }
                      final value = await showDialog<String>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('选择解析通道'),
                          children: [
                            for (final site in hub.sitesFor(platform))
                              SimpleDialogOption(
                                onPressed: () =>
                                    Navigator.pop(context, site.id),
                                child: Row(
                                  children: [
                                    Icon(
                                      site.id == selected?.id
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      size: 20,
                                      color: themeAccent(context),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(site.name)),
                                    Text(
                                      'v${site.version}',
                                      style: TextStyle(
                                        color: secondary(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                      if (value == null || !context.mounted) return;
                      await hub.select(value);
                      onSelected?.call(value);
                    }
                  : null,
            ),
            if (selected == null || selected.rule.requiresPassword)
              TextButton.icon(
                key: const ValueKey('parser-password-button'),
                icon: const Icon(Icons.key_outlined, size: 17),
                label: const Text('解析密码'),
                onPressed: !enabled || selected == null
                    ? null
                    : () async {
                        final grant = await showParserPasswordDialog(
                          context,
                          hub,
                          selected.id,
                          resolveUcPassword:
                              services.cloud.publicPasswords.fromUcCommand,
                        );
                        if (grant != null && context.mounted) {
                          onPasswordReady?.call(grant);
                        }
                      },
              ),
            if (selected != null &&
                !selected.rule.requiresPassword &&
                selected.obtainUrl.isNotEmpty)
              TextButton.icon(
                key: const ValueKey('parser-web-button'),
                icon: const Icon(Icons.open_in_browser_outlined, size: 17),
                label: const Text('网页解析'),
                onPressed: !enabled
                    ? null
                    : () async {
                        final uri = Uri.tryParse(selected.obtainUrl);
                        if (uri != null &&
                            {'http', 'https'}.contains(uri.scheme)) {
                          final opened = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!opened && context.mounted) {
                            message(context, '未能打开解析网页');
                          }
                        }
                      },
              ),
          ],
        );
      },
    );
  }
}

Future<String?> showParserPasswordDialog(
  BuildContext context,
  ParserRuleHub hub,
  String siteId, {
  Future<String> Function(String command)? resolveUcPassword,
  AppServices? services,
}) async {
  final site = hub.sites.where((s) => s.id == siteId).firstOrNull;
  if (site == null && siteId == 'mf_dg22' && hub.builtinPasswordAvailable) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _BuiltinParserPasswordDialog(hub: hub, services: services),
    );
  }
  if (site == null) {
    message(context, '当前通道尚未连接共享密码服务，请稍后重试');
    return null;
  }
  if (!site.rule.requiresPassword) return '';
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ParserPasswordDialog(
      hub: hub,
      site: site,
      resolveUcPassword: resolveUcPassword,
    ),
  );
}

// Deliberately limited to the existing built-in parser with no configured Hub.
// The original parser still checks the password on the actual list request.
class _BuiltinParserPasswordDialog extends StatefulWidget {
  const _BuiltinParserPasswordDialog({required this.hub, this.services});
  final ParserRuleHub hub;
  final AppServices? services;

  @override
  State<_BuiltinParserPasswordDialog> createState() =>
      _BuiltinParserPasswordDialogState();
}

class _BuiltinParserPasswordDialogState
    extends State<_BuiltinParserPasswordDialog> {
  final input = TextEditingController();
  bool busy = false;
  String error = '';

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final grant = await widget.hub.grantBuiltinPassword(input.text.trim());
      if (mounted) Navigator.pop(context, grant);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openGuide() async {
    try {
      final opened = await launchUrl(
        Uri.parse(MobilePasswordGuide.pageUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) setState(() => error = '无法打开领取说明，请在浏览器中打开');
    } catch (_) {
      if (mounted) setState(() => error = '无法打开领取说明，请在浏览器中打开');
    }
  }

  Future<void> _readMobileGuide() async {
    final services = widget.services;
    if (services == null) return;
    setState(() {
      busy = true;
      error = '';
    });
    String? command;
    try {
      command = await MobilePasswordGuide(services.cloud.http).read();
    } catch (_) {
      if (mounted) setState(() => error = '无法自动读取当前口令，请打开领取说明并复制口令');
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted && command != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CloudCommandPage(services, initialText: command!),
        ),
      );
    }
  }

  Future<void> _openMobileCommand() async {
    final services = widget.services;
    if (services == null) return;
    final clipboard =
        (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted) return;
    final command = C139Passcode.parse(clipboard.trim());
    if (command == null) {
      setState(() => error = '请先从领取说明复制当前移动云盘口令');
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CloudCommandPage(services, initialText: clipboard.trim()),
      ),
    );
    if (mounted) setState(() => error = '');
  }

  Future<void> _importArchive() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: '密码 ZIP / TXT', extensions: ['zip', 'txt']),
        ],
      );
      if (file == null || !mounted) return;
      final limit = file.name.toLowerCase().endsWith('.zip')
          ? MobilePasswordArchive.maxArchiveBytes
          : MobilePasswordArchive.maxTextBytes;
      if (await file.length() > limit) {
        throw const FormatException('文件大小超出限制');
      }
      final bytes = await file.readAsBytes();
      final value = file.name.toLowerCase().endsWith('.zip')
          ? MobilePasswordArchive.fromZip(bytes)
          : MobilePasswordArchive.fromText(bytes);
      if (mounted) {
        setState(() {
          input.text = value;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '无法读取密码，请选择当天的 ZIP 或 UTF-8 TXT，确认第一行格式');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('百度公益解析 · 手动密码'),
    scrollable: true,
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本构建未配置共享密码服务。请按公益解析站的说明获得当前有效解析密码。它与百度提取码不同，仅保存在本次运行的内存中，由原站验证。',
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开公益解析原站'),
            onPressed: () async {
              try {
                final ok = await launchUrl(
                  Uri.parse('https://mf.dg22.top/user/parse'),
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && mounted) {
                  setState(
                    () => error = '请在浏览器打开 https://mf.dg22.top/user/parse',
                  );
                }
              } catch (_) {
                if (mounted) {
                  setState(
                    () => error = '请在浏览器打开 https://mf.dg22.top/user/parse',
                  );
                }
              }
            },
          ),
          const Text('移动云盘领取：读取公开说明中的当前口令，登录后按要求转存当天 ZIP，下载后导入。'),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : _openGuide,
                child: const Text('领取说明'),
              ),
              if (widget.services != null)
                TextButton(
                  onPressed: busy ? null : _readMobileGuide,
                  child: const Text('读取最新移动口令'),
                ),
              if (widget.services != null)
                TextButton(
                  onPressed: busy ? null : _openMobileCommand,
                  child: const Text('解析剪贴板移动口令'),
                ),
              TextButton.icon(
                key: const ValueKey('builtin-parser-password-import'),
                onPressed: busy ? null : _importArchive,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('导入 ZIP / TXT'),
              ),
            ],
          ),
          TextField(
            key: const ValueKey('builtin-parser-password-input'),
            controller: input,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '当前解析密码',
              errorText: error.isEmpty ? null : error,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (!busy && input.text.trim().isNotEmpty) _submit();
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('builtin-parser-password-submit'),
        onPressed: busy || input.text.trim().isEmpty ? null : _submit,
        child: const Text('继续解析'),
      ),
    ],
  );
}

Future<T?> withParserPassword<T>(
  BuildContext context,
  ParserRuleHub hub,
  Future<T> Function(String? grant) action, {
  String? initialGrant,
  ValueChanged<String>? onGranted,
  String label = '正在解析…',
  Future<String> Function(String command)? resolveUcPassword,
}) async {
  var grant = initialGrant;
  while (context.mounted) {
    final result = await busy<(T?, ParserPasswordRequired?)>(context, () async {
      try {
        return (await action(grant), null);
      } on ParserPasswordRequired catch (error) {
        return (null, error);
      }
    }, label: label);
    if (result == null || !context.mounted) return null;
    if (result.$2 == null) return result.$1;
    grant = await showParserPasswordDialog(
      context,
      hub,
      result.$2!.siteId,
      resolveUcPassword: resolveUcPassword,
    );
    if (grant == null || !context.mounted) return null;
    onGranted?.call(grant);
  }
  return null;
}

class _ParserPasswordDialog extends StatefulWidget {
  const _ParserPasswordDialog({
    required this.hub,
    required this.site,
    this.resolveUcPassword,
  });
  final ParserRuleHub hub;
  final ParserSite site;
  final Future<String> Function(String command)? resolveUcPassword;
  @override
  State<_ParserPasswordDialog> createState() => _ParserPasswordDialogState();
}

class _ParserPasswordDialogState extends State<_ParserPasswordDialog> {
  final input = TextEditingController();
  bool busy = true, available = false, visible = false, needsPassword = false;
  bool verifiedByInput = false;
  String status = '正在读取共享密码…', submissionId = '';
  ParserSite get site => widget.hub.currentSite(widget.site.id) ?? widget.site;
  bool get inputOnly =>
      site.id == 'mf_dg22' ||
      !site.passwordPrompt.autoFill ||
      (site.passwordPrompt.webFlow != null &&
          !site.passwordPrompt.webFlow!.sharePassword);
  bool get canContinue =>
      available && (input.text.isEmpty && (!inputOnly || verifiedByInput));
  @override
  void initState() {
    super.initState();
    input.addListener(_inputChanged);
    _refresh();
  }

  void _inputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        busy = true;
        available = false;
        verifiedByInput = false;
        needsPassword = false;
        status = '正在读取共享密码…';
      });
    }
    unawaited(widget.hub.refresh(force: true));
    try {
      if (site.passwordPrompt.webFlow != null && inputOnly) {
        setState(() {
          needsPassword = true;
          status = '';
        });
        return;
      }
      if (inputOnly) {
        await widget.hub.passwordMetadata(widget.site.id);
        if (mounted) {
          setState(() {
            needsPassword = true;
            status = '';
          });
        }
        return;
      }
      await widget.hub.password(widget.site.id, force: true);
      if (mounted) {
        setState(() {
          available = true;
          status = '当前无需输入密码，可直接解析';
        });
      }
    } on ParserPasswordRequired {
      if (mounted) {
        setState(() {
          available = false;
          needsPassword = true;
        });
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      available = false;
      verifiedByInput = false;
      needsPassword = false;
      status = site.passwordPrompt.webFlow == null ? '正在验证密码，请稍候…' : '正在继续解析…';
    });
    try {
      final flow = site.passwordPrompt.webFlow;
      if (flow != null) {
        final grant = await widget.hub.grantLocalPassword(
          site.id,
          input.text,
          flowFingerprint: flow.fingerprint,
        );
        if (mounted) Navigator.pop(context, grant);
        return;
      }
      final result = await widget.hub.submitPassword(
        widget.site.id,
        input.text,
      );
      if (!mounted) return;
      _apply(result);
      if (result.str('status') == 'accepted') {
        final grant = await widget.hub.grantPassword(widget.site.id);
        if (mounted) Navigator.pop(context, grant);
      } else if (available) {
        input.clear();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _apply(Json result) {
    setState(() {
      available = result.str('status') == 'accepted';
      verifiedByInput = available;
      needsPassword = result.str('status') == 'rejected';
      submissionId = {'pending', 'verifying'}.contains(result.str('status'))
          ? result.str('submissionId').ifEmpty(result.str('id'))
          : '';
      status = switch (result.str('status')) {
        'accepted' => '密码验证通过，现在可以继续解析。',
        'pending' || 'verifying' => '密码已提交，等待验证或管理员审核。稍后可查看审核结果。',
        'rejected' => '',
        'superseded' => '共享密码已有更新，请重新获取。',
        _ => '原站暂时无法验证（可能是网络、额度或接口故障），已有共享密码会保留，请稍后重试。',
      };
    });
  }

  Future<void> _obtainWeb() async {
    setState(() => busy = true);
    try {
      await widget.hub.refresh(force: true);
      if (!mounted) return;
      final current = widget.hub.currentSite(widget.site.id);
      final flow = current?.passwordPrompt.webFlow;
      if (current == null || flow == null) {
        throw const AppException('网页取密规则已更新，请重新打开密码窗口');
      }
      final value = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => ParserPasswordWebPage(
            siteId: current.id,
            siteName: current.name,
            flow: flow,
            directory: widget.hub.root,
            documentHttp: widget.hub.passwordDocumentHttp,
            resolveUcPassword: widget.resolveUcPassword,
          ),
        ),
      );
      if (!mounted || value == null) return;
      final grant = await widget.hub.grantLocalPassword(
        current.id,
        value,
        flowFingerprint: flow.fingerprint,
      );
      if (mounted) {
        unawaited(widget.hub.shareGrantedPassword(current.id, grant));
        Navigator.pop(context, grant);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _check() async {
    setState(() {
      busy = true;
      needsPassword = false;
      status = '正在查询验证结果…';
    });
    try {
      final result = await widget.hub.submission(submissionId);
      if (!mounted) return;
      _apply(result);
      if (available) {
        await widget.hub.password(widget.site.id, force: true);
        final grant = await widget.hub.grantPassword(widget.site.id);
        if (mounted) Navigator.pop(context, grant);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() {
      available = false;
      needsPassword = error is ParserPasswordRequired;
      status = needsPassword ? '' : errorText(error);
    });
  }

  Future<void> _continue() async {
    if (inputOnly && !verifiedByInput) return;
    setState(() => busy = true);
    try {
      final grant = await widget.hub.grantPassword(site.id);
      if (mounted) Navigator.pop(context, grant);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.hub,
    builder: (context, _) {
      final site = this.site;
      final prompt = site.passwordPrompt;
      final title = prompt.title.isEmpty ? '${site.name} · 解析密码' : prompt.title;
      final obtainUri = Uri.tryParse(site.obtainUrl);
      final showObtain =
          prompt.buttonEnabled &&
          obtainUri != null &&
          {'http', 'https'}.contains(obtainUri.scheme) &&
          obtainUri.host.isNotEmpty &&
          obtainUri.userInfo.isEmpty;
      return PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: SelectableText(title),
          content: SizedBox(
            width: 480,
            height: math.min(540, MediaQuery.sizeOf(context).height * .58),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('parser-password-copy'),
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('复制内容'),
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(
                              text: [
                                title,
                                prompt.message,
                                if (site.guide.isNotEmpty) site.guide,
                                if (showObtain) site.obtainUrl,
                              ].join('\n\n'),
                            ),
                          );
                          if (context.mounted) message(context, '内容已复制');
                        } catch (_) {
                          if (context.mounted) {
                            message(context, '复制失败，请长按文字选择复制');
                          }
                        }
                      },
                    ),
                  ),
                  if (prompt.format == 'markdown')
                    AnnouncementMarkdown(prompt.message)
                  else
                    SelectableText(
                      prompt.message,
                      style: const TextStyle(height: 1.6),
                    ),
                  if (!needsPassword &&
                      status.isNotEmpty &&
                      !(inputOnly && available && !verifiedByInput))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SelectableText(
                        status,
                        key: const ValueKey('parser-password-status'),
                        style: TextStyle(
                          height: 1.6,
                          color: status == '当前无需输入密码，可直接解析'
                              ? Colors.red
                              : secondary(context),
                        ),
                      ),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (site.guide.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SelectableText(
                        site.guide,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                  if (prompt.buttonEnabled &&
                      prompt.webFlow != null &&
                      ParserPasswordWebPage.isSupported)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('parser-password-web-obtain'),
                          onPressed: busy ? null : _obtainWeb,
                          icon: const Icon(
                            Icons.auto_fix_high_outlined,
                            size: 18,
                          ),
                          label: const Text('网页获取并继续'),
                        ),
                      ),
                    ),
                  if (showObtain)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          key: const ValueKey('parser-password-obtain'),
                          icon: const Icon(Icons.open_in_new, size: 17),
                          label: Text(
                            prompt.buttonText,
                            textAlign: TextAlign.center,
                          ),
                          onPressed: busy
                              ? null
                              : () async {
                                  var opened = false;
                                  try {
                                    opened = await launchUrl(
                                      obtainUri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (_) {
                                    // Some devices report a missing browser as an exception.
                                  }
                                  if (!opened && context.mounted) {
                                    message(context, '无法打开获取页面');
                                  }
                                },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('parser-password-input'),
                    controller: input,
                    enabled: !busy,
                    obscureText: !visible,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: '当前解析密码',
                      hintText: '按原文填写，支持中文、字母和符号',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => visible = !visible),
                        icon: Icon(
                          visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!busy) {
                        canContinue ? _continue() : _submit();
                      }
                    },
                  ),
                  for (final url in site.guideImages)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AnnouncementMarkdown('![获取密码操作说明](<$url>)'),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '这是解析站的访问密码，无需填写网盘账号密码。',
                    style: TextStyle(fontSize: 12, color: secondary(context)),
                  ),
                  if (submissionId.isNotEmpty && !available)
                    TextButton(
                      onPressed: busy ? null : _check,
                      child: const Text('查看审核结果'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: busy ? null : _refresh,
              child: const Text('重新获取'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : canContinue
                  ? _continue
                  : input.text.trim().isEmpty
                  ? null
                  : _submit,
              child: Text(
                canContinue || prompt.webFlow != null ? '继续解析' : '验证',
              ),
            ),
          ],
        ),
      );
    },
  );
}
