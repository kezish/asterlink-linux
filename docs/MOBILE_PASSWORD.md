# Mobile cloud public password guide

Source: https://www.yuque.com/xwpzs/fbdtqk/tc7tfdy07d1cerae

The guide currently requests the latest published mobile-cloud command, a normal
transfer of the daily ZIP to the user's own cloud account, download, then reading
the password between equals signs on the first line of the TXT. The operator
explains that promotion funds the service and requests users not to bypass it.

The unconfigured community-build password dialog now reads the public Markdown
document via the existing BaiduPublicCommandSource, validates a mobile command,
and opens the existing CloudCommandPage. Clipboard input is a fallback. The
user chooses and transfers the daily archive using the normal account workflow.
Import ZIP/TXT fills the password field; the original parser validates it.
Passwords and downloaded text are not logged or stored by the import module.
The ZIP is read in memory with input/output bounds, CRC checks, no extraction
to disk, and no execution. Ambiguous TXT entries or first-line markers fail.

Verified: 71 targeted tests passed, including the current public Markdown
HTML captured on dawn16, C139 protocol/account fixtures, archive import and
manual password grants. Static analysis of changed modules passed.

Unverified: live C139 authentication and daily ZIP transfer/download because
no mobile-cloud account was configured locally at verification time; whether
third-party API transfers are credited under the operator's promotion rules.
No autonomous transfer or automatic daily password refresh is enabled. If the
provider requires an official app or additional promotion verification, follow
that flow, then import the downloaded ZIP/TXT. No private Hub credentials are
needed for this guided import workflow.
