#!/bin/sh
set -u

### helpers ############################################################

say()   { printf '%s\n' "$*"; }
kv()    { printf '%-24s = %s\n' "$1" "$2"; }
warn()  { printf '!! %-21s = %s\n' "$1" "$2"; }

exists() {
    [ -e "$1" ] && echo yes || echo no
}

### locate system ######################################################

MRVA_SYSTEM_ROOT=${MRVA_SYSTEM_ROOT:-$(pwd)}
COMPOSE_FILE=${COMPOSE_FILE:-submodules/mrva-docker/docker-compose-demo.yml}

say "MRVA STATE SNAPSHOT"
say "=================="
kv "system_root" "$MRVA_SYSTEM_ROOT"
kv "compose_file" "$COMPOSE_FILE"
say

if [ ! -f "$COMPOSE_FILE" ]; then
    warn "compose_file" "NOT FOUND"
    exit 1
fi

### compose-derived state ##############################################

say "COMPOSE (resolved)"
say "------------------"

COMPOSE_CONFIG=$(docker-compose -f "$COMPOSE_FILE" config 2>/dev/null || true)

if [ -z "$COMPOSE_CONFIG" ]; then
    warn "compose_config" "FAILED TO RESOLVE"
else
    kv "compose_config" "ok"
fi
say

### extract volumes ####################################################
say "VOLUMES (service : host → container)"
say "----------------------------------"

echo "$COMPOSE_CONFIG" |
awk '
# Track indentation levels
function indent(line) {
    match(line, /^[ ]*/)
    return RLENGTH
}

# Enter services block
/^services:$/ {
    in_services=1
    services_indent=indent($0)
    next
}

# Leave services block on new top-level key
in_services && /^[a-zA-Z0-9_-]+:$/ && $1 != "services:" {
    in_services=0
}

# Capture service name (child of services)
in_services && /^[ ]*[a-zA-Z0-9_-]+:$/ && indent($0) > services_indent {
    service=$1
    sub(":", "", service)
    service_indent=indent($0)
    next
}

# Capture volume entries belonging to current service
in_services && /^[ ]*- / && service != "" {
    if ($2 ~ /:/) {
        split($2,a,":")
        host=a[1]
        container=a[2]
        printf "%s %s %s\n", service, host, container
    }
}
' |
while read service host_path container_path; do
    kv "service" "$service"
    kv "host_path" "$host_path"
    kv "container_path" "$container_path"
    kv "exists_on_host" "$(exists "$host_path")"
    say
done


### known MRVA paths ###################################################

say "KNOWN MRVA STATE"
say "----------------"

# These are semantic, not mandatory
GH_MRVA_DIR="$MRVA_SYSTEM_ROOT/gh-mrva"
HEPC_DIR="$MRVA_SYSTEM_ROOT/mrvahepc"
METADATA_DB="$HEPC_DIR/db-collection-host.tmp/metadata.sql"
SELECTION_JSON="$GH_MRVA_DIR/gh-mrva-selection.json"

kv "GH_MRVA_DIR" "$GH_MRVA_DIR"
kv "exists" "$(exists "$GH_MRVA_DIR")"
say

kv "HEPC_DIR" "$HEPC_DIR"
kv "exists" "$(exists "$HEPC_DIR")"
say

kv "METADATA_DB" "$METADATA_DB"
kv "exists" "$(exists "$METADATA_DB")"
say

kv "SELECTION_JSON" "$SELECTION_JSON"
kv "exists" "$(exists "$SELECTION_JSON")"
say

### invariants #########################################################

say "INVARIANTS"
say "----------"

[ -d "$GH_MRVA_DIR" ] \
    || warn "GH_MRVA_DIR" "missing"

[ -d "$HEPC_DIR" ] \
    || warn "HEPC_DIR" "missing"

[ -f "$METADATA_DB" ] \
    || warn "metadata.sql" "missing"

[ -f "$SELECTION_JSON" ] \
    || warn "selection.json" "missing"

say
say "END STATE"
