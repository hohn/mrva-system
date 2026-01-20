#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

COMP=mrvaserver
SRC="$MRVA_SYSTEM_ROOT/submodules/mrvaserver"
OUT="$STATE/generated/$COMP"
LOG="$STATE/logs/$COMP/build.log"

if [[ "${1:-}" == "-h" ]]; then
cat <<EOFH
build-mrvaserver.sh

Builds mrvaserver inside mrva-platform.

Reads:
  - $SRC
  - $MRVA_SYSTEM_ROOT/submodules/mrvacommander
  - spec/version.conf

Writes:
  - $OUT/mrvaserver
  - $LOG
  - $STATE/verified/$COMP.ok
EOFH
exit 0
fi

mkdir -p "$OUT" "$STATE/logs/$COMP"

docker run --rm \
  -v "$SRC:$WORKROOT/mrvaserver:ro" \
  -v "$MRVA_SYSTEM_ROOT/submodules/mrvacommander:$WORKROOT/mrvacommander:ro" \
  -v "$OUT:$WORKROOT/out" \
  mrva-platform:"$MRVA_VERSION" \
  sh -c "
    cd $WORKROOT/mrvaserver &&
    go build -o $WORKROOT/out/mrvaserver
  " >"$LOG" 2>&1

touch "$STATE/verified/$COMP.ok"
