#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "${1:-}" == "-h" ]]; then
cat <<'EOFH'
orchestrate-build.sh

Linear, authoritative MRVA build sequence.

Order:
  1. prepare-scratch.sh
  2. build-mrvaplatform.sh
  3. build-gh-mrva.sh
  4. build-mrvaagent.sh
  5. build-mrvaserver.sh
  6. build-mrvahepc.sh
  7. build-image-gh-mrva.sh
  8. build-image-mrvaagent.sh
  9. build-image-mrvaserver.sh
 10. build-image-mrvahepc.sh

Properties:
  - No implicit state
  - Order is authoritative here
  - Individual scripts remain independently runnable
EOFH
exit 0
fi

run() {
  echo
  echo "=== $1 ==="
  "$SCRIPT_DIR/$1"
}

run prepare-scratch.sh
run build-mrvaplatform.sh

run build-gh-mrva.sh
run build-mrvaagent.sh
run build-mrvaserver.sh
run build-mrvahepc.sh

run build-image-gh-mrva.sh
run build-image-mrvaagent.sh
run build-image-mrvaserver.sh
run build-image-mrvahepc.sh

echo
echo "MRVA build completed successfully."
