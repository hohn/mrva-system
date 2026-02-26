#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# MRVA Container Image Download Script
# ============================================================

usage() {
cat <<EOF
download-containers.sh

Usage:
  download-containers.sh [options]

Options:
  --version=X.Y.Z    Override MRVA version (default: 0.4.8)
  --registry=R        Registry prefix (default: ghcr.io/hohn)
  -h, --help          Show this help and exit.

Behavior:
  - Pulls MRVA images (server, agent, hepc, gh-mrva) from the registry.
  - Also ensures infrastructure images (minio, rabbitmq, postgres) are present.
  - Skips images that are already available locally.
EOF
}

VERSION="0.4.8"
REGISTRY="ghcr.io/hohn"

for arg in "$@"; do
    case "$arg" in
        --version=*) VERSION="${arg#*=}" ;;
        --registry=*) REGISTRY="${arg#*=}" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $arg"; usage; exit 1 ;;
    esac
done

# ============================================================
# Image Definitions
# ============================================================

MRVA_IMAGES=(
    "$REGISTRY/mrva-server:$VERSION"
    "$REGISTRY/mrva-agent:$VERSION"
    "$REGISTRY/mrva-hepc:$VERSION"
    "$REGISTRY/mrva-gh-mrva:$VERSION"
)

INFRA_IMAGES=(
    "minio/minio:RELEASE.2024-06-11T03-13-30Z"
    "rabbitmq:3.13.7-management"
    "postgres:15"
)

# ============================================================
# Helpers
# ============================================================

check_docker() {
    docker info >/dev/null
}

pull_if_missing() {
    local img="$1"
    if docker image inspect "$img" >/dev/null 2>&1; then
        echo "Already present: $img"
    else
        echo "Pulling: $img"
        docker pull "$img"
    fi
}

# ============================================================
# Download
# ============================================================

check_docker

echo "Downloading MRVA images (version $VERSION) from $REGISTRY"
echo

for img in "${MRVA_IMAGES[@]}"; do
    pull_if_missing "$img"
done

echo
echo "Ensuring infrastructure images are present"
echo

for img in "${INFRA_IMAGES[@]}"; do
    pull_if_missing "$img"
done

echo
echo "All images ready."
