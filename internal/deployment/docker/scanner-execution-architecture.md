# Scanner Execution Architecture - Kubernetes Jobs

**Last Updated:** February 2026
**Service:** tool-integration v0.4.0
**Status:** Production — 15 scanners implemented

## Overview

The tool-integration service executes security scanners as isolated Kubernetes Jobs. Each scan triggers a short-lived K8s Job that runs a scanner Docker image, analyzes the contract, and POSTs results back via HTTP callback. This architecture provides production-grade isolation, scalability, and security without requiring Docker-in-Docker or privileged containers.

For the complete operational pipeline (trigger, execution, result collection, forwarding), see [Scanner Job Execution Pipeline](../../../pipelines/scanner-job-execution-pipeline.md).

## Architecture Decision

**Decision**: Use Kubernetes Jobs for scanner execution
**Date**: October 2025
**Status**: Implemented (15 scanners, 6 verified end-to-end February 2026)

### Why Kubernetes Jobs?

1. **Security** — No Docker socket mounting. Each scan runs in an isolated pod with its own namespace, non-root user (UID 1000), seccomp profile, and dropped capabilities.
2. **Dependency isolation** — Each scanner has conflicting dependencies (e.g., Slither requires `web3>=7.10` with `ckzg>=2.0.0` while other tools may conflict). Separate images eliminate dependency hell.
3. **Resource management** — Per-scanner memory limits (512Mi–2Gi), CPU quotas, and `activeDeadlineSeconds` prevent runaway scanners from consuming cluster resources.
4. **Scalability** — K8s scheduler distributes Jobs across nodes. Hundreds of concurrent scans can run simultaneously.
5. **Cleanup** — `ttlSecondsAfterFinished: 3600` auto-deletes completed Jobs. `ResultCollector` background task handles orphaned ConfigMaps.

### Why NOT Alternatives?

| Alternative | Issue |
|-------------|-------|
| Docker-in-Docker | Requires privileged containers (security anti-pattern) |
| Sidecar containers | All scanners always running (wastes resources) |
| Embedded Python packages | Dependency conflicts between scanners |
| Shared PVC for results | Race conditions, 1MB ConfigMap limit for small results |

## Current Scanner Inventory

### Solidity Static Analysis (6)

| Scanner | Tool Version | Image Tag | Memory Limit | Developer |
|---------|-------------|-----------|--------------|-----------|
| slither | 0.11.5 | scanner-slither:0.3.8 | 1Gi | Trail of Bits |
| aderyn | 0.6.7 | scanner-aderyn:0.7.2 | 512Mi | Cyfrin |
| semgrep | 1.144.0 | scanner-semgrep:0.3.5 | 1Gi | Semgrep Inc |
| solhint | 6.0.2 | scanner-solhint:0.1.6 | 512Mi | Protofire |
| wake | 4.22.0 | scanner-wake:0.3.6 | 1Gi | Ackee Blockchain |
| soliditydefend | 2.0.1 | scanner-soliditydefend:0.8.0 | 1Gi | Apogee |

### Solidity Fuzzing & Symbolic (3)

| Scanner | Tool Version | Image Tag | Memory Limit | Developer |
|---------|-------------|-----------|--------------|-----------|
| echidna | 2.2.7 | scanner-echidna:0.3.1 | 1Gi | Trail of Bits |
| medusa | 1.5.0 | scanner-medusa:0.3.1 | 2Gi | Trail of Bits |
| halmos | 0.3.3 | scanner-halmos:0.3.0 | 2Gi | a16z |

### Vyper (2)

| Scanner | Tool Version | Image Tag | Memory Limit | Developer |
|---------|-------------|-----------|--------------|-----------|
| vyper | 0.4.3 | scanner-vyper:0.3.0 | 1Gi | Vyper Team |
| moccasin | 0.4.3 | scanner-moccasin:0.3.0 | 1Gi | Cyfrin |

### Solana/Rust (4)

| Scanner | Tool Version | Image Tag | Memory Limit | Developer |
|---------|-------------|-----------|--------------|-----------|
| sol-azy | 0.4.0 | scanner-sol-azy:0.4.0 | 1Gi | FuzzingLabs |
| sec3-xray | 0.3.0 | scanner-sec3-xray:0.3.1 | 2Gi | Sec3 |
| trident | 0.12.0 | scanner-trident:0.3.0 | 1Gi | Ackee Blockchain |
| cargo-fuzz-solana | 0.13.1 | scanner-cargo-fuzz-solana:0.3.0 | 1Gi | rust-fuzz |

