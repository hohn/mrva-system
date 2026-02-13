#!/usr/bin/env bash
set -euo pipefail

containers=$(docker ps --format '{{.Names}}' | grep '^mrva-' || true)

if [ -z "$containers" ]; then
    echo "No MRVA containers running."
    exit 1
fi

pids=()

for c in $containers; do
    (
        docker logs -f --tail=50 "$c" 2>&1 |
        sed -u "s/^/[$c] /"
    ) &
    pids+=($!)
done

trap "kill ${pids[*]} 2>/dev/null" EXIT INT TERM

wait
