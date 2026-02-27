# Scan Execution Pipeline

Orchestrates multi-scanner execution on smart contracts, from scan request through result collection and intelligence processing.

## Overview

```
Dashboard / API            API Service          Orchestration Service       Scanners
───────────────            ───────────          ─────────────────────       ────────
POST /scans         →      Queue scan task      execute_scanners()          Scanner.execute()
                                                1. Create temp directory    (K8s Jobs)
                                                2. Build ScannerContext
                                                3. Iterate scanner_ids:
                                                   a. Check availability
                                                   b. Execute scanner
                                                   c. Collect results
                                                4. Return OrchestrationResult
                    ←      Process results →    Intelligence Pipeline →     Store findings
```

## Trigger

- **Dashboard**: User clicks "Scan" on an uploaded contract
- **API Key**: `POST /api/v1/scans` with contract_id and scanner selection
- **CLI**: `0xapogee scan` command

## Pipeline Phases

### Phase 1: Scan Request

| Step | Description |
|------|-------------|
| Authenticate | JWT or API key with `scans:write` scope |
| Validate contract | Verify contract exists and belongs to user |
| Select scanners | User-selected or default scanner set based on contract language |
| Filter scanners | Remove scanners incompatible with contract type (single-file vs project) |
| Queue task | Create scan record (status: `queued`) and dispatch to orchestration |

### Phase 2: Scanner Execution

| Step | Description |
|------|-------------|
| Create context | Build `ScannerContext` with scan_id, contract source, temp directory |
| Project setup | For multi-file: convert files to `ProjectFile` objects, detect framework |
| Scanner loop | For each scanner_id in selection: |
| → Check registry | Look up scanner in `ScannerRegistry` |
| → Check availability | Verify scanner binary/container is available |
| → Execute | Run scanner against contract source in temp directory |
| → Collect result | Capture `ScannerResult` (findings, execution_time, success/error) |
| Aggregate | Build `OrchestrationResult` with all results and failed scanners list |

### Phase 3: Result Processing

| Step | Description |
|------|-------------|
| Parse findings | Extract raw vulnerability findings from each scanner result |
| Validate snippets | Reject pragma-only snippets (`pragma solidity`) and line-1 outputs from SolidityDefend |
| Intelligence pipeline | Process through [Intelligence Pipeline](./intelligence-pipeline.md) |
| Store findings | Insert enriched vulnerabilities into database |
| Update scan | Set scan status to `completed` with summary statistics |
| Persist duration | Calculate `duration_seconds = completed_at - started_at` and store on scan record |

### Scan Duration Tracking

`duration_seconds` is calculated and persisted at every scan completion point (success, failure, stale recovery, admin force-fail) in both the API service and orchestration service. The calculation uses `int((completed_at - started_at).total_seconds())` and is only set when `started_at` is non-null.

Existing scans without `duration_seconds` can be backfilled:

```sql
UPDATE scans SET duration_seconds = EXTRACT(EPOCH FROM (completed_at - started_at))::int
WHERE started_at IS NOT NULL AND completed_at IS NOT NULL AND duration_seconds IS NULL;
```

## Scanner Context

The `ScannerContext` dataclass contains everything a scanner needs:

| Field | Type | Description |
|-------|------|-------------|
| `scan_id` | UUID | Scan identifier |
| `contract_id` | UUID | Contract identifier |
| `contract_name` | str | Contract name |
| `source_code` | str | Source code (single-file mode) |
| `temp_dir` | Path | Temporary working directory |
| `timeout` | int | Execution timeout (default: 300s) |
| `is_project` | bool | Multi-file project mode |
| `project_files` | List[ProjectFile] | Project files with paths and content |
| `framework` | str | Framework type (`foundry`, `hardhat`, `plain`) |
| `framework_config` | dict | Framework-specific configuration |
| `main_file_path` | str | Path to main contract file |

## OrchestrationResult

| Field | Type | Description |
|-------|------|-------------|
| `scan_id` | UUID | Scan identifier |
| `scanner_results` | Dict[str, ScannerResult] | Results keyed by scanner_id |
| `failed_scanners` | List[str] | Scanner IDs that failed |
| `total_execution_time` | float | Wall clock time for all scanners |

## Supported Scanners

| Scanner | Language | Type | Port |
|---------|----------|------|------|
| Slither | Solidity | Static Analysis | via K8s Job |
| Aderyn | Solidity | Static Analysis | via K8s Job |
| SolidityDefend | Solidity | Static Analysis | via K8s Job |
| Semgrep | Solidity | Pattern Matching | via K8s Job |
| Solhint | Solidity | Linter | via K8s Job |
| Halmos | Solidity | Formal Verification | via K8s Job |
| Echidna | Solidity | Fuzzer | via K8s Job |
| Medusa | Solidity | Fuzzer | via K8s Job |
| Wake | Solidity | Static Analysis | via K8s Job |
| Moccasin | Vyper | Fuzzer | via K8s Job |
| Sol-Azy | Solana/Rust | Static Analysis | via K8s Job |
| Sec3 X-Ray | Solana/Rust | Static Analysis | via K8s Job |
| Trident | Solana/Rust | Fuzzer | via K8s Job |
| Cargo Fuzz | Solana/Rust | Fuzzer | via K8s Job |
| RustDefend | Solana/Rust | Static Analysis | via K8s Job |
| Vyper | Vyper | Static Analysis | via K8s Job |

## Files

| File | Role |
|------|------|
| `blocksecops-orchestration/src/blocksecops_orchestration/scanners/orchestrator.py` | `ScannerOrchestrator`: main execution loop |
| `blocksecops-orchestration/src/blocksecops_orchestration/scanners/base.py` | `ScannerContext`, `ScannerResult`, `ProjectFile` dataclasses |
| `blocksecops-orchestration/src/blocksecops_orchestration/scanners/registry.py` | `ScannerRegistry`: available scanner lookup |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py` | Scan request endpoint |
| `blocksecops-api-service/src/application/services/intelligence_pipeline_service.py` | Post-execution intelligence processing |

## Error Handling

- Each scanner executes independently; a failure in one does not stop others
- Failed scanners are recorded in `OrchestrationResult.failed_scanners`
- Exceptions during execution are caught and logged with `scanner_execution_error`
- Unavailable scanners are skipped with a warning log

## Related Pipelines

- [Scanner Job Execution Pipeline](./scanner-job-execution-pipeline.md) — K8s Job lifecycle, callback result collection, parsing, and forwarding (tool-integration service)
- [Intelligence Pipeline](./intelligence-pipeline.md) — processes raw findings after scan execution
- [Deduplication Pipeline](./deduplication-pipeline.md) — maintains deduplication groups post-scan