## Execution Flow

```
User clicks "Scan" in Dashboard
         |
         v
API Service creates scan record (status: queued)
         |
         v
Orchestration dispatches to Tool-Integration
         |
         v
Tool-Integration: POST /scans/{scan_id}/trigger?scanner=slither
    1. Validate scanner name (15 supported)
    2. Create ConfigMap with contract source (scan-{scan_id}-source)
    3. Create K8s Job (scan-{scanner}-{scan_id})
       - Image from scanner-versions ConfigMap
       - ConfigMap mounted read-only at /contracts
       - CALLBACK_URL set to tool-integration endpoint
       - Security: UID 1000, seccomp, no capabilities
       - DNS: single-request-reopen (Alpine musl fix)
    4. Return job_name to caller
         |
         v
K8s Scheduler pulls image from Harbor, runs scanner
    - Entrypoint: run-{scanner}.sh
    - Reads contracts from /contracts
    - Runs scanner analysis
    - POSTs JSON results to CALLBACK_URL
         |
         v
Tool-Integration: POST /api/v1/scans/{scan_id}/results
    1. Identify scanner from payload
    2. Route to scanner-specific parser
    3. Normalize to common vulnerability schema
    4. Forward to API service
    5. On failure: store in dead-letter queue
         |
         v
ResultCollector (every 60s):
    - List completed/failed Jobs
    - Clean up ConfigMaps and Jobs
    - Forward failure status for failed Jobs
```

## Scanner Image Architecture

Each scanner runs as a custom Docker image stored in Harbor (`harbor.blocksecops.local/blocksecops/`):

```
scanner-images/
  slither/
    Dockerfile          # Multi-stage: foundry + python + slither + solc versions
    run-slither.sh      # Entrypoint: set solc, find .sol files, run slither, POST results
  aderyn/
    Dockerfile          # Debian + foundry + node + aderyn binary
    run-aderyn.sh
  semgrep/
    Dockerfile          # Python + semgrep + bundled rules (offline operation)
    run-semgrep.sh
  ... (15 scanner directories total)
```

### Common Image Patterns

- Non-root user `scanner` (UID 1000, GID 1000)
- Entrypoint script handles: env validation, tool setup, execution, JSON output, HTTP callback
- Foundry (forge) included in Solidity images for project compilation
- Node.js 20 included for Hardhat project support
- curl with retry flags (`--retry 3 --retry-all-errors --connect-timeout 10`) for callback delivery

### Pod Security

```yaml
# Pod security context
run_as_non_root: true
run_as_user: 1000
run_as_group: 1000
fs_group: 1000
seccomp_profile: RuntimeDefault

# Container security context
allow_privilege_escalation: false
capabilities:
  drop: ["ALL"]
```

### Job Configuration

```yaml
ttl_seconds_after_finished: 3600   # Auto-delete 1 hour after completion
backoff_limit: 3                    # Retry up to 3 times
restart_policy: Never               # Don't restart failed containers
active_deadline_seconds: 600        # Kill after 10 minutes
```

## Result Collection — HTTP Callback

Results are collected via HTTP POST callback (not shared storage):

1. Scanner container POSTs JSON to `CALLBACK_URL` (`/api/v1/scans/{scan_id}/results`)
2. Tool-integration identifies scanner type and routes to the appropriate parser
3. Parser normalizes scanner-native format to common vulnerability schema
4. Tool-integration forwards standardized results to the API service
5. On API forward failure, results are stored in a file-backed dead-letter queue

### Parser Routing

| Scanner | Parser | Input Format | Notes |
|---------|--------|-------------|-------|
| slither | SlitherParser | `results.detectors` | High→critical, Low→medium severity mapping |
| aderyn | AderynParser | `high_issues`, `low_issues` | Per-instance line numbers |
| semgrep | Inline | `vulnerabilities` or `findings` | UPPERCASE severity normalized |
| solhint | Inline | `findings` (not `vulnerabilities`) | category=linter, confidence=0.9 |
| wake | Inline | `vulnerabilities` | `locations[0].line` for line_number |
| soliditydefend | Inline | `findings` | `fix_suggestion.description` → recommendation |
| echidna | EchidnaParser | `scanner_results.findings` | Includes `fuzzing_results` |
| medusa | MedusaParser | `scanner_results.findings` | `call_sequence` as code_snippet |
| Generic | Fallback | `vulnerabilities` or `findings` | Checks both keys |

## RBAC Configuration

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: scanner-job-manager
  namespace: tool-integration-local
