#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# MRVA Runtime Startup Script
# ============================================================

usage() {
cat <<EOF
start-containers.sh

Usage:
  start-containers.sh --source=local|ghcr [options]

Required:
  --source=local|ghcr     Select image source.

Options:
  --recreate-volumes      Remove and recreate named volumes.
  --follow-logs           Follow server logs after startup.
  -h, --help              Show this help and exit.

Environment:
  MRVA_VALUES_PATH must be set.

Failure policy:
  - Fails if containers already exist.
  - Fails if images missing (use download-containers.sh for ghcr images).
  - Fails on readiness timeout.
EOF
}

TIMEOUT=30
POLL_INTERVAL=2

SOURCE=""
RECREATE_VOLUMES=0
FOLLOW_LOGS=0

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        --source=local) SOURCE="local" ;;
        --source=ghcr) SOURCE="ghcr" ;;
        --recreate-volumes) RECREATE_VOLUMES=1 ;;
        --follow-logs) FOLLOW_LOGS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $arg"; usage; exit 1 ;;
    esac
done

if [ -z "$SOURCE" ]; then
    echo "Must specify --source=local or --source=ghcr"
    exit 1
fi

# ============================================================
# Configuration
# ============================================================

MRVA_VERSION="0.4.8"

MRVA_MINIO_VIRTUAL_HOST="0"

MRVA_RABBITMQ_HOST="rabbitmq"
MRVA_RABBITMQ_PORT="5672"
MRVA_RABBITMQ_USER="user"
MRVA_RABBITMQ_PASSWORD="password"

MINIO_ROOT_USER="user"
MINIO_ROOT_PASSWORD="mmusty8432"

ARTIFACT_MINIO_ENDPOINT="mrvastore:9000"
ARTIFACT_MINIO_ID="$MINIO_ROOT_USER"
ARTIFACT_MINIO_SECRET="$MINIO_ROOT_PASSWORD"

QLDB_MINIO_ENDPOINT="mrvastore:9000"
QLDB_MINIO_ID="$MINIO_ROOT_USER"
QLDB_MINIO_SECRET="$MINIO_ROOT_PASSWORD"

MRVA_HEPC_ENDPOINT="http://hepc:8070"
MRVA_HEPC_CACHE_DURATION="0"

POSTGRES_USER="mrva"
POSTGRES_PASSWORD="mrvapg"
POSTGRES_DB="mrvadb"

MRVA_HEPC_DATAVIACLI="0"
MRVA_HEPC_OUTDIR="default"
MRVA_HEPC_TOOL="codeql-javascript"
MRVA_HEPC_COMMAND="spigot-cli"
MRVA_HEPC_REFROOT="/refroot/"

MRVA_VALUES_PATH="${MRVA_VALUES_PATH:-}"

if [ -z "$MRVA_VALUES_PATH" ]; then
    echo "MRVA_VALUES_PATH must be set in environment"
    exit 1
fi

# ============================================================
# Image Selection
# ============================================================

if [ "$SOURCE" = "local" ]; then
    IMG_SERVER="mrva-server:$MRVA_VERSION"
    IMG_AGENT="mrva-agent:$MRVA_VERSION"
    IMG_HEPC="mrva-hepc:$MRVA_VERSION"
else
    IMG_SERVER="ghcr.io/hohn/mrva-server:$MRVA_VERSION"
    IMG_AGENT="ghcr.io/hohn/mrva-agent:$MRVA_VERSION"
    IMG_HEPC="ghcr.io/hohn/mrva-hepc:$MRVA_VERSION"
fi

IMG_MINIO="minio/minio:RELEASE.2024-06-11T03-13-30Z"
IMG_RABBITMQ="rabbitmq:3.13.7-management"
IMG_POSTGRES="postgres:15"

# ============================================================
# Helpers
# ============================================================

check_docker() {
    docker info >/dev/null
}

check_image() {
    local img="$1"

    if docker image inspect "$img" >/dev/null 2>&1; then
        return 0
    fi

    echo "Missing image: $img"
    if [ "$SOURCE" = "ghcr" ]; then
        echo "Run download-containers.sh first."
    else
        echo "Run build first."
    fi
    exit 1
}

