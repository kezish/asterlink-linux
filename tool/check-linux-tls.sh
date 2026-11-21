#!/usr/bin/env bash
# Run in nix develop .#full. No credentials or TLS verification override.
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/probe.c" <<'C'
#include <gio/gio.h>
#include <stdio.h>
int main(void) {
  GTlsBackend *backend = g_tls_backend_get_default();
  gboolean supported = g_tls_backend_supports_tls(backend);
  GTlsDatabase *db = supported ? g_tls_backend_get_default_database(backend) : NULL;
  printf("GIO TLS backend: %s; TLS=%s; trust database=%s\n",
    G_OBJECT_TYPE_NAME(backend), supported ? "yes" : "no",
    db ? G_OBJECT_TYPE_NAME(db) : "none");
  return supported && db ? 0 : 1;
}
C
cc "$tmp/probe.c" -o "$tmp/probe" $(pkg-config --cflags --libs gio-2.0)
"$tmp/probe"
