#!/usr/bin/env bash
# Start the locally built bundle; keep graphics workarounds application-scoped.
set -euo pipefail
cd "$(dirname "$0")/.."
bundle="$PWD/build/linux/x64/release/bundle"
export LD_LIBRARY_PATH="$bundle/lib:${LD_LIBRARY_PATH:-}"
if [[ ! -v WEBKIT_DMABUF_RENDERER_FORCE_SHM && ! -v WEBKIT_DISABLE_DMABUF_RENDERER ]]; then
  export WEBKIT_DMABUF_RENDERER_FORCE_SHM=1
fi
exec "$bundle/asterlink" "$@"
