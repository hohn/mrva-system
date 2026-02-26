#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# MRVA GHCR Push Script
# ============================================================

usage() {
cat <<EOF
push-ghcr.sh

Usage:
  push-ghcr.sh [options]

Options:
  --version=X        Image version (default: 0.4.7)
  --registry=R       Registry prefix (default: ghcr.io/hohn)
  --user=U           GHCR username (default: hohn)
  --no-login         Skip docker login step
  -h, --help         Show this help and exit

Environment:
  GHCR_GITHUB_TOKEN  Required unless --no-login is used

Behavior:
  - Verifies required local images exist
  - Tags them under the registry
  - Pushes all images
  - Fails on any error
EOF
}

VERSION="0.4.7"
REGISTRY="ghcr.io/hohn"
USER="hohn"
DO_LOGIN=1

for arg in "$@"; do
    case "$arg" in
        --version=*) VERSION="${arg#*=}" ;;
        --registry=*) REGISTRY="${arg#*=}" ;;
        --user=*) USER="${arg#*=}" ;;
        --no-login) DO_LOGIN=0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $arg"; usage; exit 1 ;;
    esac
done

# ============================================================
# Images
# ============================================================

LOCAL_IMAGES=(
  "mrva-server"
  "mrva-agent"
  "mrva-gh-mrva"
  "mrva-hepc-container"
  "mrva-platform"
)

REMOTE_NAMES=(
  "mrva-server"
  "mrva-agent"
  "mrva-gh-mrva"
  "mrva-hepc"
  "mrva-platform"
)

# ============================================================
# Preflight Checks
# ============================================================

echo "Checking docker..."
docker info >/dev/null

for img in "${LOCAL_IMAGES[@]}"; do
    if ! docker image inspect "${img}:${VERSION}" >/dev/null 2>&1; then
        echo "Missing local image: ${img}:${VERSION}"
        exit 1
    fi
done

# ============================================================
# Login
# ============================================================

if [ "$DO_LOGIN" -eq 1 ]; then
    if [ -z "${GHCR_GITHUB_TOKEN:-}" ]; then
        echo "GHCR_GITHUB_TOKEN must be set"
        exit 1
    fi
    echo "Logging into $REGISTRY as $USER"
    echo "$GHCR_GITHUB_TOKEN" | docker login "${REGISTRY%%/*}" -u "$USER" --password-stdin
fi

# ============================================================
# Tag + Push
# ============================================================

for i in "${!LOCAL_IMAGES[@]}"; do
    LOCAL="${LOCAL_IMAGES[$i]}:${VERSION}"
    REMOTE="${REGISTRY}/${REMOTE_NAMES[$i]}:${VERSION}"

    echo "Tagging $LOCAL -> $REMOTE"
    docker tag "$LOCAL" "$REMOTE"

    echo "Pushing $REMOTE"
    docker push "$REMOTE"
done

echo
echo "All images pushed successfully."
