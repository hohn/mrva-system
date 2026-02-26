#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

COMP=mrvahepc
SRC="$MRVA_SYSTEM_ROOT/submodules/mrvahepc"
OUT="$STATE/generated/$COMP"
LOG="$STATE/logs/$COMP/build.log"

if [[ "${1:-}" == "-h" ]]; then
cat <<EOFH
build-mrvahepc.sh

Stages mrvahepc tree for container assembly.

Reads:
  - $SRC

Writes:
  - $OUT/mrvahepc/*
  - $LOG
  - $STATE/verified/$COMP.ok
EOFH
exit 0
fi

mkdir -p "$OUT" "$STATE/logs/$COMP"

rsync -a \
  --exclude='.git' \
  --exclude='venv' \
  "$SRC/" "$OUT/mrvahepc/" >"$LOG" 2>&1

touch "$STATE/verified/$COMP.ok"
