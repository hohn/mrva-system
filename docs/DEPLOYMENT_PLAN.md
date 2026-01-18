# MRVA System Deployment Plan

## Overview

This document outlines the plan to integrate `data-douser` repositories into an improved `mrva-system`, replacing the Python-based `hohn/mrvahepc` placeholder with the Go-based `data-douser/mrva-go-hepc` implementation and deploying the system using the `codeql-mrva-chart` Helm chart.

---

## Phase 1: Repository Integration ✅

### 1.1 Update mrva-system Submodules

- [x] Create and switch to `data-douser/integrate-forks` branch in `data-douser/mrva-system`
- [x] Update `.gitmodules` to reference data-douser forks:

| Submodule | Current URL | Target URL |
|-----------|-------------|------------|
| `mrva-docker` | `git@github.com:hohn/mrva-docker.git` | `git@github.com:data-douser/mrva-docker.git` |
| `mrvahepc` | `git@github.com:hohn/mrvahepc.git` | `git@github.com:data-douser/mrva-go-hepc.git` |

- [x] Update submodule paths if renaming `mrvahepc` → `mrva-go-hepc`
- [ ] Run `git submodule sync && git submodule update --init --recursive` *(manual step)*
- [ ] Verify submodule branches *(manual step)*:
  - `mrva-docker`: `data-douser/codeql-mrva-chart/1`
  - `mrva-go-hepc`: `main`

### 1.2 Document Submodule Configuration

- [x] Create `docs/SUBMODULES.md` documenting:
  - Branch tracking requirements per submodule
  - Update procedures
  - Conflict resolution guidelines

---

## Phase 2: Interface Alignment — mrva-go-hepc ✅

### 2.1 HTTP API Compatibility

The `hohn/mrvahepc` Python implementation exposes:

| Endpoint | Purpose | Status |
|----------|---------|--------|
| `GET /index` | Serve metadata as JSONL | ✅ Implemented |
| `GET /api/v1/latest_results/codeql-all` | Serve metadata as JSONL | ✅ Implemented |
| `GET /db/{filepath...}` | Serve database files | ✅ Implemented |
| `GET /health` | Health check | ✅ Implemented |

**Action Items:**

- [x] Verify JSONL output format matches `HepcResult` schema in `mrvacommander/pkg/qldbstore/qldbstore_hepc.go`
- [x] Add test case validating response schema compatibility

### 2.2 Metadata Schema Alignment

The `mrvacommander` `HepcStore` expects this JSON schema (from `HepcResult`):

```json
{
  "git_branch": "string",
  "git_commit_id": "string",
  "git_repo": "string",
  "ingestion_datetime_utc": "string",
  "result_url": "string",
  "tool_id": "string",
  "tool_name": "string",
  "tool_version": "string",
  "projname": "string"
}
```

Current `mrva-go-hepc` `DatabaseMetadata` schema (from `api/types.go`):

```json
{
  "content_hash": "string",
  "build_cid": "string",
  "git_branch": "string",
  "git_commit_id": "string",
  "git_owner": "string",
  "git_repo": "string",
  "ingestion_datetime_utc": "string",
  "primary_language": "string",
  "result_url": "string",
  "tool_name": "string",
  "tool_version": "string",
  "projname": "string",
  "db_file_size": "int64"
}
```

**Schema Gap Analysis:**

| Field | HepcResult | DatabaseMetadata | Action Required |
|-------|------------|------------------|-----------------|
| `tool_id` | ✅ | ❌ Missing | Add field or map from existing |
| `git_owner` | ❌ | ✅ | Keep (superset is OK) |
| `primary_language` | ❌ | ✅ | Keep (superset is OK) |
| `content_hash` | ❌ | ✅ | Keep (superset is OK) |
| `build_cid` | ❌ | ✅ | Keep (superset is OK) |
| `db_file_size` | ❌ | ✅ | Keep (superset is OK) |

**Action Items:**

- [x] Add `tool_id` field to `DatabaseMetadata` struct (or derive from existing fields)
- [x] Update metadata discovery to populate `tool_id`
- [x] Add integration test validating `HepcStore.fetchViaHTTP()` can parse responses
- [ ] Document schema in `api/README.md` *(optional enhancement)*

### 2.3 Environment Variable Support

The `mrvacommander` `InitHEPCDatabaseStore()` requires:

