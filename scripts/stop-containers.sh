#!/usr/bin/env bash
set -euo pipefail

usage() {
cat <<EOF
stop-containers.sh

Usage:
  stop-containers.sh [options]

Options:
  -h, --help   Show this help and exit.

Stops and removes:
  mrva-ghmrva
  mrva-agent
  mrva-server
  mrva-hepc
  mrvastore
  mrva-rabbitmq
  mrva-postgres

Does not remove volumes or network.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

CONTAINERS=(
  mrva-ghmrva
  mrva-agent
  mrva-server
  mrva-hepc
  mrvastore
  mrva-rabbitmq
  mrva-postgres
)

for c in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^$c$"; then
        echo "Stopping and removing $c"
        docker rm -f "$c"
    fi
done

echo
echo "Remaining MRVA containers:"
docker ps --filter name=mrva-
