# Linux mobile-cloud web login

The upstream flutter_inappwebview 6.1.5 login flow cannot initialize its
CookieManager on Linux. A detached WebKitGTK 4.1 plugin from the Linux reference
port is now used only by the C139 login route. Other platform login paths are
unchanged. The plugin import and local adaptation are separate commits.

Open the normal provider login page in the isolated GTK window, complete all
provider verification, and keep it open. Return to AsterLink and press Detect
and save login. Only C139's existing configured cookie URLs are read in this
session. The existing AccountLoginService checks credentials and account
ownership; no credentials are logged by the new page. Each root login has its
own ephemeral browser context; related SSO windows share that context. Cancel,
manual login, and successful completion close the native windows. Manual login
remains available. No browser profile outside AsterLink is read.

Regression: account/command/account-route tests (62) and a new mocked native
widget test (1) passed. Static analysis of the two login Dart files passed.
The native plugin compiled into the Flutter Linux bundle. Real provider login,
including any verification challenges, still requires interactive user testing.
The plugin is not yet integrated into browser-assisted search or other providers.

## Hybrid GPU / Wayland render fallback

On dawn16 with WebKitGTK 2.54.2 the native login window opened but was
blank, with `Failed to create EGL image from DMABuf`. The public provider
page returned HTTP 200. The runner now defaults to
`WEBKIT_DMABUF_RENDERER_FORCE_SHM=1` before GTK initialization, unless a
caller supplies an explicit WebKit renderer override. This keeps WebKit
shared-memory transport available and avoids disabling the entire backing store.
Use `nix develop .#full --command bash tool/run-linux.sh` for the existing
bundle too. To compare the default renderer, explicitly set
`WEBKIT_DMABUF_RENDERER_FORCE_SHM=0`. If necessary, test `GDK_BACKEND=x11`
with shared-memory mode. No global graphics driver or desktop setting is changed.
See https://bugs.webkit.org/show_bug.cgi?id=324730 and
https://bugs.webkit.org/show_bug.cgi?id=324551 for related WebKitGTK issues.
Actual visible rendering of the provider login window requires interactive
confirmation on the affected desktop.

## GIO TLS runtime

On dawn16 the WebKit window rendered TLS support is not available.
The original full shell had only the dconf GIO module directory and
selected GDummyTlsBackend. Adding the pinned glib-networking module
yielded GTlsBackendGnutls and a default trust database; libsoup returned
HTTP 200 from https://yun.139.com/w/.
The full shell now explicitly adds that module and preserves other
GIO directories. Certificate validation stays enabled. No global
system change or rebuild of the existing application is required.

Offline TLS self-check:
    nix develop .#full --command bash tool/check-linux-tls.sh

Launch:
    nix develop .#full --command bash tool/run-linux.sh
