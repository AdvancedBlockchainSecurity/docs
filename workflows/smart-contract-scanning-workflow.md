# Smart Contract Scanning Workflow

**Version:** 1.0.0
**Last Updated:** January 31, 2026
**Status:** Active

---

## Overview

This document provides a comprehensive audit of the smart contract scanning workflow in the BlockSecOps platform. It covers the complete end-to-end flow from contract upload to vulnerability display in the dashboard.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              BlockSecOps Platform                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────┐            │
│  │   Dashboard  │────▶│  API Service │────▶│  Tool Integration    │            │
│  │   (React)    │     │  (FastAPI)   │     │  (Scanner Execution) │            │
│  └──────────────┘     └──────┬───────┘     └──────────┬───────────┘            │
│         ▲                    │                        │                         │
│         │                    ▼                        ▼                         │
│         │            ┌──────────────┐     ┌──────────────────────┐            │
│         │            │ Orchestration│     │   Kubernetes Jobs    │            │
│         │            │   (Celery)   │     │  (Scanner Containers)│            │
│         │            └──────┬───────┘     └──────────────────────┘            │
│         │                   │                                                   │
│         │                   ▼                                                   │
│         │            ┌──────────────┐     ┌──────────────────────┐            │
│         └────────────│  PostgreSQL  │◀────│ Intelligence Engine  │            │
│                      │  (Database)  │     │  (Dedup/Classify)    │            │
│                      └──────────────┘     └──────────────────────┘            │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Services Involved

| Service | Purpose | Key Components |
|---------|---------|----------------|
| **blocksecops-api-service** | HTTP API gateway for contract/scan operations | `endpoints/contracts.py`, `endpoints/scans.py` |
| **blocksecops-orchestration** | Scan workflow orchestration via Celery | `scan_orchestrator.py`, Celery tasks |
| **blocksecops-tool-integration** | Scanner execution and result collection | `scanner_adapter.py`, Kubernetes Job management |
| **blocksecops-intelligence-engine** | ML/AI processing, deduplication, classification | `deduplication.py`, `classification.py` |
| **blocksecops-dashboard** | React UI for results display | `pages/Contracts`, `pages/Scans`, `pages/Vulnerabilities` |

---

## Workflow Phases

### Phase 1: Contract Upload

**Endpoints:**
- `POST /api/v1/upload` - File upload (single or archive)
- `POST /api/v1/contracts` - Create with inline source code

#### Upload Flow

```
User uploads file/archive
        │
        ▼
┌───────────────────┐
│ Validate file type│ .sol, .vy, .rs, .cairo, .zip, .tar, .tar.gz, .tgz
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Check size limits │ Tier-based limits (see table below)
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ LanguageDetector  │ Auto-detect: Solidity, Vyper, Rust, Move, Cairo
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Framework detect  │ For archives: Foundry, Hardhat, plain
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Create Contract   │ ContractModel with status="uploaded"
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Log activity      │ Activity record for audit trail
└───────────────────┘
```

#### File Size Limits by Tier

| Tier | Single File | Archive |
|------|-------------|---------|
| Developer | 5 MB | 25 MB |
| Team | 10 MB | 50 MB |
| Growth | 10 MB | 50 MB |
| Enterprise | 20 MB | 100 MB |

#### Supported File Types

| Extension | Language | Description |
|-----------|----------|-------------|
| `.sol` | Solidity | Ethereum smart contracts |
| `.vy` | Vyper | Python-like EVM contracts |
| `.rs` | Rust | Solana programs |
| `.cairo` | Cairo | StarkNet contracts |
| `.zip`, `.tar`, `.tar.gz`, `.tgz` | Multi-file | Project archives |

---

### Phase 2: Scan Initiation

**Endpoint:** `POST /api/v1/scans`

#### Request Schema

```json
{
  "contract_id": "uuid",
  "scanner_ids": ["slither", "aderyn", "semgrep"],
  "scan_type": "full",
  "scan_source": "web"
}
```

#### Scan Types

| Type | Description | Scanner Selection |
|------|-------------|-------------------|
| `quick` | Fast static analysis | Lightweight scanners only |
| `standard` | Comprehensive analysis | Static + one fuzzer |
| `deep` | Full security audit | All applicable scanners |
| `full` | Custom selection | User-specified scanners |

