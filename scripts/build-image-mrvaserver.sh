#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

COMP=mrvaserver
IMG=mrva-server
SRC="$STATE/generated/$COMP"
CTX="$SRC/context"
LOG="$STATE/logs/$COMP/image.log"

if [[ "${1:-}" == "-h" ]]; then
cat <<EOFH
build-image-mrvaserver.sh

Assembles mrvaserver container image.

Reads:
  - $SRC/mrvaserver
  - entrypoint.sh
  - mrva-docker/containers/server/Dockerfile

Writes:
  - Docker image: $IMG:$MRVA_VERSION
  - $LOG
  - $STATE/verified/$COMP.image.ok
EOFH
exit 0
fi

mkdir -p "$CTX" "$STATE/logs/$COMP"
cp "$SRC/mrvaserver" "$CTX/mrvaserver"
cp "$MRVA_SYSTEM_ROOT/submodules/mrva-docker/containers/server/entrypoint.sh" "$CTX/entrypoint.sh"

docker build \
  -f "$MRVA_SYSTEM_ROOT/submodules/mrva-docker/containers/server/Dockerfile" \
  -t "$IMG:$MRVA_VERSION" \
  "$CTX" >"$LOG" 2>&1

touch "$STATE/verified/$COMP.image.ok"
