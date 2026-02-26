#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# MRVA gh-mrva Client Runner
# ============================================================

usage() {
cat <<EOF
run-ghmrva.sh

Usage:
  run-ghmrva.sh --source=local|ghcr [options]

Required:
  --source=local|ghcr     Select image source.

Options:
  --version=X.Y.Z        Override MRVA version (default: 0.4.8)
  --rm                   Remove container after exit (default: on)
  -h, --help             Show this help and exit.

Behavior:
  - Requires mrva-server container to be running.
  - Attaches to backend docker network.
  - SERVER_URL is set to http://mrva-server:8080
EOF
}

SOURCE=""
VERSION="0.4.8"
REMOVE=1

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        --source=local) SOURCE="local" ;;
        --source=ghcr) SOURCE="ghcr" ;;
        --version=*) VERSION="${arg#*=}" ;;
        --rm) REMOVE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $arg"; usage; exit 1 ;;
    esac
done

if [ -z "$SOURCE" ]; then
    echo "Must specify --source=local or --source=ghcr"
    exit 1
fi

# ============================================================
# Preconditions
# ============================================================

if ! docker ps --format '{{.Names}}' | grep -q '^mrva-server$'; then
    echo "mrva-server is not running."
    echo "Start it with: ./scripts/start-containers.sh --source=$SOURCE"
    exit 1
fi

if ! docker network inspect backend >/dev/null 2>&1; then
    echo "Docker network 'backend' does not exist."
    exit 1
fi

# ============================================================
# Image Selection
# ============================================================

if [ "$SOURCE" = "local" ]; then
    IMAGE="mrva-gh-mrva:$VERSION"
else
    IMAGE="ghcr.io/hohn/mrva-gh-mrva:$VERSION"
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Missing image: $IMAGE"
    if [ "$SOURCE" = "ghcr" ]; then
        echo "Run download-containers.sh first."
    else
        echo "Run build first."
    fi
    exit 1
fi



# ============================================================
# Run Client
# ============================================================

RM_FLAG=""
if [ "$REMOVE" -eq 1 ]; then
    RM_FLAG="--rm"
fi

echo "Running gh-mrva client using image: $IMAGE"
echo "Connecting to server at http://mrva-server:8080"
echo

docker run -d $RM_FLAG \
    --name mrva-ghmrva \
    --network backend \
    -e SERVER_URL="http://mrva-server:8080" \
    -e MRVA_SERVER_URL="http://mrva-server:8080" \
    "$IMAGE"

echo "Container mrva-ghmrva started in background."
echo "To follow logs: docker logs -f mrva-ghmrva"