| Variable | Purpose | Required |
|----------|---------|----------|
| `MRVA_HEPC_ENDPOINT` | Base URL (e.g., `http://hepc:8070`) | ✅ |
| `MRVA_HEPC_CACHE_DURATION` | Metadata cache TTL (minutes) | ✅ |
| `MRVA_HEPC_DATAVIACLI` | Use CLI instead of HTTP | ⚠️ Legacy |
| `MRVA_HEPC_OUTDIR` | Output dir for CLI mode | ⚠️ Legacy |
| `MRVA_HEPC_TOOL` | Tool name for CLI mode | ⚠️ Legacy |

**Action Items:**

- [x] Verify `mrva-go-hepc` works with only HTTP-mode variables
- [x] Document that CLI-mode variables (`MRVA_HEPC_DATAVIACLI`, etc.) are not supported
- [x] Update `codeql-mrva-chart` ConfigMap if needed

### 2.4 Unit Test Updates

- [x] Add test: `TestAPISchemaCompatibility` — validate JSON output matches `HepcResult`
- [x] Add test: `TestMetadataEndpointParsing` — simulate `HepcStore.fetchViaHTTP()` parsing
- [x] Add test: `TestHealthEndpoint` — ensure `/health` returns expected format
- [ ] Ensure test coverage ≥ 80% *(verify with `go test -cover`)*

---

## Phase 3: Docker Image Creation ✅

### 3.1 Create Dockerfile for mrva-go-hepc

- [x] Create `data-douser/mrva-go-hepc/Dockerfile`:

```dockerfile
# Multi-stage build for mrva-go-hepc
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /hepc-server ./cmd/hepc-server

FROM alpine:3.19
RUN apk --no-cache add ca-certificates
COPY --from=builder /hepc-server /usr/local/bin/hepc-server
EXPOSE 8070
ENTRYPOINT ["hepc-server"]
CMD ["--storage", "local", "--host", "0.0.0.0", "--port", "8070"]
```

- [x] Create `.dockerignore`
- [x] Add `make docker-build` target to Makefile
- [x] Add `make docker-push` target for GHCR publishing

### 3.2 Update Helm Chart for Go-based HEPC

The current `codeql-mrva-chart` HEPC deployment uses:

```yaml
hepc:
  image:
    repository: mrva-hepc-container
  command:
    - "hepc-serve-global"
    - "--host"
    - "0.0.0.0"
    - "--port"
    - "8070"
```

**Action Items:**

- [ ] Update `values.yaml` HEPC section for Go binary:

```yaml
hepc:
  image:
    repository: ghcr.io/data-douser/mrva-go-hepc
    tag: "latest"
  command:
    - "hepc-server"
    - "--storage"
    - "gcs"  # or "local" depending on deployment
    - "--host"
    - "0.0.0.0"
    - "--port"
    - "8070"
```

- [x] Add GCS configuration options to values.yaml
- [x] Update hepc-deployment.yaml for volume mounts (if using local storage)
- [x] Add environment variable support for GCS credentials

---

## Phase 4: GitHub Actions Workflow ✅

### 4.1 Create CI/CD Pipeline

- [x] Create `.github/workflows/docker-publish.yml` in `mrva-go-hepc`:

```yaml
name: Build and Publish Docker Images
on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build and push hepc-server
        uses: docker/build-push-action@v5
        with:
          push: ${{ github.event_name != 'pull_request' }}
          tags: ghcr.io/data-douser/mrva-go-hepc:${{ github.sha }}
```

- [x] Configure GHCR authentication secrets *(uses `GITHUB_TOKEN`)*
- [x] Add image scanning (Trivy)
- [x] Add Go test step before build

### 4.2 Create Workflow for All Custom Images

Images required by `codeql-mrva-chart`:

| Service | Image | Source |
| ------- | ----- | ------ |
| server | `mrva-server` | `mrva-docker/containers/server` |
| agent | `mrva-agent` | `mrva-docker/containers/agent` |
| hepc | `mrva-go-hepc` | `mrva-go-hepc` |
| ghmrva | `mrva-gh-mrva` | `mrva-docker/containers/ghmrva` |
| codeServer | `code-server-initialized` | `mrva-docker/containers/vscode` |

- [x] Create `.github/workflows/build-images.yml` in `mrva-docker`
- [x] Use matrix strategy for parallel builds
- [ ] Trigger on submodule updates *(manual step: configure webhook)*

---

## Phase 5: Kubernetes Deployment ✅

### 5.1 Prerequisites

