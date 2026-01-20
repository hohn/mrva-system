#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

COMP=gh-mrva
SRC="$MRVA_SYSTEM_ROOT/submodules/gh-mrva"
OUT="$STATE/generated/$COMP"
LOG="$STATE/logs/$COMP/build.log"

if [[ "${1:-}" == "-h" ]]; then
cat <<EOFH
build-gh-mrva.sh

Builds gh-mrva inside mrva-platform.

Reads:
  - $SRC
  - $MRVA_SYSTEM_ROOT/submodules/mrvacommander
  - spec/version.conf

Writes:
  - $OUT/gh-mrva
  - $LOG
  - $STATE/verified/$COMP.ok
EOFH
exit 0
fi

mkdir -p "$OUT" "$STATE/logs/$COMP"

docker run --rm \
  -v "$SRC:$WORKROOT/gh-mrva:ro" \
  -v "$MRVA_SYSTEM_ROOT/submodules/mrvacommander:$WORKROOT/mrvacommander:ro" \
  -v "$OUT:$WORKROOT/out" \
  mrva-platform:"$MRVA_VERSION" \
  sh -c "
    cd $WORKROOT/gh-mrva &&
    go build -o $WORKROOT/out/gh-mrva
  " >"$LOG" 2>&1

touch "$STATE/verified/$COMP.ok"
