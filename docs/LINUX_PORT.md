# AsterLink Linux port

## Baselines

- Upstream: https://github.com/z7786/wenxi (read-only remote: upstream).
- Release baseline: v2.3.5+235, commit 1b2fc62, 2026-11-16.
- Linux reference: https://github.com/winter110/parse-link (read-only remote: linux-reference), develop commit 09d78dd, 2026-11-03.
- Working integration branch: linux/develop. Keep upstream source changes small and isolated.

## Scope

P0: Linux runner, native Gopeed helper, filesystem, parser public route.
P1: server search and local QuickJS source execution.
P2: browser-assisted search source transport / WebKitGTK bridge.
P3: full search -> parse -> file selection -> download and diagnostics.
P4: other cloud accounts, player, uploads, cross-transfer, LAN.

Search paths: lib/data/resource_search_api.dart, lib/data/client_search_engine.dart,
lib/data/client_search_host.dart, lib/data/sources/, vendor_plugins/asterlink_js/.
Parser paths: lib/data/parser_rules/, lib/data/providers/baidu_public_parser.dart,
lib/data/providers/baidu_public_password.dart, lib/data/cloud_repository.dart.

## Development

    nix develop
    bash tool/test-linux-core.sh
    nix develop .#full
    bash tool/build-linux.sh

No NixOS global packages or service modifications required. Keep Gopeed alongside
the AsterLink executable, and the QuickJS library in the Flutter bundle lib directory.

For a small test loop (after build dependencies are available):

    flutter test test/link_parser_test.dart
    flutter test test/baidu_public_parser_test.dart
    ASTERLINK_JS_LIBRARY="$(pwd)/build/linux/x64/release/bundle/lib/libasterlink_js.so" flutter test test/client_search_test.dart

## Upstream integration

    git fetch upstream main --tags
    git log --oneline --decorate HEAD..upstream/main
    git tag --list 'v*' --sort=-version:refname | head
    git diff --stat v2.3.5+235..upstream/main -- lib/data/providers lib/data/parser_rules lib/data/client_search_engine.dart

Prefer merging upstream release tags into a feature/integration branch; do not
force reset the Linux branch to a moving upstream commit. Commit Linux-only changes
separately. Never cherry-pick older source-layer files wholesale over a newer release.

Review each update to dynamic search source signatures or parser rules carefully.
The remote backend, parser sites, and cloud providers may fail independently.

## Baseline status

At start: no native Linux artifact validated against upstream v2.3.5. Tests
and live third-party parser/search functionality must be recorded separately.
The Linux reference v2.1.0 published a DEB, but this is not proof of compatibility
with the 2.3.5 backend.

## Diagnostics

For each failing attempt, record upstream_commit, linux_commit, Flutter version,
Go version, parser_bundle_id, source_manifest_revision, parser_site_id, search_source_id,
phase, elapsed_ms, and HTTP/error status. Do not record credentials, full share
links, signed download URLs, source HTML, plaintext passwords, or user queries.

Minimum separate outcome fields:
- compile: passed/failed/not_checked
- offline_parser: passed/failed/not_checked
- offline_search_quickjs: passed/failed/not_checked
- live_parser: passed/failed/not_checked
- live_search: passed/failed/not_checked
- full_download: passed/failed/not_checked

## Current status

See docs/VALIDATION.md for exact command outcomes, expected upstream
plaintext-cache test inconsistency, and live service limitations.
The Linux bundle builds successfully with Flutter 3.41.9 and archive 4.4.0.
Headless browser-based search sources use a backend fallback on Linux;
full WebKitGTK search-source support remains incomplete.

Local build output: build/linux/x64/release/bundle/ (not yet a Nix package).
The bundle and its Gopeed helper need to be kept together.

## Linux download / shutdown regression

The running application could reject downloads with `应用正在退出` after a
failed close. Diagnostics showed app.close_failed: MissingPluginException
for the native foreground channel during DownloadManager.close/pauseAll.
The preceding Linux tray initialization had also failed at unsupported
setToolTip. Linux is a desktop platform but does not implement the native
transfer foreground bridge available on Android, Windows and macOS.
Restrict that bridge to supported platforms, skip the unsupported tray API,
and do not return to a usable-looking UI after irreversible service closure.
This does not disable normal Linux Gopeed transfers.

Verified on dawn16: 68 selected download/keepalive/feedback tests pass;
additional Linux runtime test uses AppServices(platformFeatures: true),
real DesktopGopeedTransport, loopback HTTP server, real PlatformFileAccess,
32 KiB exact byte comparison, pause and full AppServices.close. Passed.
The test does not read or modify the user's cloud account state.
