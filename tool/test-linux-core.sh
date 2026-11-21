#!/usr/bin/env bash
# Offline smoke tests for parser, search, and Linux-only platform integration.
set -euo pipefail
cd "$(dirname "$0")/.."
printf 'upstream=%s\n' "$(git describe --tags --abbrev=0 2>/dev/null || echo unknown)"
printf 'commit=%s\n' "$(git rev-parse --short HEAD)"
printf 'flutter=%s\n' "$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
flutter pub get
mkdir -p native/bin
(
  cd native/gopeed
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOTOOLCHAIN=local go build -tags nosqlite -trimpath     -o ../../native/bin/asterlink_gopeed ./cmd/asterlink
)
python3 - <<'CHECK'
import json, subprocess
frames = b'{"seq":1,"method":"version","args":{}}\n{"seq":2,"method":"close","args":{}}\n'
out = subprocess.run(['native/bin/asterlink_gopeed'], input=frames, capture_output=True, check=True, timeout=8)
reply = json.loads(out.stdout.splitlines()[0])
assert reply['result']['protocol'] == 1
assert reply['result']['parserHttp2'] is True
print('Gopeed protocol smoke PASSED')
CHECK
cmake -S vendor_plugins/asterlink_js/src -B build/quickjs-native -DCMAKE_BUILD_TYPE=Release
cmake --build build/quickjs-native -j 2
export ASTERLINK_JS_LIBRARY="$(pwd)/build/quickjs-native/libasterlink_js.so"
test -s "$ASTERLINK_JS_LIBRARY"
flutter test test/linux_desktop_platform_test.dart
flutter test test/link_parser_test.dart
flutter test test/baidu_public_parser_test.dart
flutter test test/baidu_public_password_test.dart
flutter test test/client_search_test.dart
flutter test test/client_search_adapters_test.dart
echo "OFFLINE PARSER + SEARCH SMOKE PASSED"
