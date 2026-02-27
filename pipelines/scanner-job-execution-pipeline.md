# Scanner Job Execution Pipeline

Executes security scanners as isolated Kubernetes Jobs, collects results via HTTP callback, parses scanner-specific output, and forwards standardized vulnerabilities to the API service.

## Overview

```
Orchestration / API         Tool Integration Service            K8s Job (Scanner Container)
───────────────────         ────────────────────────            ───────────────────────────
POST /scans/{id}/trigger →  1. Validate scanner name
                            2. Create ConfigMap (contract src)
                            3. Create K8s Job
                            4. Return job_name              →  Pull scanner image
                                                               Mount ConfigMap at /contracts
                                                               Run entrypoint script
                                                               Execute scanner analysis
                                                               POST results to CALLBACK_URL

                            collect_scan_results()          ←  JSON: {scanner, vulnerabilities}
                            5. Route to scanner parser
                            6. Standardize vulnerability schema
                            7. Forward to API service       →  API stores vulnerabilities

                            [Background: ResultCollector]
                            8. Poll completed Jobs (60s)
                            9. Clean up ConfigMap + Job
```

## Service

| Property | Value |
|----------|-------|
| Repository | `blocksecops-tool-integration` |
| Version | 0.4.0 |
| Port | 8005 |
| Namespace | `tool-integration-local` |
| Language | Python 3.11 / FastAPI |

## Trigger

- **Orchestration service**: Dispatches scanner execution after scan request is queued
- **Direct API**: `POST /scans/{scan_id}/trigger?scanner=slither` with contract source in body
- **Dashboard**: Indirectly, via orchestration after user clicks "Scan"

## Pipeline Phases

### Phase 1: Trigger

| Step | Description |
|------|-------------|
| Validate scanner | Check scanner name against 15 supported scanners |
| Parse request | Extract `contract_source` (single-file) or `files` array (multi-file) |
| Detect extension | Auto-detect `.sol`, `.vy`, or `.rs` from source content |
| Create ConfigMap | Store contract source as `scan-{scan_id}-source` ConfigMap |
| Create K8s Job | Create `scan-{scanner}-{scan_id}` Job referencing ConfigMap |
| Handle conflict | If Job already exists (409), delete stale Job and recreate |
| Return | Job name and status to caller |

**Endpoint**: `POST /scans/{scan_id}/trigger`

**Request body (single-file)**:
```json
{
    "contract_source": "pragma solidity ^0.8.0;\ncontract Token { ... }",
    "compiler_version": "0.8.20"
}
```

**Request body (multi-file project)**:
```json
{
    "files": [
        {"path": "contracts/Token.sol", "content": "pragma solidity ^0.8.0; ..."},
        {"path": "contracts/Utils.sol", "content": "pragma solidity ^0.8.0; ..."}
    ],
    "main_file_path": "contracts/Token.sol",
    "compiler_version": "0.8.20"
}
```

### Phase 2: K8s Job Execution

| Step | Description |
|------|-------------|
| Schedule | K8s scheduler pulls scanner image from Harbor |
| Mount | ConfigMap mounted read-only at `/contracts` |
| Environment | `CALLBACK_URL`, `SCAN_ID`, `SOLC_VERSION`, `WORK_DIR=/contracts` |
| Security | Non-root (UID 1000), seccomp RuntimeDefault, all capabilities dropped |
| DNS | `single-request-reopen` option (fixes Alpine musl parallel A+AAAA issue) |
| Execute | Entrypoint script (`run-{scanner}.sh`) runs scanner against contract |
| Callback | Scanner container POSTs JSON results to `CALLBACK_URL` |

**Job spec highlights**:

```yaml
ttl_seconds_after_finished: 3600   # Auto-delete 1 hour after completion
backoff_limit: 3                    # Retry up to 3 times
restart_policy: Never               # Don't restart failed containers
```

**Pod security context**:
```yaml
run_as_non_root: true
run_as_user: 1000
run_as_group: 1000
fs_group: 1000
seccomp_profile: RuntimeDefault
```

**Container security context**:
```yaml
allow_privilege_escalation: false
capabilities:
  drop: ["ALL"]
```

### Phase 3: Result Collection (Callback)

| Step | Description |
|------|-------------|
| Receive | Scanner container POSTs JSON to `/api/v1/scans/{scan_id}/results` |
| Identify | Extract `scanner` field from payload to determine parser |
| Parse | Route to scanner-specific parser (SlitherParser, AderynParser, etc.) |
| Standardize | Convert scanner-native format to common vulnerability schema |
| Forward | POST standardized results to API service |
| DLQ | On forward failure, store in dead-letter queue for manual retry |