- [ ] Access to production Kubernetes cluster *(manual)*
- [ ] `kubectl` configured with cluster credentials *(manual)*
- [x] Helm 3.x installed
- [ ] GHCR image pull secrets created in namespace *(manual)*

### 5.2 Namespace and Secrets Setup

```bash
# Create namespace
kubectl create namespace mrva

# Create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USER \
  --docker-password=$GITHUB_TOKEN \
  --namespace=mrva

# Create application secrets
kubectl apply -f k8s/secrets.yaml --namespace=mrva
```

- [x] Document secret requirements
- [x] Create production secrets template (without values)

### 5.3 Helm Chart Deployment

```bash
# Add image pull secrets to values
helm install mrva ./k8s/codeql-mrva-chart \
  --namespace mrva \
  --set global.imagePullSecrets[0].name=ghcr-secret \
  --set hepc.image.repository=ghcr.io/data-douser/mrva-go-hepc \
  --set hepc.image.tag=v1.0.0 \
  --values production-values.yaml
```

- [x] Create `production-values.yaml` override file
- [ ] Configure ingress/HTTPRoute for external access *(manual)*
- [x] Set resource limits for production
- [x] Enable persistence for PostgreSQL, MinIO, RabbitMQ

### 5.4 Validation Checklist

- [ ] All pods running: `kubectl get pods -n mrva` *(manual)*
- [ ] Services accessible: `kubectl get svc -n mrva` *(manual)*
- [ ] HEPC health check: `curl http://hepc:8070/health` *(manual)*
- [ ] HEPC metadata: `curl http://hepc:8070/index | head -1` *(manual)*
- [ ] Server health: `curl http://server:8080/health` *(manual)*
- [ ] RabbitMQ management UI accessible *(manual)*
- [ ] MinIO console accessible *(manual)*
- [ ] End-to-end MRVA job submission test *(manual)*
## Phase 6: Testing & Validation

### 6.1 Local Testing (Minikube)

- [ ] Start Minikube: `minikube start --memory=8192 --cpus=4`
- [ ] Build local images: `eval $(minikube docker-env) && make docker-build`
- [ ] Deploy chart: `helm install mrva-test ./k8s/codeql-mrva-chart --set global.imagePullPolicy=Never`
- [ ] Run smoke tests

### 6.2 Integration Testing

- [ ] Submit MRVA job via gh-mrva client
- [ ] Verify job flows through: server → RabbitMQ → agent
- [ ] Verify agent fetches databases from HEPC
- [ ] Verify results stored in MinIO
- [ ] Verify status updates in PostgreSQL

### 6.3 Performance Testing

- [ ] Load test HEPC with 100+ concurrent requests
- [ ] Measure database download throughput
- [ ] Profile memory usage under load

---

## Appendices

### A. File Mapping Reference

| Component | Original (hohn/) | Fork (data-douser/) |
|-----------|------------------|---------------------|
| HEPC | `mrvahepc/` (Python) | `mrva-go-hepc/` (Go) |
| Helm Chart | N/A | `mrva-docker/k8s/codeql-mrva-chart/` |
| Docker Configs | `mrva-docker/containers/` | `mrva-docker/containers/` |

### B. Environment Variables Reference

| Variable | Component | Description |
|----------|-----------|-------------|
| `MRVA_HEPC_ENDPOINT` | agent, server | HEPC service URL |
| `MRVA_HEPC_CACHE_DURATION` | agent, server | Metadata cache TTL |
| `POSTGRES_HOST` | server, agent | PostgreSQL hostname |
| `RABBITMQ_HOST` | server, agent | RabbitMQ hostname |
| `MINIO_ENDPOINT` | server, agent | MinIO S3 endpoint |

### C. Port Reference

| Service | Port | Protocol |
|---------|------|----------|
| HEPC | 8070 | HTTP |
| Server | 8080 | HTTP |
| Agent | 8071 | HTTP |
| PostgreSQL | 5432 | TCP |
| RabbitMQ | 5672 | AMQP |
| RabbitMQ Mgmt | 15672 | HTTP |
| MinIO API | 9000 | HTTP |
| MinIO Console | 9001 | HTTP |

---

## Revision History

| Version | Date | Author | Changes |
| ------- | ---- | ------ | ------- |
| 0.1.0 | 2026-01-18 | data-douser | Initial deployment plan |
| 0.2.0 | 2026-01-18 | data-douser | Phases 1-5 implemented |
