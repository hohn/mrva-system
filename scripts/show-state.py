#!/usr/bin/env python3

import os
import subprocess
import sys
import yaml
from pathlib import Path

# ------------------------------------------------------------
# helpers
# ------------------------------------------------------------

def run(cmd):
    return subprocess.check_output(cmd, text=True)

def exists(p):
    return "yes" if p.exists() else "no"

def kv(k, v):
    print(f"{k:<24} = {v}")

def warn(k, v):
    print(f"!! {k:<21} = {v}")

# ------------------------------------------------------------
# locate system
# ------------------------------------------------------------

MRVA_SYSTEM_ROOT = Path(os.environ.get("MRVA_SYSTEM_ROOT", os.getcwd()))
COMPOSE_FILE = Path(os.environ.get(
    "COMPOSE_FILE",
    "submodules/mrva-docker/docker-compose-demo.yml"
))

print("MRVA STATIC STATE SNAPSHOT")
print("=========================")
kv("system_root", MRVA_SYSTEM_ROOT)
kv("compose_file", COMPOSE_FILE)
print()

if not COMPOSE_FILE.exists():
    warn("compose_file", "NOT FOUND")
    sys.exit(1)

# ------------------------------------------------------------
# load resolved compose config
# ------------------------------------------------------------

print("COMPOSE (resolved)")
print("------------------")

try:
    compose_yaml = run([
        "docker-compose",
        "-f", str(COMPOSE_FILE),
        "config"
    ])
    compose = yaml.safe_load(compose_yaml)
    kv("compose_config", "ok")
except Exception as e:
    warn("compose_config", f"FAILED ({e})")
    compose = {}

print()

# ------------------------------------------------------------
# volumes
# ------------------------------------------------------------

print("VOLUMES (service : host → container)")
print("----------------------------------")

services = compose.get("services", {})

for svc_name, svc in services.items():
    volumes = svc.get("volumes", [])
    for v in volumes:
        # volume entries may be "host:container[:mode]"
        if isinstance(v, str) and ":" in v:
            parts = v.split(":")
            host = parts[0]
            container = parts[1]

            host_path = Path(host)
            is_bind = host.startswith("/") or host.startswith("~")

            kv("service", svc_name)
            kv("host_path", host)
            kv("container_path", container)
            kv(
                "exists_on_host",
                exists(host_path.expanduser()) if is_bind else "n/a (named volume)"
            )
            print()

# ------------------------------------------------------------
# known MRVA state
# ------------------------------------------------------------

print("KNOWN MRVA STATE")
print("----------------")

SUBMODULES_DIR = MRVA_SYSTEM_ROOT / "submodules"
GH_MRVA_DIR = SUBMODULES_DIR / "gh-mrva"
HEPC_DIR = SUBMODULES_DIR / "mrvahepc"

METADATA_DB = HEPC_DIR / "db-collection.global" / "metadata.sql"
SELECTION_JSON = GH_MRVA_DIR / "gh-mrva-selection.json"

kv("GH_MRVA_DIR", GH_MRVA_DIR)
kv("exists", exists(GH_MRVA_DIR))
print()

kv("HEPC_DIR", HEPC_DIR)
kv("exists", exists(HEPC_DIR))
print()

kv("METADATA_DB", METADATA_DB)
kv("exists", exists(METADATA_DB))
print()

kv("SELECTION_JSON", SELECTION_JSON)
kv("exists", exists(SELECTION_JSON))
print()

# ------------------------------------------------------------
# invariants
# ------------------------------------------------------------

print("INVARIANTS")
print("----------")

if not GH_MRVA_DIR.exists():
    warn("GH_MRVA_DIR", "missing")

if not HEPC_DIR.exists():
    warn("HEPC_DIR", "missing")

if not METADATA_DB.exists():
    warn("metadata.sql", "missing")

if not SELECTION_JSON.exists():
    warn("selection.json", "missing")

print()
print("END STATE")

print()
print("MRVA RUN-TIME SNAPSHOT")
print("=====================")
print()

# ------------------------------------------------------------
# runtime containers
# ------------------------------------------------------------

print("RUNNING CONTAINERS")
print("------------------")

try:
    ps = run([
        "docker", "ps",
        "--format",
        "{{.Names}}\t{{.Image}}\t{{.Status}}"
    ])
except Exception as e:
    warn("docker_ps", f"FAILED ({e})")
    ps = ""

found = False
for line in ps.splitlines():
    try:
        name, image, status = line.split("\t", 2)
    except ValueError:
        continue

    # MRVA naming conventions
    if name.startswith("mrva-") or name in ("mrvastore",):
        found = True
        kv("container", name)
        kv("image", image)
        kv("status", status)
        print()

if not found:
    kv("containers", "none running")

print()

# ------------------------------------------------------------
# images (present)
# ------------------------------------------------------------

print("IMAGES (present)")
print("----------------")

try:
    images = run([
        "docker", "image", "ls",
        "--format",
        "{{.Repository}}\t{{.Tag}}\t{{.ID}}"
    ])
except Exception as e:
    warn("docker_images", f"FAILED ({e})")
    images = ""

found = False
for line in images.splitlines():
    try:
        repo, tag, image_id = line.split("\t", 2)
    except ValueError:
        continue

    if repo.startswith("mrva-"):
        found = True
        kv("image", f"{repo}:{tag}")
        kv("id", image_id)
        print()

if not found:
    kv("images", "no MRVA images present")

print()
