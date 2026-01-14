#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MRVA_SYSTEM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCRATCH_DIR="$MRVA_SYSTEM_ROOT/deploy-scratch"

# -----------------------------------------------------------------------------
# prepare-scratch.sh
#
# Create a fresh deployment scratch directory.
#
# This directory holds all mutable, instance-specific state.
# It is NOT a git repository.
#
# mrva-system is the blueprint.
# deploy-scratch is the scratch paper.
# -----------------------------------------------------------------------------

echo "==> Preparing deployment scratch directory: $SCRATCH_DIR"

# Top-level
mkdir -p "$SCRATCH_DIR"

# State hierarchy
mkdir -p "$SCRATCH_DIR/state"/{config,generated,verified,logs}

# Execution helpers
mkdir -p "$SCRATCH_DIR/run"

# Local notes / environment
mkdir -p "$SCRATCH_DIR/env"

# Instance README (only created if missing)
README="$SCRATCH_DIR/README.org"
if [ ! -f "$README" ]; then
    cat > "$README" <<'EOF'
#+TITLE: MRVA Deployment Scratch

This directory contains instance-specific, mutable deployment state.

- It is not a git repository.
- It may be modified freely.
- It may be deleted and recreated at any time.

Authoritative definitions live in the mrva-system repository.

Use this file for:
- local notes
- site-specific decisions
- operational observations
EOF
fi

echo "==> Scratch directory ready"
echo "    Path: $SCRATCH_DIR"

# Explicit success marker (optional but useful)
touch "$SCRATCH_DIR/state/verified/scratch.initialized"
