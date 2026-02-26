#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

IMG=mrva-platform
LOG="$STATE/logs/platform/build.log"

if [[ "${1:-}" == "-h" ]]; then
    cat <<EOFH
build-mrvaplatform.sh

Builds the mrva-platform base image.

Reads:
  - spec/version.conf
  - mrva-docker/containers/platform/Dockerfile

Writes:
  - Docker image: mrva-platform:\$MRVA_VERSION
  - $LOG
  - $STATE/verified/platform.image.ok

Notes:
  - Pins CODEQL_VERSION
  - Use a single platform -- amd64 or arm64 -- for all steps to avoid cross-platform incompatibilities from docker
  - No 'latest' allowed
EOFH
    exit 0
fi

mkdir -p "$STATE/logs/platform"

docker build \
       --build-arg CODEQL_VERSION="$CODEQL_VERSION" \
       -f "$MRVA_SYSTEM_ROOT/submodules/mrva-docker/containers/platform/Dockerfile" \
       -t "$IMG:$MRVA_VERSION" \
       "$MRVA_SYSTEM_ROOT/submodules/mrva-docker/containers/platform" \
       >"$LOG" 2>&1

# Verify platform explicitly
docker inspect \
       --format '{{.Os}}/{{.Architecture}}' \
       "$IMG:$MRVA_VERSION" >>"$LOG"

touch "$STATE/verified/platform.image.ok"