wait_for() {
    local name="$1"
    local cmd="$2"
    local elapsed=0
    while true; do
        if eval "$cmd" >/dev/null 2>&1; then
            break
        fi
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
        if [ "$elapsed" -ge "$TIMEOUT" ]; then
            echo "Timeout waiting for $name"
            exit 1
        fi
    done
}

ensure_not_exists() {
    if docker ps -a --format '{{.Names}}' | grep -q "^$1$"; then
        echo "Container $1 already exists."
        echo "Remove with: docker rm -f $1"
        exit 1
    fi
}

create_volume() {
    if docker volume inspect "$1" >/dev/null 2>&1; then
        if [ "$RECREATE_VOLUMES" -eq 1 ]; then
            echo "Recreating volume $1"
            docker volume rm "$1"
            docker volume create "$1"
        else
            echo "Warning: volume $1 exists"
        fi
    else
        docker volume create "$1"
    fi
}

# ============================================================
# Start
# ============================================================

check_docker

for img in "$IMG_SERVER" "$IMG_AGENT" "$IMG_HEPC" "$IMG_MINIO" "$IMG_RABBITMQ" "$IMG_POSTGRES"; do
    check_image "$img"
done

for c in mrva-postgres mrva-rabbitmq mrvastore mrva-hepc mrva-server mrva-agent; do
    ensure_not_exists "$c"
done

docker network create backend >/dev/null 2>&1 || true

create_volume pgdata
create_volume rabbitmq-data

echo "Starting postgres"
docker run -d \
    --name mrva-postgres \
    --hostname postgres \
    --network backend \
    --restart unless-stopped \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -v pgdata:/var/lib/postgresql/data \
    "$IMG_POSTGRES"

wait_for "postgres" "docker exec mrva-postgres pg_isready -U $POSTGRES_USER"

echo "Starting rabbitmq"
docker run -d \
    --name mrva-rabbitmq \
    --hostname rabbitmq \
    --network backend \
    -p 5672:5672 \
    -p 15672:15672 \
    -e RABBITMQ_DEFAULT_USER="$MRVA_RABBITMQ_USER" \
    -e RABBITMQ_DEFAULT_PASS="$MRVA_RABBITMQ_PASSWORD" \
    -v rabbitmq-data:/var/lib/rabbitmq \
    "$IMG_RABBITMQ"

wait_for "rabbitmq" "docker exec mrva-rabbitmq rabbitmq-diagnostics check_port_connectivity"

echo "Starting minio"
docker run -d \
    --name mrvastore \
    --network backend \
    -p 9000:9000 \
    -p 9001:9001 \
    -e MINIO_ROOT_USER="$MINIO_ROOT_USER" \
    -e MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
    "$IMG_MINIO" \
    server /data --console-address ":9001"

# Wait for minio readiness; the local build has mrva-platform with curl,
# otherwise just use a simple sleep since mrvastore lacks curl.
if [ "$SOURCE" = "local" ]; then
    wait_for "minio" "docker run --rm --network backend mrva-platform:$MRVA_VERSION curl -sf http://mrvastore:9000/minio/health/ready"
else
    echo "Waiting for minio to start..."
    sleep 5
fi


echo "Initializing bucket"
docker run --rm \
    --network backend \
    --entrypoint /bin/sh \
    -e MINIO_ROOT_USER="$MINIO_ROOT_USER" \
    -e MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
    minio/mc \
    -c "
      set -e;
      mc alias set local http://mrvastore:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD;
      mc mb -p local/mrvabucket || true;
    "

echo "Starting hepc"
docker run -d \
    --name mrva-hepc \
    --hostname hepc \
    --network backend \
    -p 8070:8070 \
    -v "$MRVA_VALUES_PATH":/mrva/values:ro \
    "$IMG_HEPC" \
    hepc-serve-global --host 0.0.0.0 --port 8070

