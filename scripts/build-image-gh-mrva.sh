#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

COMP=gh-mrva
IMG=mrva-gh-mrva
SRC="$STATE/generated/$COMP"
CTX="$SRC/context"
LOG="$STATE/logs/$COMP/image.log"

if [[ "${1:-}" == "-h" ]]; then
cat <<EOFH
build-image-gh-mrva.sh

Assembles gh-mrva container image.

Reads:
  - $SRC/gh-mrva
  - mrva-docker/containers/ghmrva/Dockerfile

Writes:
  - Docker image: $IMG:$MRVA_VERSION
  - $LOG
  - $STATE/verified/$COMP.image.ok
EOFH
exit 0
fi

mkdir -p "$CTX" "$STATE/logs/$COMP"
cp "$SRC/gh-mrva" "$CTX/gh-mrva"

docker build \
  -f "$MRVA_SYSTEM_ROOT/submodules/mrva-docker/containers/ghmrva/Dockerfile" \
  -t "$IMG:$MRVA_VERSION" \
  "$CTX" >"$LOG" 2>&1

touch "$STATE/verified/$COMP.image.ok"
