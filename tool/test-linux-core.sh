#!/usr/bin/env bash
# Offline smoke tests for parser, search, and Linux-only platform integration.
set -euo pipefail
cd "$(dirname "$0")/.."
printf 'upstream=%s\n' "$(git describe --tags --abbrev=0 2>/dev/null || echo unknown)"
printf 'commit=%s\n' "$(git rev-parse --short HEAD)"
printf 'flutter=%s\n' "$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
flutter pub get
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