echo "Starting server"
docker run -d \
    --name mrva-server \
    --network backend \
    --network-alias server \
    -p 127.0.0.1:18080:8080 \
    -e ARTIFACT_MINIO_ENDPOINT="$ARTIFACT_MINIO_ENDPOINT" \
    -e ARTIFACT_MINIO_ID="$ARTIFACT_MINIO_ID" \
    -e ARTIFACT_MINIO_SECRET="$ARTIFACT_MINIO_SECRET" \
    -e QLDB_MINIO_ENDPOINT="$QLDB_MINIO_ENDPOINT" \
    -e QLDB_MINIO_ID="$QLDB_MINIO_ID" \
    -e QLDB_MINIO_SECRET="$QLDB_MINIO_SECRET" \
    -e MRVA_MINIO_VIRTUAL_HOST="$MRVA_MINIO_VIRTUAL_HOST" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e POSTGRES_HOST="postgres" \
    -e POSTGRES_PORT="5432" \
    -e MRVA_HEPC_ENDPOINT="$MRVA_HEPC_ENDPOINT" \
    -e MRVA_HEPC_CACHE_DURATION="$MRVA_HEPC_CACHE_DURATION" \
    -e MRVA_RABBITMQ_HOST="$MRVA_RABBITMQ_HOST" \
    -e MRVA_RABBITMQ_PORT="$MRVA_RABBITMQ_PORT" \
    -e MRVA_RABBITMQ_USER="$MRVA_RABBITMQ_USER" \
    -e MRVA_RABBITMQ_PASSWORD="$MRVA_RABBITMQ_PASSWORD" \
    -e MRVA_HEPC_DATAVIACLI="$MRVA_HEPC_DATAVIACLI" \
    -e MRVA_HEPC_OUTDIR="$MRVA_HEPC_OUTDIR" \
    -e MRVA_HEPC_TOOL="$MRVA_HEPC_TOOL" \
    -e MRVA_HEPC_COMMAND="$MRVA_HEPC_COMMAND" \
    -e MRVA_HEPC_REFROOT="$MRVA_HEPC_REFROOT" \
    -e SERVER_HOST="server" \
    -e SERVER_PORT="8080" \
    "$IMG_SERVER"

echo "Starting agent"
docker run -d \
    --name mrva-agent \
    --network backend \
    -e ARTIFACT_MINIO_ENDPOINT="$ARTIFACT_MINIO_ENDPOINT" \
    -e ARTIFACT_MINIO_ID="$ARTIFACT_MINIO_ID" \
    -e ARTIFACT_MINIO_SECRET="$ARTIFACT_MINIO_SECRET" \
    -e QLDB_MINIO_ENDPOINT="$QLDB_MINIO_ENDPOINT" \
    -e QLDB_MINIO_ID="$QLDB_MINIO_ID" \
    -e QLDB_MINIO_SECRET="$QLDB_MINIO_SECRET" \
    -e MRVA_MINIO_VIRTUAL_HOST="$MRVA_MINIO_VIRTUAL_HOST" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e POSTGRES_HOST="postgres" \
    -e POSTGRES_PORT="5432" \
    -e MRVA_HEPC_ENDPOINT="$MRVA_HEPC_ENDPOINT" \
    -e MRVA_HEPC_CACHE_DURATION="$MRVA_HEPC_CACHE_DURATION" \
    -e MRVA_HEPC_DATAVIACLI="$MRVA_HEPC_DATAVIACLI" \
    -e MRVA_HEPC_OUTDIR="$MRVA_HEPC_OUTDIR" \
    -e MRVA_HEPC_TOOL="$MRVA_HEPC_TOOL" \
    -e MRVA_RABBITMQ_HOST="$MRVA_RABBITMQ_HOST" \
    -e MRVA_RABBITMQ_PORT="$MRVA_RABBITMQ_PORT" \
    -e MRVA_RABBITMQ_USER="$MRVA_RABBITMQ_USER" \
    -e MRVA_RABBITMQ_PASSWORD="$MRVA_RABBITMQ_PASSWORD" \
    "$IMG_AGENT"

echo
echo "MRVA containers running:"
docker ps --filter name=mrva-

if [ "$FOLLOW_LOGS" -eq 1 ]; then
    docker logs -f mrva-server
else
    echo
    echo "To follow logs:"
    echo "docker logs -f mrva-server"
fi
