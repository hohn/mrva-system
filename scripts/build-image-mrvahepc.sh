#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

COMP=mrvahepc
IMG=mrva-hepc-container
SRC="$STATE/generated/$COMP"
CTX="$SRC/context"
LOG="$STATE/logs/$COMP/image.log"

if [[ "${1:-}" == "-h" ]]; then
cat <<EOFH
build-image-mrvahepc.sh

Assembles mrvahepc container image.

Reads:
  - $SRC/mrvahepc/*
  - mrva-docker/containers/hepc/Dockerfile

Writes:
  - Docker image: $IMG:$MRVA_VERSION
  - $LOG
  - $STATE/verified/$COMP.image.ok
EOFH
exit 0
fi

mkdir -p "$CTX" "$STATE/logs/$COMP"
rsync -a "$SRC/mrvahepc/" "$CTX/mrvahepc/"

docker build \
  -f "$MRVA_SYSTEM_ROOT/submodules/mrva-docker/containers/hepc/Dockerfile" \
  -t "$IMG:$MRVA_VERSION" \
  "$CTX" >"$LOG" 2>&1

touch "$STATE/verified/$COMP.image.ok"