#### Scan Sources

| Source | Description |
|--------|-------------|
| `web` | Dashboard UI |
| `cli` | CLI tool |
| `vscode` | VS Code extension |
| `jetbrains` | JetBrains IDE plugin |
| `neovim` | Neovim plugin |
| `github_actions` | CI/CD pipeline |

#### Initiation Flow

```
User submits scan request
        │
        ▼
┌───────────────────┐
│ Validate contract │ Check ownership and existence
│ ownership         │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Check user quota  │ Monthly scan limits by tier
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Create ScanModel  │ status="queued", priority by tier
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Update contract   │ status="scanning"
│ status            │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Trigger tool-     │ HTTP POST for each scanner
│ integration       │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Log activity      │ Scan initiated record
└───────────────────┘
```

#### Response Codes

| Code | Description |
|------|-------------|
| `201 Created` | Scan queued successfully |
| `402 Payment Required` | Quota exceeded (includes payment options) |
| `403 Forbidden` | Not authorized for this contract |
| `404 Not Found` | Contract not found |
| `503 Service Unavailable` | Tool-integration service down |

---

### Phase 3: Scanner Execution (Tool Integration)

**Architecture:** Kubernetes Jobs for scanner isolation

#### Trigger Endpoint

`POST /scans/{scan_id}/trigger?scanner={scanner_id}`

#### Request Bodies

**Single File:**
```json
{
  "contract_source": "pragma solidity ^0.8.0; ...",
  "compiler_version": "0.8.20"
}
```

**Multi-File Project:**
```json
{
  "files": [
    {"path": "contracts/Token.sol", "content": "..."},
    {"path": "contracts/Utils.sol", "content": "..."}
  ],
  "main_file_path": "contracts/Token.sol",
  "compiler_version": "0.8.20"
}
```

#### Execution Flow

```
Receive trigger from API service
        │
        ▼
┌───────────────────┐
│ Create ConfigMap  │ Contains contract source code
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Create K8s Job    │ Scanner container with mounts
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Scanner executes  │ Reads from /source mount
│ analysis          │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Container POSTs   │ Results to callback URL
│ results           │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Parse raw output  │ Scanner-specific parsers
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Forward to API    │ Normalized vulnerabilities
│ service           │
└───────────────────┘
```

#### Kubernetes Job Template

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: scan-{scan_id}-{scanner_id}
spec:
  activeDeadlineSeconds: 300
  template:
    spec:
      containers:
      - name: scanner
        image: blocksecops/{scanner}:latest
        env:
        - name: API_CALLBACK_URL
          value: "http://api-service:8000/api/v1/store-results"
        volumeMounts:
        - name: source
          mountPath: /source
      volumes:
      - name: source
        configMap:
          name: contract-source-{scan_id}
      restartPolicy: Never
```

---

### Phase 4: Result Processing (Orchestration)

**Technology:** Celery distributed task queue

#### Celery Tasks

| Task | Schedule | Description |
|------|----------|-------------|
| `poll_scan_queue` | Every 10s | Finds queued scans, dispatches execution |
| `execute_scan_analysis` | On-demand | Main scan execution task |

#### Priority System

| Tier | Priority Value | Description |
|------|----------------|-------------|
| Enterprise | 5 | Highest priority |
| Growth | 25 | High priority |
| Team | 40 | Normal priority |
| Developer | 50 | Base priority |

*Lower value = Higher priority*

#### Orchestration Flow

```
poll_scan_queue (every 10s)
        │
        ▼
┌───────────────────┐
│ Query scans where │ status='queued' ORDER BY priority
│ status='queued'   │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Dispatch execute_ │ Celery task per scan
│ scan_analysis     │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Update status     │ 'queued' → 'running'
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Fetch contract    │ Load source code
│ and scan data     │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ ScannerOrchestrator│ Execute all requested scanners
│ .execute_scanners()│
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Collect results   │ Wait for all scanners
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Update status     │ 'running' → 'completed' or 'failed'
└───────────────────┘
```

---

### Phase 5: Intelligence Layer Processing

The intelligence engine processes raw scanner output to provide enhanced analysis.

#### Processing Pipeline

```
Raw scanner output
        │
        ▼