**Callback endpoint**: `POST /api/v1/scans/{scan_id}/results`

**Parser routing by scanner type**:

| Scanner | Parser | Key Input Field | Notes |
|---------|--------|-----------------|-------|
| slither | SlitherParser | `results.detectors` | Severity: High→critical, Low→medium |
| aderyn | AderynParser | `high_issues`, `low_issues` | Per-instance line numbers |
| semgrep | Inline | `vulnerabilities` or `findings` | UPPERCASE severity normalized |
| solhint | Inline | `findings` (not `vulnerabilities`) | category=linter, confidence=0.9 |
| wake | Inline | `vulnerabilities` | `locations[0].line` for line_number |
| soliditydefend | Inline | `findings` | `fix_suggestion.description` → recommendation |
| echidna | EchidnaParser | `scanner_results.findings` | Includes `fuzzing_results` |
| medusa | MedusaParser | `scanner_results.findings` | `call_sequence` as code_snippet |
| Others | Generic fallback | `vulnerabilities` or `findings` | Checks both keys |

### Phase 4: Cleanup (Background)

| Step | Description |
|------|-------------|
| Poll | ResultCollector runs every 60 seconds |
| Check Jobs | List all scanner Jobs in namespace |
| Succeeded | Delete ConfigMap and Job |
| Failed | Check if results were already received via callback |
| → Yes | Log success, clean up ConfigMap and Job |
| → No | Forward failure status to API service, then clean up |

### Phase 5: Failure Handling

| Failure Type | Handling |
|--------------|----------|
| Job fails (backoff exhausted) | ResultCollector sends error status to API with Job logs |
| API forward fails | Stored in dead-letter queue (`/tmp/dead-letters/`) |
| Job already exists (409) | Delete stale Job, wait up to 20s, recreate |
| Scanner timeout | K8s `activeDeadlineSeconds` terminates pod |

**Dead-letter queue endpoints**:
- `GET /api/v1/dead-letters` — list all failed forwards
- `POST /api/v1/dead-letters/{id}/retry` — manually retry
- `DELETE /api/v1/dead-letters/{id}` — discard entry

## Supported Scanners

### Solidity Static Analysis (6)

| Scanner | Tool Version | Image Tag | Memory Limit | Developer |
|---------|-------------|-----------|--------------|-----------|
| slither | 0.11.5 | scanner-slither:0.3.2 | 1Gi | Trail of Bits |
| aderyn | 0.6.7 | scanner-aderyn:0.7.2 | 512Mi | Cyfrin |
| semgrep | 1.144.0 | scanner-semgrep:0.3.5 | 1Gi | Semgrep Inc |
| solhint | 6.0.2 | scanner-solhint:0.1.6 | 512Mi | Protofire |
| wake | 4.22.0 | scanner-wake:0.3.6 | 1Gi | Ackee Blockchain |
| soliditydefend | 2.0.1 | scanner-soliditydefend:0.8.0 | 1Gi | BlockSecOps |

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

## Standardized Vulnerability Schema

Every scanner's output is normalized to this format before forwarding to the API service:

| Field | Type | Description |
|-------|------|-------------|
| `vulnerability_type` | string | Scanner-specific check/rule ID |
| `severity` | string | `critical`, `high`, `medium`, `low` |
| `title` | string | Short vulnerability description |
| `description` | string | Detailed explanation |
| `line_number` | int | Line in source code (0 if unknown) |
| `code_snippet` | string | Relevant code fragment |
| `recommendation` | string | Suggested fix |
| `confidence` | float | 0.0–1.0 confidence score |
| `scanner_id` | string | Scanner that found this |
| `scanner_name` | string | Human-readable scanner name |
| `category` | string | `static-analysis`, `linter`, `fuzzer`, `pattern-matching` |
| `contract_name` | string | Contract name (if available) |
| `file_path` | string | Source file path |
| `function_name` | string | Function name (if available) |

**Severity mapping (Slither example)**:

| Slither Impact | Normalized Severity |
|----------------|---------------------|
| High | critical |
| Medium | high |
| Low | medium |
| Informational | low |
| Optimization | low |

## Environment Variables

### Tool-Integration Service

| Variable | Value | Source |
|----------|-------|--------|
| `SCANNER_IMAGE_{NAME}` | `harbor.0xapogee.local/blocksecops/scanner-{name}:{version}` | scanner-versions ConfigMap |
| `IMAGE_PULL_POLICY` | `IfNotPresent` | deployment env |
| `API_SERVICE_URL` | `http://api-service.api-service-local.svc.cluster.local:8000` | configmap |

### Scanner Job Containers

