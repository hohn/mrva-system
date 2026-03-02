#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# MRVA Container Image Download Script
# ============================================================


# ============================================================
# Image Definitions
# ============================================================

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

echo
echo "Ensuring infrastructure images are present"
echo

for img in "${INFRA_IMAGES[@]}"; do
    pull_if_missing "$img"
done

echo
echo "All images ready."