┌───────────────────┐
│ Parse to typed    │ Vulnerability, CodeQuality, Gas, Formal, Fuzzing
│ findings          │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Generate          │ Code, AST, Location, Fuzzy fingerprints
│ fingerprints      │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Pattern           │ Map to BVD codes
│ classification    │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Deduplication     │ Group across scanners
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Canonical         │ Select primary finding
│ selection         │
└───────────────────┘
```

#### Fingerprint Types

| Type | Field | Description |
|------|-------|-------------|
| Code | `fingerprint_code` | Source code hash |
| AST | `fingerprint_ast` | Abstract syntax tree structure hash |
| Location | `fingerprint_location` | File + line location hash (primary) |
| Fuzzy | `fingerprint_location_fuzzy` | Fuzzy location matching |
| Semantic | `fingerprint_semantic` | Semantic analysis hash |
| Composite | `fingerprint_composite` | Combined fingerprint |

#### Pattern Classification (BVD Codes)

Vulnerabilities are classified using BlockSecOps Vulnerability Database (BVD) codes:

```
Format: BVD-{CHAIN}-{CATEGORY}-{NUMBER}

Examples:
- BVD-SOLIDITY-REE-001  (Reentrancy)
- BVD-SOLIDITY-ACC-002  (Access Control)
- BVD-VYPER-OVF-001     (Integer Overflow)
- BVD-SOLANA-VAL-001    (Validation Error)
```

#### Deduplication Logic

```python
# Pseudocode for deduplication
def deduplicate_findings(findings: list[Vulnerability]) -> list[DeduplicationGroup]:
    groups = {}

    for finding in findings:
        key = finding.fingerprint_location
        if key not in groups:
            groups[key] = DeduplicationGroup(
                fingerprint=key,
                findings=[],
                severity_distribution={},
                scanner_distribution={}
            )
        groups[key].findings.append(finding)
        groups[key].severity_distribution[finding.severity] += 1
        groups[key].scanner_distribution[finding.scanner_id] += 1

    # Select canonical finding by scanner priority
    for group in groups.values():
        group.canonical = select_canonical(group.findings)
        group.canonical.is_primary = True
        group.canonical.duplicate_count = len(group.findings)

    return list(groups.values())
```

---

### Phase 6: Storage and Display

#### Database Models

##### VulnerabilityModel

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `scan_id` | UUID | Parent scan reference |
| `scanner_id` | String | Which scanner found it |
| `detector_id` | String | Scanner's check ID |
| `severity` | Enum | critical, high, medium, low |
| `title` | String | Vulnerability title |
| `description` | Text | Detailed description |
| `line_number` | Integer | Source line location |
| `code_snippet` | Text | Relevant code extract |
| `recommendation` | Text | Fix suggestion |
| `raw_output` | JSONB | Original scanner output |
| `pattern_id` | UUID | Pattern classification |
| `pattern_code` | String | BVD code |
| `fingerprint_location` | String | Location-based fingerprint |
| `is_primary` | Boolean | Canonical finding flag |
| `duplicate_count` | Integer | Number of duplicates |
| `status` | Enum | open, acknowledged, fixed, false_positive |

##### ScanModel

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `contract_id` | UUID | Contract reference |
| `status` | Enum | queued, running, completed, failed, cancelled |
| `scan_type` | String | quick, standard, deep, full |
| `scanner_ids` | Array | List of scanners used |
| `priority` | Integer | Execution priority |
| `critical_count` | Integer | Critical severity count |
| `high_count` | Integer | High severity count |
| `medium_count` | Integer | Medium severity count |
| `low_count` | Integer | Low severity count |
| `started_at` | Timestamp | Execution start time |
| `completed_at` | Timestamp | Execution end time |

##### DeduplicationGroupModel

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `fingerprint` | String | Group fingerprint |
| `canonical_id` | UUID | Primary finding reference |
| `severity_distribution` | JSONB | Severity counts |
| `scanner_distribution` | JSONB | Scanner counts |

#### Dashboard Pages

| Page | Route | Description |
|------|-------|-------------|
| Contract List | `/contracts` | All uploaded contracts |
| Contract Detail | `/contracts/{id}` | Single contract with scans |
| Scan List | `/scans` | All scans with status |
| Scan Detail | `/scans/{id}` | Scan results and vulnerabilities |
| Vulnerabilities | `/vulnerabilities` | Global vulnerability view |
| Deduplication | `/deduplication` | Duplicate finding groups |

#### Dashboard API Calls

```typescript
// Contract list
GET /api/v1/contracts