| Variable | Value | Set By |
|----------|-------|--------|
| `SCAN_ID` | UUID | KubernetesJobManager |
| `CALLBACK_URL` | `http://tool-integration.tool-integration-local.svc.cluster.local.:8005/api/v1/scans/{scan_id}/results` | KubernetesJobManager |
| `SOLC_VERSION` | e.g. `0.8.20` | KubernetesJobManager |
| `CONTRACTS_DIR` | `/contracts` | KubernetesJobManager |
| `WORK_DIR` | `/contracts` | KubernetesJobManager |
| `OUTPUT_DIR` | `/output` | KubernetesJobManager |
| `TOOL_INTEGRATION_URL` | `http://tool-integration.tool-integration-local.svc.cluster.local.:8005` | KubernetesJobManager |

Note: Trailing dots on DNS names force absolute lookups (avoids ndots search delay).

## Scanner Image Architecture

Each scanner runs as a custom Docker image stored in Harbor:

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

**Common image patterns**:
- Non-root user `scanner` (UID 1000, GID 1000)
- Entrypoint script handles: env validation, tool setup, execution, JSON output, HTTP callback
- Foundry (forge) included in Solidity images for project compilation
- Node.js 20 included for Hardhat project support

## Observability

### Prometheus Metrics (port 9090)

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `tool_integration_scan_trigger_total` | Counter | scanner, status | Scan trigger requests |
| `tool_integration_scan_callback_total` | Counter | scanner, status | Result callbacks received |
| `tool_integration_scan_callback_forward_total` | Counter | status | API forwards attempted |
| `tool_integration_scan_callback_duration_seconds` | Histogram | scanner | Callback processing time |
| `tool_integration_vulnerabilities_parsed_total` | Counter | scanner, severity | Vulnerabilities parsed |
| `tool_integration_job_conflict_total` | Counter | scanner | 409 conflicts during Job creation |

### Health & Readiness

| Endpoint | Purpose | Failure Response |
|----------|---------|-----------------|
| `GET /health` | Component status (job_manager, result_collector, dead_letter_queue) | `{"status": "degraded"}` |
| `GET /ready` | Readiness gate (K8s probe) | HTTP 503 |

### Structured Logging

All log entries are JSON with fields: `timestamp`, `level`, `message`, `scan_id`, `scanner`, `job_name`.

## Files

| File | Role |
|------|------|
| `src/main.py` | FastAPI app: trigger, callback, health, ready, dead-letter endpoints |
| `src/scanners/kubernetes_job_manager.py` | K8s Job/ConfigMap creation, image selection, conflict handling |
| `src/scanners/parser.py` | Scanner-specific result parsers (Slither, Aderyn, Echidna, Medusa, etc.) |
| `src/scanners/slither_parser.py` | Detailed Slither parser with SWC IDs and category mapping |
| `src/scanners/result_collector.py` | Background Job polling, cleanup, failure forwarding |
| `src/scanners/dead_letter.py` | File-backed dead-letter queue for failed API forwards |
| `k8s/base/scanner-versions-configmap.yaml` | Scanner metadata and image tags (source of truth) |
| `k8s/overlays/local/scanner-versions-patch.yaml` | Local overlay with Harbor registry prefixes |
| `scanner-images/*/Dockerfile` | Scanner Docker images (15 scanners) |
| `scanner-images/*/run-*.sh` | Scanner entrypoint scripts |

## Configuration Sources

| What | Where | Notes |
|------|-------|-------|
| Scanner image tags | `k8s/base/scanner-versions-configmap.yaml` | Single source of truth |
| Scanner metadata (version, developer) | Same ConfigMap, `SCANNER_METADATA` JSON | Read by API service too |
| Local Harbor overrides | `k8s/overlays/local/scanner-versions-patch.yaml` | Adds `harbor.0xapogee.local/blocksecops/` prefix |
| Memory limits per scanner | `kubernetes_job_manager.py:_get_memory_limit()` | Varies by scanner type |
| Job TTL, backoff, timeouts | `kubernetes_job_manager.py:create_scanner_job()` | TTL 3600s, backoff 3, timeout 600s |
| API service URL | `result_collector.py` constructor | `http://api-service.api-service-local.svc.cluster.local:8000` |

## Related Pipelines

- [Scan Execution Pipeline](./scan-execution-pipeline.md) — orchestration-level scan flow (request → orchestration → tool-integration)
- [Intelligence Pipeline](./intelligence-pipeline.md) — processes raw findings after scan execution
- [Deduplication Pipeline](./deduplication-pipeline.md) — maintains deduplication groups post-scan
- [Scanner Upgrade Pipeline](./scanner-upgrade-pipeline.md) — process for upgrading scanner images
- [Scanner Data Audit Pipeline](./scanner-data-audit-pipeline.md) — auditing scanner output quality
