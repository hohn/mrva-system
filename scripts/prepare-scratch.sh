#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRATCH="$ROOT/deploy-scratch"

if [[ "${1:-}" == "-h" ]]; then
cat <<'HLP'
prepare-scratch.sh

Reads:
  - none

Writes:
  - deploy-scratch/state/*
  - deploy-scratch/README.org

Produces:
  - deploy-scratch/state/verified/scratch.initialized

Idempotent: yes
HLP
exit 0
fi

mkdir -p "$SCRATCH"/{env,run}
mkdir -p "$SCRATCH/state"/{config,generated,logs,verified}

README="$SCRATCH/README.org"
if [ ! -f "$README" ]; then
cat > "$README" <<'EOF2'
#+TITLE: MRVA Deployment Scratch

Instance-specific, mutable deployment state.
Not a git repository.
Safe to delete and recreate.

mrva-system is the blueprint.
deploy-scratch is the scratch paper.
EOF2
fi

touch "$SCRATCH/state/verified/scratch.initialized"