// Contract detail
GET /api/v1/contracts/{id}

// Scan list
GET /api/v1/scans?status=completed&sort=-created_at

// Scan detail with vulnerabilities
GET /api/v1/scans/{id}
GET /api/v1/vulnerabilities?scan_id={id}

// Specialized result types
GET /api/v1/scans/{id}/result-types
GET /api/v1/scans/{id}/code-quality
GET /api/v1/scans/{id}/gas-analysis
GET /api/v1/scans/{id}/formal-verification
GET /api/v1/scans/{id}/fuzzing

// Scan comparison
GET /api/v1/scans/compare?scan1={id1}&scan2={id2}
```

---

## Scan State Machine

```
                 ┌─────────────────┐
                 │     queued      │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
          ┌──────│     running     │──────┐
          │      └─────────────────┘      │
          │                               │
          ▼                               ▼
┌─────────────────┐             ┌─────────────────┐
│    completed    │             │     failed      │
└─────────────────┘             └─────────────────┘
          │                               │
          │                               │
          ▼                               ▼
┌─────────────────┐             ┌─────────────────┐
│    cancelled    │             │   (can retry)   │
└─────────────────┘             └─────────────────┘
```

### Status Definitions

| Status | Description |
|--------|-------------|
| `queued` | Scan created, waiting for worker |
| `running` | Scanners actively executing |
| `completed` | All scanners finished successfully |
| `failed` | One or more scanners failed |
| `cancelled` | User cancelled the scan |

---

## Scanner Reference

### Solidity Scanners (11)

| Scanner | Type | Estimated Time | Requires Project | Detectors |
|---------|------|----------------|------------------|-----------|
| **slither** | Static Analysis | 15s | No | 93 |
| **aderyn** | Static Analysis | 20s | No | 88 |
| **mythril** | Symbolic Execution | 180s | No | 4 |
| **semgrep** | Pattern Matching | 10s | No | 47 |
| **solhint** | Linter | 5s | No | 20 |
| **wake** | Static Analysis | 25s | No | - |
| **soliditydefend** | Static Analysis | 30s | No | 204+ |
| **echidna** | Fuzzer | 120s | Yes | - |
| **medusa** | Fuzzer | 180s | Yes | - |
| **halmos** | Formal Verification | 180s | Yes | - |
| **foundry-fuzz** | Fuzzer | 120s | Yes | - |

### Vyper Scanners (2)

| Scanner | Type | Estimated Time | Requires Project |
|---------|------|----------------|------------------|
| **vyper** | Static Analysis | 20s | No |
| **moccasin** | Fuzzer | 90s | Yes |

### Solana/Rust Scanners (4)

| Scanner | Type | Estimated Time | Requires Project | Status |
|---------|------|----------------|------------------|--------|
| **sol-azy** | Static Analysis | 30s | No | Pending |
| **sec3-xray** | Static Analysis | 60s | Yes | Pending |
| **trident** | Fuzzer | 120s | Yes | Pending |
| **cargo-fuzz-solana** | Fuzzer | 150s | Yes | Pending |

### Scan Presets

#### Solidity

| Preset | Scanners | Est. Time |
|--------|----------|-----------|
| Quick | slither, aderyn, semgrep, solhint, wake, soliditydefend | ~105s |
| Standard | Quick + echidna | ~235s |
| Deep | Standard + halmos, medusa | ~510s |

#### Vyper

| Preset | Scanners | Est. Time |
|--------|----------|-----------|
| Quick | vyper | ~20s |
| Standard | vyper, moccasin | ~110s |

#### Rust/Solana

| Preset | Scanners | Est. Time |
|--------|----------|-----------|
| Quick | sol-azy | ~30s |
| Standard | sol-azy, sec3-xray, trident | ~210s |
| Deep | Standard + cargo-fuzz-solana | ~360s |

---

## API Endpoints Reference

### Contract Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/upload` | Upload contract file |
| `POST` | `/api/v1/contracts` | Create contract with inline source |
| `GET` | `/api/v1/contracts` | List contracts |
| `GET` | `/api/v1/contracts/{id}` | Get contract details |
| `DELETE` | `/api/v1/contracts/{id}` | Delete contract |

