# Slither Scanner Integration Documentation

**Version:** 0.2.0
**Last Updated:** 2025-12-05
**Scanner Version:** Slither 0.11.3
**Solc-select Version:** 1.1.0
**Docker Image:** scanner-slither:0.2.0

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)
7. [References](#references)

---

## Overview

Slither is a static analysis framework for Solidity smart contracts that runs as an isolated Kubernetes Job in the BlockSecOps platform. It detects vulnerabilities, code quality issues, and provides optimization recommendations.

### Key Features

- **Static Analysis**: Detects 90+ vulnerability patterns without executing code
- **Isolation**: Runs in dedicated Kubernetes Jobs to avoid dependency conflicts
- **Compiler Support**: Multiple Solidity compiler versions (0.8.18, 0.8.19, 0.8.20)
- **Result Parsing**: Automated parsing of JSON output with standardized vulnerability schema
- **Status Tracking**: Production-ready status determination with false-positive prevention

### Detection Capabilities

- Reentrancy attacks
- Access control vulnerabilities
- Arithmetic issues
- Timestamp dependence
- Unchecked call return values
- Uninitialized storage pointers
- Weak randomness
- Gas optimization opportunities

---

##  Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         BlockSecOps Platform                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────┐   ┌───────────────────┐   ┌───────────────────┐  │
│  │   Dashboard     │◄──┤   API Service     │◄──┤  Tool Integration │  │
│  │   (Port 3000)   │   │   (Port 8000)     │   │    (Port 8005)    │  │
│  └────────┬────────┘   └─────────┬─────────┘   └─────────┬─────────┘  │
│           │                      │                         │             │
│           │                      │                         │             │
│           │  1. Create Scan      │                         │             │
│           ├─────────────────────►│                         │             │
│           │                      │  2. Trigger Scanner     │             │
│           │                      ├────────────────────────►│             │
│           │                      │                         │             │
│           │                      │      3. Create Job      │             │
│           │                      │◄────────────────────────┤             │
│           │                      │                         │             │
└───────────┼──────────────────────┼─────────────────────────┼─────────────┘
            │                      │                         │
            │                      │                         │
            │                      │                         ▼
            │                      │              ┌─────────────────────┐
            │                      │              │  Kubernetes Job     │
            │                      │              │  scan-slither-XXX   │
            │                      │              ├─────────────────────┤
            │                      │              │                     │
            │                      │              │  ┌───────────────┐ │
            │                      │              │  │  ConfigMap    │ │
            │                      │              │  │  (Contract    │ │
            │                      │              │  │   Source)     │ │
            │                      │              │  └───────────────┘ │
            │                      │              │         │          │
            │                      │              │         ▼          │
            │                      │              │  ┌───────────────┐ │
            │                      │              │  │   Slither     │ │
            │                      │              │  │   Scanner     │ │
            │                      │              │  │   (Python)    │ │
            │                      │              │  └───────┬───────┘ │
            │                      │              │          │          │
            │                      │              │          ▼          │
            │                      │              │  ┌───────────────┐ │
            │                      │              │  │ run-slither   │ │
            │                      │              │  │  .sh wrapper  │ │
            │                      │              │  └───────┬───────┘ │
            │                      │              │          │          │
            │                      │              └──────────┼──────────┘
            │                      │                         │
            │                      │   4. POST /results      │
            │                      │◄────────────────────────┘
            │                      │   (JSON with vulnerabilities)
            │                      │
            │  5. GET /scans/:id   │
            │◄─────────────────────┤
            │                      │
            ▼                      │
     Display Results               │
                                   ▼
                            ┌──────────────┐
                            │  PostgreSQL  │
                            │   Database   │
                            └──────────────┘
                            - Scans table
                            - Vulnerabilities table
```

### Service Communication

| From | To | Protocol | Purpose |
|------|----|---------| --------|
| Dashboard | API Service | HTTP/REST | Create scans, fetch results |
| API Service | Tool Integration | HTTP/REST | Trigger scanner execution |
| Tool Integration | Kubernetes API | gRPC | Create/manage Jobs |
| Scanner Job | Tool Integration | HTTP/POST | Submit scan results |
| Tool Integration | API Service | HTTP/POST | Forward parsed results |
| Result Collector | API Service | HTTP/GET | Check scan status |

---

## Component Details

### 1. Scanner Docker Image

**Location:** `/blocksecops-tool-integration/scanner-images/slither/`

**Dockerfile Overview:**
```dockerfile
FROM python:3.11-slim

# System dependencies
RUN apt-get install -y git build-essential curl jq

# Python dependencies
RUN pip install slither-analyzer==0.11.3 solc-select==1.1.0

# Pre-installed Solidity compilers
RUN solc-select install 0.8.20 && \
    solc-select install 0.8.19 && \
    solc-select install 0.8.18

# Wrapper script
COPY run-slither.sh /app/run-slither.sh

ENTRYPOINT ["/app/run-slither.sh"]
```

**Key Libraries:**
- **slither-analyzer (0.11.3)**: Core static analysis framework by Trail of Bits
- **solc-select (1.1.0)**: Solidity compiler version manager (updated December 2025)
- **jq**: JSON processing for wrapping scanner output

### 2. Wrapper Script (`run-slither.sh`)

**Location:** `/blocksecops-tool-integration/scanner-images/slither/run-slither.sh`

**Responsibilities:**
1. Validate environment variables (CALLBACK_URL, SCAN_ID)
2. Set Solidity compiler version using solc-select
3. Discover contract files in `/contracts` directory
4. Execute Slither with JSON output format
5. Wrap results with scanner identification
6. POST results to callback URL

**Critical Sections:**

```bash
# Set compiler version (dynamic based on contract pragma)
solc-select use "$SOLC_VERSION"

# Run Slither analysis
slither /contracts --json "$OUTPUT_FILE"

# Wrap output with scanner field
jq '. + {"scanner": "slither"}' "$OUTPUT_FILE" > "$WRAPPED_OUTPUT"

# POST results to tool-integration
curl -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -d @"$WRAPPED_OUTPUT"
```

**Exit Code Behavior:**
- **Exit 0**: Results successfully posted to callback URL
- **Exit 1**: Failed to POST results OR Slither encountered fatal error
- **Non-zero during analysis**: Normal when vulnerabilities are found (captured but not failed)

### 3. Kubernetes Job Manager

**Location:** `/blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py`

**Key Methods:**

#### `create_scanner_job(scan_id, scanner_name, contract_source, compiler_version)`
Creates a Kubernetes Job with:
- ConfigMap containing contract source code
- Environment variables (CALLBACK_URL, SCAN_ID, SOLC_VERSION)
- Resource limits (CPU: 500m, Memory: 512Mi)
- Backoff limit: 3 retries
- TTL after finished: 3600 seconds (1 hour)

#### `create_configmap(scan_id, contract_source, filename)`
Creates a ConfigMap to mount contract source into the scanner pod at `/contracts/contract.sol`

**Job Spec Structure:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: scan-slither-<scan-id-prefix>
  labels:
    scanner: slither
    scan-id: <full-scan-id>
spec:
  backoffLimit: 3
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      containers:
      - name: scanner
        image: scanner-slither:latest
        env:
        - name: CALLBACK_URL
          value: http://tool-integration.tool-integration-local.svc.cluster.local:8005/api/v1/scans/<scan-id>/results
        - name: SCAN_ID
          value: <scan-id>
        - name: SOLC_VERSION
          value: "0.8.20"
        volumeMounts:
        - name: contract-source
          mountPath: /contracts
      volumes:
      - name: contract-source
        configMap:
          name: scan-<scan-id-prefix>-source
      restartPolicy: Never
```

### 4. Result Collector

**Location:** `/blocksecops-tool-integration/src/scanners/result_collector.py`

**Purpose:** Background service that polls Kubernetes Jobs every 60 seconds to handle completed scans

**Key Logic:**

#### Successful Jobs (`status.succeeded == 1`)
```python
# Scanner already POSTed results directly
# Result collector only cleanup ConfigMap
self.job_manager.delete_configmap(scan_id)
```

#### Failed Jobs (`status.failed >= backoff_limit`)
```python
# Check if results were posted before failure
has_results = await self._check_scan_has_results(scan_id)

if has_results:
    # FALSE POSITIVE: Scanner posted results but exited with non-zero code
    # Example: Slither exits 255 when vulnerabilities found
    logger.info("Scan has results despite Job failure - skipping failure status")
else:
    # TRUE FAILURE: Scanner crashed before posting results
    await self._send_results(scan_id, {"status": "failed"})
```

**Critical Fix (PR #43):**
The `/check-results` endpoint prevents false-positive failures when scanners successfully post results but exit with non-zero codes.

### 5. Slither Parser

**Location:** `/blocksecops-tool-integration/src/scanners/slither_parser.py`

**Responsibilities:**
- Parse Slither JSON output
- Map Slither severity/confidence to platform schema
- Extract code locations (file, line number, snippet)
- Generate remediation recommendations
- Map detectors to SWC IDs (Smart Contract Weakness Classification)
- Assign vulnerability categories

**Severity Mapping:**
| Slither Impact | Platform Severity |
|----------------|-------------------|
| High | critical |
| Medium | high |
| Low | medium |
| Informational | low |
| Optimization | low |

**Confidence Mapping:**
| Slither Confidence | Platform Score |
|--------------------|----------------|
| High | 0.9 |
| Medium | 0.7 |
| Low | 0.5 |

**Category Classification:**
- `reentrancy`: Reentrancy attack vectors
- `access_control`: Authorization and permission issues
- `arithmetic`: Math and calculation vulnerabilities
- `best_practice`: Code quality and safety patterns
- `gas_optimization`: Gas efficiency improvements
- `uncategorized`: Unknown or unmapped detector types

**SWC Mapping Examples:**
```python
SWC_MAP = {
    "reentrancy-eth": "SWC-107",         # Reentrancy
    "timestamp": "SWC-116",              # Timestamp Dependence
    "controlled-delegatecall": "SWC-112", # Delegatecall to Untrusted Callee
    "tx-origin": "SWC-115",              # Authorization through tx.origin
    "weak-prng": "SWC-120",              # Weak Sources of Randomness
}
```

### 6. API Service Endpoints

**Location:** `/blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py`

#### POST `/api/v1/scans`
**Purpose:** Create a new scan and trigger scanner execution

**Request Body:**
```json
{
  "contract_id": "uuid",
  "scanners": ["slither", "semgrep", "mythril"]
}
```

**Flow:**
1. Validate contract exists and belongs to user
2. Check for consecutive failure limit (3 failed scans = temporary ban)
3. Create scan record with status "queued"
4. For each selected scanner:
   - POST to Tool Integration `/scans/{scan_id}/trigger?scanner=slither`
   - Update scan.scanners_used array
5. Set scan status to "running"
6. Return scan object

#### POST `/api/v1/scans/{scan_id}/results`
**Purpose:** Receive results from scanner Jobs (called by Tool Integration)

**Request Body:**
```json
{
  "scanner": "slither",
  "status": "completed",
  "vulnerabilities": [
    {
      "vulnerability_type": "reentrancy-eth",
      "severity": "critical",
      "title": "Reentrancy Attack (Ether)",
      "description": "...",
      "line_number": 42,
      "code_snippet": "...",
      "recommendation": "...",
      "confidence": 0.9,
      "scanner_id": "slither",
      "category": "reentrancy"
    }
  ]
}
```

**Flow:**
1. Validate scan exists
2. Update scan status to "completed" (or keep as "failed" if status="failed")
3. Bulk insert vulnerabilities
4. Broadcast WebSocket update to dashboard
5. Return success response

#### GET `/api/v1/scans/{scan_id}/check-results`
**Purpose:** Check if a scan has posted results (used by Result Collector)

**Response:**
```json
{
  "has_results": true,
  "vulnerability_count": 23
}
```

**Logic:**
```python
# Check if scan has ANY vulnerabilities
vulnerability_count = db.query(Vulnerability).filter_by(scan_id=scan_id).count()
has_results = vulnerability_count > 0
```

**CRITICAL:** This endpoint is used by Result Collector to distinguish between:
- **False positive failures**: Scanner posted results but Job failed (exit code 255)
- **True failures**: Scanner crashed before posting results

#### GET `/api/v1/scans/{scan_id}`
**Purpose:** Fetch scan details and vulnerabilities for dashboard

**Response:**
```json
{
  "id": "uuid",
  "contract_id": "uuid",
  "status": "completed",
  "scanners_used": ["slither", "semgrep"],
  "created_at": "2025-11-06T12:00:00Z",
  "updated_at": "2025-11-06T12:05:00Z",
  "vulnerabilities": [
    {
      "id": "uuid",
      "vulnerability_type": "reentrancy-eth",
      "severity": "critical",
      "title": "Reentrancy Attack (Ether)",
      "description": "...",
      "line_number": 42,
      "code_snippet": "...",
      "recommendation": "...",
      "status": "open",
      "confidence": 0.9,
      "scanner_id": "slither",
      "category": "reentrancy",
      "swc_id": "SWC-107"
    }
  ]
}
```

### 7. Tool Integration Service

**Location:** `/blocksecops-tool-integration/src/main.py`

**Lifespan Events:**
```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    app.state.job_manager = KubernetesJobManager(namespace="tool-integration-local")
    app.state.result_collector = ResultCollector(namespace="tool-integration-local")

    # Start background polling (60s interval)
    app.state.collector_task = asyncio.create_task(
        app.state.result_collector.start_polling(interval=60)
    )

    yield

    # Shutdown
    app.state.collector_task.cancel()
```

#### POST `/scans/{scan_id}/trigger?scanner=slither`
**Purpose:** Create Kubernetes Job for scanner execution

**Request Body:**
```json
{
  "contract_source": "pragma solidity ^0.8.0; contract MyContract { ... }",
  "compiler_version": "0.8.20"
}
```

**Flow:**
1. Validate scanner name (must be in allowed list)
2. Parse request body for contract_source and compiler_version
3. Create Kubernetes Job via `job_manager.create_scanner_job()`
4. Return job name and success status

#### POST `/api/v1/scans/{scan_id}/results`
**Purpose:** Receive results from scanner containers (called by run-slither.sh)

**Flow for Slither:**
1. Extract scanner type from `results_json["scanner"]`
2. Parse Slither JSON using `SlitherParser()`
3. Convert vulnerabilities to standardized format
4. Create ScanResults payload with scanner="slither", status="completed"
5. Forward to API Service `POST /api/v1/scans/{scan_id}/results`
6. Return success response

**Result Transformation:**
```python
# Slither-specific parsing
parser = SlitherParser()
vulnerabilities = parser.parse(results_str, contract_id, scan_id)

# Transform to standardized format
vulnerability_results = []
for vuln in vulnerabilities:
    vulnerability_results.append({
        "vulnerability_type": vuln.get("vulnerability_type"),
        "severity": vuln.get("severity"),
        "title": vuln.get("title"),
        "description": vuln.get("description"),
        "line_number": vuln.get("line_number"),
        "code_snippet": vuln.get("code_snippet"),
        "recommendation": vuln.get("recommendation"),
        "confidence": vuln.get("confidence", 0.5),
        "scanner_id": "slither",
        "category": vuln.get("category", "uncategorized"),
        "scanner_name": "slither"
    })

# Post to API Service
scan_results = {
    "scanner": "slither",
    "status": "completed",
    "vulnerabilities": vulnerability_results
}
```

---

## Data Flow

### Complete End-to-End Scan Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. SCAN INITIATION (Dashboard → API Service)                          │
└────────────────────────────────────────────────────────────────────────┘

User clicks "Run Scan" on Dashboard
  ↓
POST /api/v1/scans
  {
    "contract_id": "abc-123",
    "scanners": ["slither"]
  }
  ↓
API Service:
  - Create scan record (status: "queued", scanners_used: {})
  - Validate no recent consecutive failures
  - Fetch contract source code from database
  ↓

┌────────────────────────────────────────────────────────────────────────┐
│ 2. SCANNER TRIGGERING (API Service → Tool Integration)                │
└────────────────────────────────────────────────────────────────────────┘

For scanner in ["slither"]:
  POST http://tool-integration:8005/scans/{scan_id}/trigger?scanner=slither
    {
      "contract_source": "pragma solidity...",
      "compiler_version": "0.8.20"
    }
  ↓
Tool Integration:
  - Validate scanner name
  - Call job_manager.create_scanner_job()
  ↓

┌────────────────────────────────────────────────────────────────────────┐
│ 3. JOB CREATION (Tool Integration → Kubernetes)                       │
└────────────────────────────────────────────────────────────────────────┘

Job Manager:
  - Create ConfigMap with contract source
    Name: scan-<scan-id-prefix>-source
    Data: contract.sol: <source code>

  - Create Kubernetes Job
    Name: scan-slither-<scan-id-prefix>
    Labels:
      scanner: slither
      scan-id: <full-scan-id>
    Spec:
      Image: scanner-slither:latest
      Env:
        CALLBACK_URL: http://tool-integration:8005/api/v1/scans/<scan-id>/results
        SCAN_ID: <scan-id>
        SOLC_VERSION: "0.8.20"
      Volumes:
        - ConfigMap mounted at /contracts

  - Update scan status to "running"
  ↓

┌────────────────────────────────────────────────────────────────────────┐
│ 4. SCANNER EXECUTION (Kubernetes Job)                                 │
└────────────────────────────────────────────────────────────────────────┘

Kubernetes schedules Pod
  ↓
run-slither.sh entrypoint:
  1. Validate env vars (CALLBACK_URL, SCAN_ID)
  2. Set solc version: solc-select use 0.8.20
  3. Find contracts: find /contracts -name "*.sol"
  4. Run analysis: slither /contracts --json /tmp/slither-results.json
  5. Wrap output: jq '. + {"scanner": "slither"}' > wrapped.json
  6. POST results:
     curl -X POST $CALLBACK_URL -d @wrapped.json
  ↓
  Exit 0 (success) or Exit 1 (failure)
  ↓

┌────────────────────────────────────────────────────────────────────────┐
│ 5. RESULT SUBMISSION (Scanner → Tool Integration)                     │
└────────────────────────────────────────────────────────────────────────┘

POST http://tool-integration:8005/api/v1/scans/{scan_id}/results
  {
    "scanner": "slither",
    "success": true,
    "results": {
      "detectors": [
        {
          "check": "reentrancy-eth",
          "impact": "High",
          "confidence": "High",
          "description": "Reentrancy in...",
          "elements": [...]
        }
      ]
    }
  }
  ↓
Tool Integration main.py:
  - Detect scanner type from payload
  - Parse with SlitherParser()
  - Transform to standardized vulnerability format
  ↓

┌────────────────────────────────────────────────────────────────────────┐
│ 6. RESULT FORWARDING (Tool Integration → API Service)                 │
└────────────────────────────────────────────────────────────────────────┘

POST http://api-service:8000/api/v1/scans/{scan_id}/results
  {
    "scanner": "slither",
    "status": "completed",
    "vulnerabilities": [
      {
        "vulnerability_type": "reentrancy-eth",
        "severity": "critical",
        "title": "Reentrancy Attack (Ether)",
        "description": "...",
        "line_number": 42,
        "code_snippet": "...",
        "recommendation": "...",
        "confidence": 0.9,
        "scanner_id": "slither",
        "category": "reentrancy",
        "swc_id": "SWC-107"
      }
    ]
  }
  ↓
API Service:
  - Update scan status to "completed"
  - Bulk insert vulnerabilities into database
  - Broadcast WebSocket update to connected dashboards
  ↓

┌────────────────────────────────────────────────────────────────────────┐
│ 7. RESULT COLLECTION (Background - Result Collector)                  │
└────────────────────────────────────────────────────────────────────────┘

Every 60 seconds, Result Collector polls Kubernetes Jobs:
  ↓
For each Job:
  Check status.succeeded or status.failed
  ↓

  If Job succeeded:
    - Scanner already posted results directly
    - Delete ConfigMap
    - Mark Job as processed

  If Job failed:
    - Check if results exist: GET /api/v1/scans/{scan_id}/check-results
    - If has_results: FALSE POSITIVE (scanner posted results, exit code 255)
      → Skip failure status update
    - If no results: TRUE FAILURE (scanner crashed before posting)
      → POST failure status to API Service
    - Delete ConfigMap
    - Mark Job as processed
  ↓

┌────────────────────────────────────────────────────────────────────────┐
│ 8. RESULT DISPLAY (Dashboard)                                         │
└────────────────────────────────────────────────────────────────────────┘

Dashboard polls: GET /api/v1/scans/{scan_id}
  ↓
Display:
  - Scan status badge (completed/failed/running)
  - Vulnerability count
  - List of vulnerabilities with:
    - Severity badges
    - Title and description
    - Code snippet with line numbers
    - Remediation recommendations
    - SWC IDs
    - Confidence scores
```

### Timing Breakdown

| Stage | Typical Duration | Notes |
|-------|------------------|-------|
| Scan Creation | ~100ms | Database write + scanner triggers |
| Job Creation | ~500ms | ConfigMap + Job creation in Kubernetes |
| Pod Scheduling | ~2-5s | Kubernetes scheduler + image pull (cached) |
| Slither Analysis | ~10-30s | Depends on contract complexity |
| Result POST | ~200ms | Network latency + parsing |
| Database Write | ~500ms | Bulk insert vulnerabilities |
| **Total** | **~15-40s** | From "Run Scan" to results visible |

---

## Configuration

### Environment Variables

#### Scanner Container
```bash
# Required
CALLBACK_URL="http://tool-integration:8005/api/v1/scans/{scan_id}/results"
SCAN_ID="abc-123-def-456"

# Optional
SOLC_VERSION="0.8.20"  # Default: 0.8.20
CONTRACT_NAME="MyContract"  # For logging only
```

#### Tool Integration Service
```bash
# Kubernetes namespace where scanner Jobs run
NAMESPACE="tool-integration-local"

# API Service URL for forwarding results
API_SERVICE_URL="http://api-service.api-service-local.svc.cluster.local:8000"

# Result collector polling interval (seconds)
COLLECTOR_INTERVAL="60"
```

### Resource Limits

**Kubernetes Job Spec:**
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

**Rationale:**
- Slither is CPU-intensive during analysis
- Memory usage scales with contract size (typically < 512Mi)
- Resource limits prevent runaway processes

### Retry Configuration

```yaml
backoffLimit: 3  # Maximum retry attempts
```

**Retry Scenarios:**
- Pod eviction (node failure, resource pressure)
- Slither crashes (out of memory, segfault)
- Network failures during result POST

**Not Retried:**
- Successful result POST (exit 0)
- Analysis errors (invalid Solidity, compilation failures)

---

## Troubleshooting

### Common Issues

#### 1. Scans Marked as "Failed" Despite Success

**Symptom:** Scan shows "failed" status but vulnerabilities are present

**Root Cause:** Slither exits with code 255 when it finds high-severity vulnerabilities

**Solution (Implemented in PR #43):**
```python
# Result Collector checks if results were posted before marking as failed
has_results = await self._check_scan_has_results(scan_id)
if has_results:
    logger.info("Scan has results - this is a false positive failure")
    # Skip sending failure status
else:
    await self._send_results(scan_id, {"status": "failed"})
```

**Verification:**
```bash
# Check if scan has vulnerabilities
curl http://api-service:8000/api/v1/scans/{scan_id}/check-results

# Expected response for successful scan with vulnerabilities:
{"has_results": true, "vulnerability_count": 23}
```

#### 2. Job Stuck in "Pending" State

**Symptom:** Kubernetes Job never starts running

**Possible Causes:**
- Insufficient cluster resources
- Image pull failures
- ConfigMap not created

**Debug Commands:**
```bash
# Check Job status
kubectl get job scan-slither-<scan-id-prefix> -n tool-integration-local

# Check Pod events
kubectl describe pod -l job-name=scan-slither-<scan-id-prefix> -n tool-integration-local

# Check ConfigMap exists
kubectl get configmap scan-<scan-id-prefix>-source -n tool-integration-local
```

**Resolution:**
- Ensure Docker image is built and available in minikube
- Check for resource quota limits
- Verify ConfigMap was created successfully

#### 3. Slither Compilation Errors

**Symptom:** Job fails with "solc" compilation errors

**Root Causes:**
- Wrong Solidity compiler version
- Missing pragma statement
- Invalid Solidity syntax

**Debug:**
```bash
# View scanner logs
kubectl logs -l job-name=scan-slither-<scan-id-prefix> -n tool-integration-local

# Common error patterns:
# "Error: Source file requires different compiler version"
# → Update compiler_version in scan request

# "ParserError: Expected..."
# → Fix Solidity syntax errors
```

**Solution:**
- Specify correct `compiler_version` when creating scan
- Ensure contract has `pragma solidity ^0.8.X;` statement
- Test contract compiles locally: `solc --version && solc contract.sol`

#### 4. ConfigMap Not Found

**Symptom:** Pod fails with "unable to mount ConfigMap"

**Root Cause:** Race condition between ConfigMap creation and Job scheduling

**Debug:**
```bash
# Check if ConfigMap exists
kubectl get configmap -n tool-integration-local | grep scan-

# View ConfigMap content
kubectl get configmap scan-<prefix>-source -n tool-integration-local -o yaml
```

**Solution:**
- Job Manager creates ConfigMap before Job (already implemented)
- If issue persists, check for RBAC permissions

#### 5. Result POST Failures

**Symptom:** Scanner completes but results never appear

**Debug Scanner Logs:**
```bash
kubectl logs -l job-name=scan-slither-<prefix> -n tool-integration-local

# Look for:
# "✗ Failed to post results (HTTP 500)"
# "curl: (6) Could not resolve host"
```

**Possible Causes:**
- Tool Integration service not reachable
- Invalid CALLBACK_URL
- Network policy blocking traffic

**Verification:**
```bash
# Check Tool Integration is running
kubectl get pods -n tool-integration-local

# Test connectivity from scanner pod
kubectl run curl-test --image=curlimages/curl --rm -it -- \
  curl http://tool-integration.tool-integration-local.svc.cluster.local:8005/health
```

#### 6. Memory/CPU Limits Exceeded

**Symptom:** Pod killed with OOMKilled or CPU throttling

**Debug:**
```bash
# Check Pod resource usage
kubectl top pod -l job-name=scan-slither-<prefix> -n tool-integration-local

# View Pod events
kubectl get events -n tool-integration-local --field-selector involvedObject.name=<pod-name>
```

**Solution:**
- Increase resource limits in Job spec
- Simplify contract (split large contracts into modules)
- Review Slither detector selection (disable expensive detectors)

### Debugging Workflow

```
1. Scan Status Check
   GET /api/v1/scans/{scan_id}
   ↓
   Is status "failed"?
   ↓

2. Check Kubernetes Job
   kubectl get job scan-slither-<prefix> -n tool-integration-local
   ↓
   Job succeeded (1/1)?
   ├─ Yes → Result Collector false positive issue (see PR #43)
   └─ No → Check Pod status
      ↓

3. Check Pod Events
   kubectl describe pod -l job-name=scan-slither-<prefix>
   ↓
   Pod status?
   ├─ Pending → Resource/scheduling issue
   ├─ OOMKilled → Memory limit exceeded
   ├─ Error → Slither analysis failed
   └─ Completed → Check logs
      ↓

4. View Scanner Logs
   kubectl logs -l job-name=scan-slither-<prefix>
   ↓
   Check for:
   - Compilation errors
   - POST result failures
   - Slither detector errors
   ↓

5. Check Result Collector Logs
   kubectl logs -n tool-integration-local deployment/tool-integration
   ↓
   Search for scan_id to see Result Collector decisions
```

### Log Analysis

**Successful Scan Logs (run-slither.sh):**
```
=== Slither Scanner ===
Scan ID: abc-123-def-456
Contract: contract.sol
Solc Version: 0.8.20

Setting solc version to 0.8.20...
Scanning for Solidity files...
Found files:
/contracts/contract.sol

Running Slither analysis...
Slither exit code: 255

Analysis complete. Results:
{"success": true, "results": {"detectors": [...]}}

Adding scanner identification...
Posting results to http://tool-integration:8005/...
✓ Results posted successfully (HTTP 200)
```

**Failed Scan Logs:**
```
ERROR: No .sol files found in /contracts
# → ConfigMap not mounted or empty

ERROR: Invalid JSON output from Slither
# → Slither crashed or produced invalid output

✗ Failed to post results (HTTP 500)
# → Tool Integration unreachable or error
```

**Result Collector Logs (result_collector.py):**
```
# False Positive (Scan has results despite Job failure)
INFO: Job scan-slither-abc123 marked as failed by Kubernetes
INFO: Scan abc-123-def-456 has results in database despite Job failure
INFO: Scanner successfully posted results before container exit
INFO: Skipping failure status update

# True Failure (No results posted)
WARNING: Scan abc-123-def-456 has no results in database
WARNING: This is a true failure - scanner did not post results
INFO: Sending failure status to API
```

---

## References

### Internal Documentation
- [Platform Development Standards](/docs/PLATFORM-DEVELOPMENT-STANDARDS.md)
- [Kubernetes Kustomize Structure](/docs/architecture-templates/kubernetes-kustomize-structure-template.md)
- [Scanner Workflow Troubleshooting](/docs/scanners/troubleshooting.md)

### External Resources
- [Slither Documentation](https://github.com/crytic/slither)
- [Smart Contract Weakness Classification (SWC)](https://swcregistry.io/)
- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [Trail of Bits Best Practices](https://github.com/crytic/building-secure-contracts)

### Related PRs
- **PR #43**: Production-ready scanner status determination
- **PR #81**: Add /check-results endpoint for status verification
- **PR #82**: Update local kustomization to use latest tag strategy

---

**Document Maintainer:** BlockSecOps Team
**Last Review:** 2025-12-05
**Next Review:** 2026-01-05
