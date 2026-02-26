#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

COMP=mrvaagent
SRC="$MRVA_SYSTEM_ROOT/submodules/mrvaagent"
OUT="$STATE/generated/$COMP"
LOG="$STATE/logs/$COMP/build.log"

if [[ "${1:-}" == "-h" ]]; then
cat <<EOFH
build-mrvaagent.sh

Builds mrvaagent inside mrva-platform.

Reads:
  - $SRC
  - $MRVA_SYSTEM_ROOT/submodules/mrvacommander
  - spec/version.conf

Writes:
  - $OUT/mrvaagent
  - $LOG
  - $STATE/verified/$COMP.ok
EOFH
exit 0
fi

mkdir -p "$OUT" "$STATE/logs/$COMP"

# XX: image can be
#   mrva-platform:"$MRVA_VERSION"
# or
#   $REG/mrva-platform:"$MRVA_VERSION" \

# docker run --rm \
#   -v "$SRC:$WORKROOT/mrvaagent:ro" \
#   -v "$MRVA_SYSTEM_ROOT/submodules/mrvacommander:$WORKROOT/mrvacommander:ro" \
#   -v "$OUT:$WORKROOT/out" \
#   mrva-platform:"$MRVA_VERSION" \
#   sh -c "
#     cd $WORKROOT/mrvaagent &&
#     go build -o $WORKROOT/out/mrvaagent
#   " >"$LOG" 2>&1

cd $SRC && go build -o $OUT


touch "$STATE/verified/$COMP.ok"