### Scan Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/scans` | Create scan |
| `POST` | `/api/v1/scans/batch` | Create batch scan |
| `GET` | `/api/v1/scans` | List scans |
| `GET` | `/api/v1/scans/{id}` | Get scan details |
| `DELETE` | `/api/v1/scans/{id}` | Delete scan |
| `GET` | `/api/v1/scans/{id}/result-types` | Get available result types |
| `GET` | `/api/v1/scans/{id}/code-quality` | Get code quality findings |
| `GET` | `/api/v1/scans/{id}/gas-analysis` | Get gas optimization findings |
| `GET` | `/api/v1/scans/{id}/formal-verification` | Get formal verification results |
| `GET` | `/api/v1/scans/{id}/fuzzing` | Get fuzzing results |
| `GET` | `/api/v1/scans/compare` | Compare two scans |

### Scanner Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/scanners` | List available scanners |
| `GET` | `/api/v1/scanners/presets/{language}` | Get scan presets |

### Vulnerability Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/vulnerabilities` | List vulnerabilities |
| `GET` | `/api/v1/vulnerabilities/{id}` | Get vulnerability details |
| `PATCH` | `/api/v1/vulnerabilities/{id}` | Update vulnerability status |

---

## Configuration

### Environment Variables

#### API Service

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Required |
| `REDIS_URL` | Redis connection string | Required |
| `TOOL_INTEGRATION_URL` | Tool integration service URL | `http://tool-integration:8005` |
| `ORCHESTRATION_URL` | Orchestration service URL | `http://orchestration:8004` |

#### Orchestration Service

| Variable | Description | Default |
|----------|-------------|---------|
| `CELERY_BROKER_URL` | Redis/RabbitMQ broker | Required |
| `CELERY_RESULT_BACKEND` | Result backend URL | Required |
| `API_SERVICE_URL` | API service callback URL | `http://api-service:8000` |
| `POLL_INTERVAL` | Queue poll interval | `10` (seconds) |

#### Tool Integration Service

| Variable | Description | Default |
|----------|-------------|---------|
| `KUBERNETES_NAMESPACE` | Job execution namespace | `scanner-jobs` |
| `API_CALLBACK_URL` | Result callback URL | `http://api-service:8000/api/v1/store-results` |
| `JOB_TIMEOUT` | Default job timeout | `300` (seconds) |

### ConfigMaps

#### Scanner Metadata

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-metadata
data:
  scanners.json: |
    {
      "slither": {
        "image": "blocksecops/slither:0.2.0",
        "language": "solidity",
        "type": "static_analysis",
        "timeout": 300
      },
      ...
    }
```

---

## Quota and Billing

### Monthly Scan Limits

| Tier | Monthly Scans | Notes |
|------|---------------|-------|
| Developer | 3 | Free tier |
| Team | Configurable | Team plan |
| Growth | Configurable | Growth plan |
| Enterprise | Unlimited | Enterprise plan |

### Quota Enforcement

- Checked at scan creation
- 402 Payment Required response for quota exceeded
- Incremented only on successful completion
- Reset on 1st of month at UTC 00:00

---

## Related Documentation

- [Scanner Documentation](../scanners/README.md) - Detailed scanner guides
- [Intelligence Integration Standards](../standards/INTELLIGENCE-INTEGRATION-STANDARDS.md) - Deduplication and classification
- [API Documentation](../api/README.md) - Complete API reference
- [Database Schema](../database/schema.md) - Full database documentation

---

**Maintained by:** BlockSecOps Platform Team
**Last Audit:** January 31, 2026
