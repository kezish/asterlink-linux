import 'package:flutter_test/flutter_test.dart';
import 'package:asterlink/platform/desktop_platform.dart';

void main() {
  test('linux executable is colocated with the desktop bundle', () {
    expect(
      desktopDownloadExecutable('/opt/asterlink/asterlink', 'linux'),
      '/opt/asterlink/asterlink_gopeed',
    );
  });

  test('windows executable retains its original naming', () {
    expect(
      desktopDownloadExecutable(r'C:\AsterLink\asterlink.exe', 'windows'),
      r'C:\AsterLink\asterlink_gopeed.exe',
    );
  });

  test('unsupported desktop platform is rejected', () {
    expect(
      () => desktopDownloadExecutable('/opt/app', 'android'),
      throwsA(anything),
    );
  });
}
