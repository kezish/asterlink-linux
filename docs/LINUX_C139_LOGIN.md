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