rules:
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create", "get", "list", "watch", "delete"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create", "get", "list", "delete"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
```

## ConfigMap-Based Scanner Metadata

Scanner metadata and image tags are managed in the `scanner-versions` ConfigMap (single source of truth):

**Location**: `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

```yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {"version": "0.11.5", "developer": "Trail of Bits"},
      "aderyn": {"version": "0.6.7", "developer": "Cyfrin"},
      ...
    }
  SCANNER_IMAGE_SLITHER: "scanner-slither:0.3.8"
  SCANNER_IMAGE_ADERYN: "scanner-aderyn:0.7.5"
  ...
```

**Local overlay** adds Harbor registry prefix: `harbor.blocksecops.local/blocksecops/scanner-slither:0.3.8`

Both the API service (for displaying scanner info) and tool-integration (for selecting images) read from this ConfigMap.

## Observability

### Prometheus Metrics (port 9090)

| Metric | Type | Description |
|--------|------|-------------|
| `tool_integration_scan_trigger_total` | Counter | Scan trigger requests |
| `tool_integration_scan_callback_total` | Counter | Result callbacks received |
| `tool_integration_scan_callback_forward_total` | Counter | API forwards attempted |
| `tool_integration_scan_callback_duration_seconds` | Histogram | Callback processing time |
| `tool_integration_vulnerabilities_parsed_total` | Counter | Vulnerabilities parsed |
| `tool_integration_job_conflict_total` | Counter | 409 conflicts during Job creation |

### Health & Readiness

- `GET /health` — Component status (job_manager, result_collector, dead_letter_queue)
- `GET /ready` — Readiness gate (K8s probe)

### Dead-Letter Queue

Failed API forwards are stored in `/tmp/dead-letters/` for manual retry:

- `GET /api/v1/dead-letters` — List failed forwards
- `POST /api/v1/dead-letters/{id}/retry` — Retry a failed forward
- `DELETE /api/v1/dead-letters/{id}` — Discard entry

## February 2026 Fixes

| Fix | Scanner | Description |
|-----|---------|-------------|
| UID 1001→1000 | slither, aderyn, wake, soliditydefend | Dockerfiles used UID 1001 but K8s security context forced UID 1000 |
| ENV HOME=/home/scanner | slither | solc-select wrote to /.solc-select/ without HOME set |
| WORK_DIR=/contracts | solhint | Entrypoint defaulted to /work but contracts mounted at /contracts |
| DNS single-request-reopen | all (Alpine) | musl libc DNS bug sends A+AAAA on same socket causing timeouts |
| Trailing dot FQDN | all | Avoids ndots:5 search domain expansion in K8s |
| stdout JSON extraction | solhint | Debug messages polluted stdout |
| Parser branches | semgrep, solhint, wake | Added dedicated parsing in collect_scan_results() |
| Generic fallback | all | Check both "vulnerabilities" and "findings" keys |
| Curl retry + timeout | aderyn, semgrep | Added --retry 3 --retry-all-errors to callback POST |
| Offline rule bundling | semgrep | Download rules during Docker build for air-gapped operation |

## Files

| File | Role |
|------|------|
| `src/main.py` | FastAPI app: trigger, callback, health, ready, dead-letter endpoints |
| `src/scanners/kubernetes_job_manager.py` | K8s Job/ConfigMap creation, image selection, conflict handling |
| `src/scanners/parser.py` | Scanner-specific result parsers |
| `src/scanners/slither_parser.py` | Detailed Slither parser with SWC IDs |
| `src/scanners/result_collector.py` | Background Job polling, cleanup, failure forwarding |
| `src/scanners/dead_letter.py` | File-backed dead-letter queue for failed API forwards |
| `k8s/base/scanner-versions-configmap.yaml` | Scanner metadata and image tags (source of truth) |
| `scanner-images/*/Dockerfile` | Scanner Docker images (15 scanners) |
| `scanner-images/*/run-*.sh` | Scanner entrypoint scripts |

## Related Documentation

- [Scanner Job Execution Pipeline](../../../pipelines/scanner-job-execution-pipeline.md) — Full operational pipeline documentation
- [Scan Execution Pipeline](../../../pipelines/scan-execution-pipeline.md) — Orchestration-level scan flow
- [Scanner Pipeline E2E Tests](../../../feature-tests/62-scanner-pipeline-e2e.md) — End-to-end verification results
- [Docker Image Versioning](../../../standards/docker-image-versioning.md) — Image versioning standards
- [Tool Metadata ConfigMaps](../../../standards/tool-metadata-configmaps.md) — ConfigMap management
