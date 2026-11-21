import '../../core/json.dart';
import '../../domain/c139_passcode.dart';
import '../http.dart';
import '../providers/baidu_public_command.dart';

/// Reuse the publisher's public document reader. Do not access private
/// document fields or execute its scripts.
class MobilePasswordGuide {
  MobilePasswordGuide(this.http);
  final JsonHttp http;
  static const pageUrl = BaiduPublicCommandSource.pageUrl;

  static String validate(String text) {
    final code = C139Passcode.parse(text.trim());
    require(code != null, '公开领取说明没有有效的移动云盘口令，请手动核对');
    return text.trim();
  }

  static String extract(String page) =>
      validate(BaiduPublicCommandSource.extract(page));

  Future<String> read() async =>
      validate(await BaiduPublicCommandSource(http).read());
}
