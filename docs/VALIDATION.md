# Linux port verification record — 2026-11-22

## Exact source baseline
- Upstream tag: `v2.3.5+235`
- Upstream commit: `1b2fc62`
- Linux integration: `linux/develop` (see `git log`)
- Reference port: `winter110/parse-link` branch `develop` commit `09d78dd`

## Observed outcomes on dawn16 NixOS

| Subsystem | Status | Evidence |
| --- | --- | --- |
| Linux Gopeed compilation | PASS | `native/bin/asterlink_gopeed`; JSON version+close protocol smoke |
| Native HTTP/2 route capability | PASS (advertised capability) | `parserHttp2: true` |
| QuickJS Linux library compilation | PASS | `build/quickjs-native/libasterlink_js.so` |
| QuickJS context allocation | PASS | FFI open, new, close |
| Linux desktop platform unit tests | PASS | `flutter test test/linux_desktop_platform_test.dart` |
| Link parser unit tests | PASS | `flutter test test/link_parser_test.dart` |
| Baidu anonymous parser fixtures | PASS | 23 tests |
| Baidu public-parser password fixtures | PASS | 50 tests |
| Search source adapters | PASS | 8 tests |
| Search engine suite | PARTIAL | 17 tests pass; 1 upstream baseline test fails |
| Changed Dart file static analysis | PASS | 6 targeted files; no issues |
| Flutter Linux GUI binary | NOT VERIFIED | build pending |
| Linux headless browser search | FALLBACK | existing backend fallback, native WebKit search not yet wired |
| Live anonymous Baidu download | NOT VERIFIED | no known public share test file used |
| Live search | NOT VERIFIED | requires backend and source probes |

## Upstream baseline inconsistency

`test/client_search_test.dart`, around line 396, expects the persisted
search cache to be encrypted and asserts that the JSON share domain
`pan.quark.cn` does not appear in the raw state file.

At the exact official `v2.3.5+235` tag, `lib/data/state_store.dart`
writes JSON with `format: asterlink-state-v2`, `sha256` and `data`.
This is plaintext with an integrity checksum, so the test fails.
The same upstream release contains both the implementation and assertion.
This is **not introduced by Linux platform changes**. Keep the upstream test
intact and track it separately. Beware: user account credentials may also
be present in the local plaintext application state file.

Do not claim an encrypted state format or advertise security guarantees
from an SHA-256 checksum. Limit file permissions, avoid syncing credentials,
and prefer upstream reconciliation of the storage security design.

## Current limitations

The Linux headless WebView implementation required by browser-based local
search sources has not been implemented. The client records
`search.browser_fallback` and invokes upstream server fallback. Results
depend on remote backend availability.

No GitHub remote owned by the user for this new project has been created.
The local branch can be published when a new remote exists.
