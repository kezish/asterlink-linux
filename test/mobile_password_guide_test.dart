import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:asterlink/data/password_sources/mobile_password_guide.dart';

void main() {
  test('reads unique published mobile code', () {
    const code = '甲乙丙丁戊己庚辛壬';
    expect(
      MobilePasswordGuide.extract(
        '<article><pre><code>$code</code></pre></article>',
      ),
      code,
    );
  });
  test('rejects unrelated content or conflicting published codes', () {
    expect(
      () => MobilePasswordGuide.extract('<pre>not-a-code</pre>'),
      throwsA(anything),
    );
    expect(
      () => MobilePasswordGuide.extract(
        '<pre>甲乙丙丁戊己庚辛壬</pre><pre>春夏秋冬东西南北中</pre>',
      ),
      throwsA(anything),
    );
  });
  final fixture = Platform.environment['ASTERLINK_PUBLIC_GUIDE_FIXTURE'];
  if (fixture != null) {
    test('reads real public guide without printing its code', () {
      expect(
        MobilePasswordGuide.extract(
          File(fixture).readAsStringSync(),
        ).isNotEmpty,
        isTrue,
      );
    });
  }
}
