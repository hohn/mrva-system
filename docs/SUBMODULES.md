# MRVA System Submodules

This document describes the Git submodule configuration for the MRVA system.

## Submodule Overview

| Submodule | Repository | Branch | Purpose |
|-----------|------------|--------|---------|
| `gh-mrva` | `hohn/gh-mrva` | `master` | CLI client for MRVA |
| `mrvaagent` | `hohn/mrvaagent` | `master` | CodeQL analysis worker agent |
| `mrvacommander` | `hohn/mrvacommander` | `master` | Shared packages (server, agent, state) |
| `mrvaserver` | `hohn/mrvaserver` | `master` | MRVA HTTP API server |
| `mrva-go-hepc` | `data-douser/mrva-go-hepc` | `main` | HTTP Endpoint for CodeQL databases (Go) |
| `mrva-docker` | `data-douser/mrva-docker` | `data-douser/codeql-mrva-chart/1` | Docker/Kubernetes deployment configs |

## Branch Tracking

### Active Development Branches

- **mrva-docker**: Uses branch `data-douser/codeql-mrva-chart/1` which contains the Helm chart improvements
- **mrva-go-hepc**: Uses `main` branch (Go replacement for Python `mrvahepc`)

### Upstream Branches

The following submodules track their upstream `master` branches:

- `gh-mrva`
- `mrvaagent`
- `mrvacommander`
- `mrvaserver`

## Update Procedures

### Update All Submodules

```bash
cd mrva-system
git submodule update --init --recursive
```

### Update a Specific Submodule

```bash
cd submodules/<submodule-name>
git fetch origin
git checkout <target-branch>
cd ../..
git add submodules/<submodule-name>
git commit -m "Update <submodule-name> to latest"
```

### Switch Submodule to Different Fork

1. Update `.gitmodules` with new URL
2. Sync the submodule configuration:
   ```bash
   git submodule sync
   ```
3. Update the submodule:
   ```bash
   git submodule update --init --remote submodules/<name>
   ```

## Submodule Dependencies

```
mrva-system
├── gh-mrva (CLI client)
│   └── depends on: mrvaserver API
├── mrvaserver
│   └── depends on: mrvacommander/pkg/*
├── mrvaagent
│   └── depends on: mrvacommander/pkg/*
├── mrvacommander (shared library)
│   └── depends on: mrva-go-hepc (via HTTP)
├── mrva-go-hepc (HEPC service)
│   └── standalone
└── mrva-docker (deployment)
    └── references all containers
```

## Conflict Resolution

### Submodule Pointer Conflicts

When merging branches with different submodule commits:

1. Decide which commit should be used
2. Checkout the desired commit in the submodule:
   ```bash
   cd submodules/<name>
   git checkout <desired-commit>
   ```
3. Stage and commit in parent:
   ```bash
   cd ../..
   git add submodules/<name>
   git commit -m "Resolve submodule conflict for <name>"
   ```

### .gitmodules Conflicts

Edit `.gitmodules` manually to resolve URL or branch conflicts, then:

```bash
git submodule sync
git submodule update --init
```

## Notes

- The `mrvahepc` submodule has been replaced by `mrva-go-hepc` (Go implementation)
- The old Python `mrvahepc` is archived but still referenced by `hohn/mrva-system`
- The `mrva-docker` fork includes Helm chart (`k8s/codeql-mrva-chart/`) for Kubernetes deployment
