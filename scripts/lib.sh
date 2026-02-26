#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MRVA_SYSTEM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCRATCH="$MRVA_SYSTEM_ROOT/deploy-scratch"
STATE="$SCRATCH/state"

# Spec
. "$MRVA_SYSTEM_ROOT/spec/version.conf"

# Canonical in-container workspace
WORKROOT=/work-gh/mrva

mkdir -p \
  "$STATE"/{config,generated,logs,verified}
