#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

COMP=mrvaagent
IMG=mrva-agent
SRC="$STATE/generated/$COMP"
CTX="$SRC/context"
LOG="$STATE/logs/$COMP/image.log"

if [[ "${1:-}" == "-h" ]]; then
cat <<EOFH
build-image-mrvaagent.sh

Assembles mrvaagent container image.

Reads:
  - $SRC/mrvaagent
  - entrypoint.sh
  - mrva-docker/containers/agent/Dockerfile

Writes:
  - Docker image: $IMG:$MRVA_VERSION
  - $LOG
  - $STATE/verified/$COMP.image.ok
EOFH
exit 0
fi

mkdir -p "$CTX" "$STATE/logs/$COMP"
cp "$SRC/mrvaagent" "$CTX/mrvaagent"
cp "$MRVA_SYSTEM_ROOT/submodules/mrva-docker/containers/agent/entrypoint.sh" "$CTX/entrypoint.sh"

docker build \
  -f "$MRVA_SYSTEM_ROOT/submodules/mrva-docker/containers/agent/Dockerfile" \
  -t "$IMG:$MRVA_VERSION" \
  "$CTX" >"$LOG" 2>&1

touch "$STATE/verified/$COMP.image.ok"
