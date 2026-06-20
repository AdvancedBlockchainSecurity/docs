# Orchestration Service: REST API Architecture

**Service**: `blocksecops-orchestration`
**Component**: REST API Layer
**Version**: 0.7.4 (Intelligence Layer Integration)
**Date**: November 1, 2025
**Last Updated**: 2026-06-20
**Status**: Production Ready

## Recent Updates

### v0.7.4 - Intelligence Layer Integration (November 1, 2025)

**Added**:
- Intelligence Layer enrichment fields to `FindingDetail` schema
  - Pattern classification (pattern_id, pattern_code, classification_confidence)
  - Fingerprints (code, location, AST, fuzzy hashes)
  - Deduplication (group_id, canonical status, scanner count)
- 397 vulnerability patterns across 4 ecosystems (EVM, Vyper, Solana, Cairo)
- Multi-dimensional fingerprinting for cross-scanner deduplication
- Pattern matching with 100% accuracy (rule-based classification)

**Backward Compatibility**:
- All intelligence fields are optional (return `null` for non-enriched findings)
- No breaking changes to existing API contracts
- Seamless upgrade for existing clients

---

### v0.7.3 - Celery Integration (October 21, 2025)

---

## Overview

The **Orchestration REST API** provides programmatic access to all 12 security scanners in the Apogee platform through a unified HTTP interface. Built with FastAPI integrated with Celery workers, it combines HTTP convenience with distributed execution capabilities.

### Key Features

- **12 Security Scanners**: Slither, Aderyn, Mythril, Wake, Solhint, Semgrep, Echidna, Medusa, Foundry Fuzz, Halmos, 4naly3er, SolidityDefend
- **Database-Backed Queue**: Scans persisted to PostgreSQL with status tracking
- **Celery Integration**: Distributed execution with automatic retries and monitoring
- **Type-Safe API**: Pydantic models for request/response validation
- **Auto Documentation**: OpenAPI/Swagger UI at `/api/v1/docs`
- **Health Probes**: Kubernetes-compatible liveness and readiness endpoints
- **CORS Enabled**: Configured for local development and production

---

## API Architecture (v0.7.1 - Integrated System)

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Client Applications                           │
│                  (Dashboard, CLI, External Services)                  │
└─────────────────────────────┬────────────────────────────────────────┘
                              │
                              │ HTTP/JSON
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    FastAPI Application (4th Container)                │
│                    (Port 8004, Uvicorn Server)                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ API Router Layer                                             │   │
│  │                                                               │   │
│  │  POST /api/v1/scans                                          │   │
│  │    1. Validate scanner_id                                    │   │
│  │    2. Generate scan_id                                       │   │
│  │    3. Insert to database with status='queued'                │   │
│  │    4. Return immediately with scan_id                        │   │
│  │                                                               │   │
│  │  GET /api/v1/scans/{scan_id}                                 │   │
│  │    1. Query database by scan_id                              │   │
│  │    2. Convert ScanModel → ScanResult                         │   │
│  │    3. Return findings from database                          │   │
│  │                                                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
                            │ Async Database Session (asyncpg)
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      PostgreSQL Database                              │
│                    (Single Source of Truth)                           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  scans table:                                                         │
│    - id (UUID, PK)                                                    │
│    - contract_id (UUID, FK → contracts)                              │
│    - user_id (UUID, FK → users)                                      │
│    - status: 'queued' | 'running' | 'completed' | 'failed'           │
│    - started_at, completed_at (timestamps)                           │
│    - vulnerabilities (relationship → findings)                       │
│                                                                       │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
                            │ Sync Database Session (psycopg2)
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│               Celery Beat Scheduler (2nd Container)                   │
│                    (RedBeat with Redis)                               │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Periodic Task: check_stale_scans (runs every 30s)                   │
│    1. SELECT * FROM scans WHERE status='running'                     │
│       AND started_at < NOW() - INTERVAL '600 seconds'                │
│       FOR UPDATE SKIP LOCKED                                         │
│    2. For each stale scan:                                           │
│       - If retry_count < retry_limit: reset to 'queued', increment  │
│         retry_count (NOTE: no re-dispatch — see BSO-SEC-030)        │
│       - If retry_count >= retry_limit: UPDATE status='failed'        │
│                                                                       │
│  Removed (PR #111, 2026-06-20): poll_scan_queue                     │
│    Previously ran every 10s to dispatch queued scans to workers.     │
│    Scan dispatch now happens at scan-creation time via               │
│    tool-integration (KubernetesJobManager).                          │
│                                                                       │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
                            │ Redis Broker (Celery Queue)
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│              Celery Workers (1st Container)                           │
│                (Gevent Pool, Concurrency=100)                         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Handles tasks dispatched by Beat (e.g., check_stale_scans).        │
│                                                                       │
│  Scanner execution is no longer performed in-pod by Celery workers.  │
│  The tool-integration service creates Kubernetes Jobs per scanner    │
│  via KubernetesJobManager at scan-creation time.                     │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘

                 ┌────────────────────────────────────┐
                 │  Flower Monitor (3rd Container)    │
                 │  • Real-time worker monitoring     │
                 │  • Task history and statistics     │
                 │  • Port: 8000 (Flower UI)          │
                 └────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                       Data Flow Summary                               │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  1. User → POST /api/v1/scans (blocksecops-api-service)              │
│     FastAPI writes to database (status='queued')                     │
│     Immediately calls tool-integration for each scanner              │
│                                                                       │
│  2. Tool Integration → KubernetesJobManager                          │
│     Creates one K8s Job per scanner, updates status='running'        │
│                                                                       │
│  3. Scanner Job executes, POSTs results to CALLBACK_URL              │
│     Tool-integration forwards normalized results to API service      │
│     API service updates status='completed'/'failed'                  │
│                                                                       │
│  4. User → GET /api/v1/scans/{scan_id}                               │
│     FastAPI reads from database, returns findings                    │
│                                                                       │
│  Celery Beat (orchestration) role:                                   │
│    • check_stale_scans every 30s — detects stuck 'running' scans    │
│    • No scan dispatch — poll_scan_queue removed (PR #111, 2026-06-20)│
│                                                                       │
│  Benefits:                                                            │
│    ✅ Database persistence (survives pod restarts)                   │
│    ✅ Isolated scanner execution (K8s Jobs, one per scanner)         │
│    ✅ HTTP REST interface (FastAPI)                                  │
│    ✅ Stale-scan detection (check_stale_scans Beat task)             │
│    ✅ Real-time monitoring (Flower dashboard for Celery tasks)       │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

---

## API Endpoints

### Health Endpoints

#### `GET /api/v1/health/live`

Kubernetes liveness probe endpoint.

**Response**:
```json
{
  "status": "alive",
  "service": "blocksecops-orchestration"
}
```

#### `GET /api/v1/health/ready`

Kubernetes readiness probe with registry status checks.

**Response**:
```json
{
  "status": "ready",
  "service": "blocksecops-orchestration",
  "scanners": {
    "total": 11,
    "available": 11
  },
  "parsers": {
    "total": 11
  }
}
```

---

### Scanner Management Endpoints

#### `GET /api/v1/scanners`

List all available scanners with metadata.

**Response Model**: `ScannerListResponse`

**Response Example**:
```json
{
  "total": 11,
  "available": 11,
  "scanners": [
    {
      "scanner_id": "slither",
      "name": "Slither",
      "description": "Static analysis framework for Solidity smart contracts",
      "finding_types": ["VULNERABILITY"],
      "is_available": true,
      "timeout": 300
    },
    {
      "scanner_id": "4naly3er",
      "name": "4naly3er",
      "description": "Gas optimization analyzer for Solidity contracts",
      "finding_types": ["GAS_ANALYSIS"],
      "is_available": true,
      "timeout": 180
    }
  ]
}
```

#### `GET /api/v1/scanners/{scanner_id}`

Get detailed information about a specific scanner.

**Path Parameters**:
- `scanner_id` (string): Scanner identifier (e.g., "slither", "mythril")

**Response Model**: `ScannerInfo`

**Response Example**:
```json
{
  "scanner_id": "slither",
  "name": "Slither",
  "description": "Static analysis framework for Solidity smart contracts",
  "finding_types": ["VULNERABILITY"],
  "is_available": true,
  "timeout": 300
}
```

**Error Responses**:
- `404 Not Found`: Scanner not found

#### `GET /api/v1/scanners/{scanner_id}/availability`

Check if scanner binary is available on the system.

**Response Model**: `ScannerAvailabilityResponse`

**Response Example**:
```json
{
  "scanner_id": "slither",
  "is_available": true,
  "message": "Scanner binary is available"
}
```

---

### Scan Execution Endpoints

#### `POST /api/v1/scans`

Execute a security scanner on a Solidity contract or project.

**Request Model**: `ScanRequest`

**Request Body**:
```json
{
  "scanner_id": "slither",
  "contract_id": "3a6a44e3-8087-45f7-9a3d-4d36479ac98e",
  "user_id": "033f38ff-991e-4ff4-80ed-20687d35340a",
  "contract_path": "/contracts/MyToken.sol",
  "timeout": 300,
  "options": {}
}
```

**Request Fields**:
- `scanner_id` (string, required): ID of scanner to execute
- `contract_id` (UUID, required): UUID of the contract to scan
- `user_id` (UUID, required): UUID of the user requesting the scan
- `contract_path` (string, required): Path to contract/project directory
- `timeout` (integer, optional): Override default timeout in seconds
- `options` (object, optional): Additional scanner-specific options

**Response Model**: `ScanStatusResponse`

**Response** (202 Accepted):
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "scanner_id": "slither",
  "status": "RUNNING",
  "started_at": "2025-10-20T10:30:00Z",
  "duration_seconds": null,
  "findings_count": 0
}
```

**Error Responses**:
- `404 Not Found`: Scanner not found
- `503 Service Unavailable`: Scanner binary not available

**Behavior**:
- Returns immediately with scan ID
- Executes scanner in background task
- Use `GET /api/v1/scans/{scan_id}` to poll for results

#### `GET /api/v1/scans/{scan_id}`

Get complete scan result with findings.

**Path Parameters**:
- `scan_id` (string): Scan execution identifier

**Response Model**: `ScanResult`

**Response Example**:
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "scanner_id": "slither",
  "status": "COMPLETED",
  "started_at": "2025-10-20T10:30:00Z",
  "completed_at": "2025-10-20T10:32:15Z",
  "duration_seconds": 135.5,
  "findings_count": 3,
  "error_message": null,
  "findings": [
    {
      "finding_type": "VULNERABILITY",
      "severity": "HIGH",
      "title": "Reentrancy vulnerability",
      "description": "Potential reentrancy attack in withdraw function",
      "location": "contracts/Bank.sol",
      "line_number": 42,
      "code_snippet": "msg.sender.call{value: amount}(\"\")",
      "recommendation": "Use checks-effects-interactions pattern",
      "metadata": {
        "confidence": "HIGH",
        "impact": "HIGH"
      }
    }
  ]
}
```

**Status Values**:
- `RUNNING`: Scan in progress
- `COMPLETED`: Scan finished successfully
- `FAILED`: Scan encountered an error
- `TIMEOUT`: Scan exceeded timeout

**Error Responses**:
- `404 Not Found`: Scan ID not found

#### `GET /api/v1/scans/{scan_id}/status`

Get scan status without full findings (lightweight endpoint).

**Response Model**: `ScanStatusResponse`

**Response Example**:
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "scanner_id": "slither",
  "status": "RUNNING",
  "started_at": "2025-10-20T10:30:00Z",
  "completed_at": null,
  "duration_seconds": null,
  "findings_count": 0
}
```

#### `GET /api/v1/scans/{scan_id}/findings`

Get only the findings from a completed scan.

**Response Model**: `List[FindingDetail]`

**Response Example**:
```json
[
  {
    "finding_type": "VULNERABILITY",
    "severity": "HIGH",
    "title": "Reentrancy vulnerability",
    "description": "Potential reentrancy attack in withdraw function",
    "location": "contracts/Bank.sol",
    "line_number": 42,
    "code_snippet": "msg.sender.call{value: amount}(\"\")",
    "recommendation": "Use checks-effects-interactions pattern",
    "metadata": {
      "confidence": "HIGH",
      "impact": "HIGH"
    }
  }
]
```

**Error Responses**:
- `404 Not Found`: Scan ID not found
- `409 Conflict`: Scan still running

---

## Data Models

### ScanRequest

```python
class ScanRequest(BaseModel):
    scanner_id: str
    contract_id: UUID
    user_id: UUID
    contract_path: str
    timeout: Optional[int] = None
    options: Optional[Dict[str, Any]] = {}
```

### ScanResult

```python
class ScanResult(BaseModel):
    scan_id: str
    scanner_id: str
    status: str  # RUNNING, COMPLETED, FAILED, TIMEOUT
    started_at: datetime
    completed_at: Optional[datetime] = None
    duration_seconds: Optional[float] = None
    findings_count: int = 0
    error_message: Optional[str] = None
    findings: List[FindingDetail] = []
```

### FindingDetail

```python
class FindingDetail(BaseModel):
    # Core finding fields
    finding_type: str  # VULNERABILITY, CODE_QUALITY, GAS_ANALYSIS, etc.
    severity: str      # CRITICAL, HIGH, MEDIUM, LOW, INFO
    title: str
    description: str
    location: Optional[str] = None
    line_number: Optional[int] = None
    code_snippet: Optional[str] = None
    recommendation: Optional[str] = None

    # Intelligence Layer Fields - Pattern Classification
    pattern_id: Optional[str] = None                   # UUID of matched pattern
    pattern_code: Optional[str] = None                 # e.g., BVD-EVM-REE-001
    classification_confidence: Optional[float] = None  # 0.0-1.0
    classification_method: Optional[str] = None        # rule_based, ml_based, hybrid

    # Intelligence Layer Fields - Fingerprints
    fingerprint_code: Optional[str] = None             # SHA-256 of normalized code
    fingerprint_location: Optional[str] = None         # SHA-256 of file:line:function
    fingerprint_ast: Optional[str] = None              # SHA-256 of AST structure
    fingerprint_location_fuzzy: Optional[str] = None   # Fuzzy hash (±3 lines)

    # Intelligence Layer Fields - Deduplication
    deduplication_group_id: Optional[UUID] = None      # Deduplication group UUID
    is_canonical: Optional[bool] = None                # True if canonical finding
    duplicate_count: Optional[int] = None              # Number of duplicates
    scanner_count: Optional[int] = None                # Number of scanners detected

    metadata: Optional[Dict[str, Any]] = {}
```

**Intelligence Layer Enrichment** (Added November 2025):

Findings now include Intelligence Layer enrichment for enhanced analysis:

- **Pattern Classification**: Standardized vulnerability patterns (397 patterns across 4 ecosystems: EVM, Vyper, Solana, Cairo)
- **Fingerprinting**: Multi-dimensional hashing for deduplication (code, location, AST, fuzzy)
- **Deduplication**: Cross-scanner finding correlation with confidence levels

Intelligence fields return `null` for findings that haven't been enriched (backward compatible).

**Pattern Code Format**: `BVD-{ECOSYSTEM}-{CATEGORY}-{NUMBER}`
- Example: `BVD-EVM-REE-001` (Ethereum Reentrancy)
- Categories: REE (Reentrancy), ACC (Access Control), INT (Integer), GAS (Gas), etc.

### ScannerInfo

```python
class ScannerInfo(BaseModel):
    scanner_id: str
    name: str
    description: str
    finding_types: List[str]
    is_available: bool
    timeout: int
    version: Optional[str] = None
```

---

## Scanner Coverage

All 11 security scanners exposed via REST API:

| Scanner       | Finding Type          | Description                                    | Default Timeout |
|---------------|-----------------------|------------------------------------------------|-----------------|
| slither       | VULNERABILITY         | Static analysis framework for Solidity         | 300s            |
| aderyn        | VULNERABILITY         | Cyfrin Rust-based static analyzer              | 300s            |
| mythril       | VULNERABILITY         | Symbolic execution security scanner            | 600s            |
| wake          | VULNERABILITY         | Python-based static analyzer                   | 300s            |
| solhint       | CODE_QUALITY          | Linter for Solidity best practices             | 180s            |
| semgrep       | VULNERABILITY, CODE_QUALITY | SAST with custom rule support           | 300s            |
| echidna       | FUZZING               | Property-based fuzzing tool                    | 600s            |
| medusa        | FUZZING               | Parallelized fuzzer for Solidity               | 600s            |
| foundry-fuzz  | FUZZING               | Coverage-guided fuzzing with Foundry           | 600s            |
| halmos        | FORMAL_VERIFICATION   | Symbolic testing and formal verification       | 600s            |
| 4naly3er      | GAS_ANALYSIS          | Gas optimization analyzer                      | 180s            |

---

## Usage Examples

### Example 1: List All Scanners

```bash
curl http://localhost:8004/api/v1/scanners
```

**Response**:
```json
{
  "total": 11,
  "available": 11,
  "scanners": [...]
}
```

### Example 2: Execute Slither Scan

```bash
curl -X POST http://localhost:8004/api/v1/scans \
  -H "Content-Type: application/json" \
  -d '{
    "scanner_id": "slither",
    "contract_path": "/contracts/MyToken.sol",
    "timeout": 300
  }'
```

**Response**:
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "scanner_id": "slither",
  "status": "RUNNING",
  "started_at": "2025-10-20T10:30:00Z",
  "findings_count": 0
}
```

### Example 3: Poll Scan Status

```bash
SCAN_ID="550e8400-e29b-41d4-a716-446655440000"
curl http://localhost:8004/api/v1/scans/$SCAN_ID/status
```

**Response (Running)**:
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "scanner_id": "slither",
  "status": "RUNNING",
  "started_at": "2025-10-20T10:30:00Z",
  "completed_at": null,
  "duration_seconds": null,
  "findings_count": 0
}
```

**Response (Completed)**:
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "scanner_id": "slither",
  "status": "COMPLETED",
  "started_at": "2025-10-20T10:30:00Z",
  "completed_at": "2025-10-20T10:32:15Z",
  "duration_seconds": 135.5,
  "findings_count": 3
}
```

### Example 4: Get Full Scan Results

```bash
curl http://localhost:8004/api/v1/scans/$SCAN_ID
```

**Response**:
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "scanner_id": "slither",
  "status": "COMPLETED",
  "findings": [
    {
      "finding_type": "VULNERABILITY",
      "severity": "HIGH",
      "title": "Reentrancy vulnerability",
      ...
    }
  ]
}
```

### Example 5: Get Only Findings

```bash
curl http://localhost:8004/api/v1/scans/$SCAN_ID/findings
```

**Response**:
```json
[
  {
    "finding_type": "VULNERABILITY",
    "severity": "HIGH",
    "title": "Reentrancy vulnerability",
    ...
  }
]
```

---

## Client Integration

### Python Client Example

```python
import requests
import time

API_BASE = "http://localhost:8004/api/v1"

def execute_scan(scanner_id: str, contract_path: str):
    """Execute a scan and wait for results."""

    # Start scan
    response = requests.post(f"{API_BASE}/scans", json={
        "scanner_id": scanner_id,
        "contract_path": contract_path
    })
    response.raise_for_status()

    scan_data = response.json()
    scan_id = scan_data["scan_id"]
    print(f"Scan started: {scan_id}")

    # Poll for completion
    while True:
        status_response = requests.get(f"{API_BASE}/scans/{scan_id}/status")
        status_response.raise_for_status()
        status = status_response.json()

        if status["status"] in ["COMPLETED", "FAILED", "TIMEOUT"]:
            break

        print(f"Status: {status['status']}")
        time.sleep(5)

    # Get results
    result_response = requests.get(f"{API_BASE}/scans/{scan_id}")
    result_response.raise_for_status()

    return result_response.json()

# Usage
result = execute_scan("slither", "/contracts/MyToken.sol")
print(f"Found {result['findings_count']} issues")
```

### TypeScript/JavaScript Client Example

```typescript
interface ScanRequest {
  scanner_id: string;
  contract_path: string;
  timeout?: number;
}

interface ScanResult {
  scan_id: string;
  scanner_id: string;
  status: string;
  findings_count: number;
  findings: Finding[];
}

async function executeScan(request: ScanRequest): Promise<ScanResult> {
  const API_BASE = "http://localhost:8004/api/v1";

  // Start scan
  const startResponse = await fetch(`${API_BASE}/scans`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request),
  });

  const { scan_id } = await startResponse.json();
  console.log(`Scan started: ${scan_id}`);

  // Poll for completion
  while (true) {
    const statusResponse = await fetch(`${API_BASE}/scans/${scan_id}/status`);
    const status = await statusResponse.json();

    if (["COMPLETED", "FAILED", "TIMEOUT"].includes(status.status)) {
      break;
    }

    console.log(`Status: ${status.status}`);
    await new Promise(resolve => setTimeout(resolve, 5000));
  }

  // Get results
  const resultResponse = await fetch(`${API_BASE}/scans/${scan_id}`);
  return resultResponse.json();
}

// Usage
const result = await executeScan({
  scanner_id: "slither",
  contract_path: "/contracts/MyToken.sol"
});
console.log(`Found ${result.findings_count} issues`);
```

---

## OpenAPI Documentation

### Interactive Documentation

Access auto-generated API documentation at:

- **Swagger UI**: `http://localhost:8004/api/v1/docs`
- **ReDoc**: `http://localhost:8004/api/v1/redoc`
- **OpenAPI JSON**: `http://localhost:8004/api/v1/openapi.json`

### Features

- **Try It Out**: Execute API calls directly from browser
- **Request/Response Examples**: See all data models
- **Authentication**: (Future) OAuth2/JWT flows
- **Schema Download**: Export OpenAPI spec for codegen

---

## Deployment Configuration

### Docker Configuration

**Dockerfile CMD**:
```dockerfile
CMD ["uvicorn", "blocksecops_orchestration.api.main:app", "--host", "0.0.0.0", "--port", "8004"]
```

**Health Check**:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8004/api/v1/health/live || exit 1
```

### Kubernetes Configuration

**Service** (k8s/base/orchestration/service.yaml):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: orchestration
spec:
  selector:
    app: orchestration
  ports:
  - name: http
    port: 8004
    targetPort: 8004
```

**Deployment Probes**:
```yaml
livenessProbe:
  httpGet:
    path: /api/v1/health/live
    port: 8004
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /api/v1/health/ready
    port: 8004
  initialDelaySeconds: 10
  periodSeconds: 5
```

**Resource Limits**:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

---

## Performance Characteristics

### API Response Times

| Endpoint                        | Avg Response Time |
|---------------------------------|-------------------|
| GET /api/v1/health/live         | < 5ms             |
| GET /api/v1/health/ready        | < 10ms            |
| GET /api/v1/scanners            | < 20ms            |
| POST /api/v1/scans              | < 50ms (async)    |
| GET /api/v1/scans/{id}/status   | < 5ms             |
| GET /api/v1/scans/{id}          | < 20ms            |

### Scanner Execution Times

| Scanner       | Typical Duration | Max Timeout |
|---------------|------------------|-------------|
| slither       | 10-60s           | 300s        |
| aderyn        | 15-90s           | 300s        |
| mythril       | 60-300s          | 600s        |
| wake          | 20-120s          | 300s        |
| solhint       | 5-30s            | 180s        |
| semgrep       | 10-60s           | 300s        |
| echidna       | 120-600s         | 600s        |
| medusa        | 120-600s         | 600s        |
| foundry-fuzz  | 60-300s          | 600s        |
| halmos        | 180-600s         | 600s        |
| 4naly3er      | 10-60s           | 180s        |

---

## Security Considerations

### Authentication & Authorization

**Current (Phase 5)**: No authentication
**Future (Phase 6)**:
- JWT-based authentication
- API key support for external services
- Role-based access control (RBAC)

### Rate Limiting

**Current**: None
**Future**:
- Per-IP rate limits
- Per-user quotas
- Scanner-specific limits

### Input Validation

- **Pydantic Models**: All inputs validated by type-safe schemas
- **Path Traversal**: Contract paths validated (future)
- **Scanner ID Whitelist**: Only registered scanners allowed

### CORS Configuration

**Allowed Origins**:
- `http://localhost:3000` (Dashboard development)
- `http://127.0.0.1:3000` (Dashboard alternative)
- `http://localhost:8004` (API self-reference)
- `http://127.0.0.1:8004` (API alternative)

**Production**: Will be restricted to platform domains only

---

## Architecture Evolution

###  v0.6.3 → v0.7.0: FastAPI Introduction

**Previous Architecture** (v0.6.3):
- 3 containers: Celery worker, Beat scheduler, Flower monitor
- Database queue polling for scan execution
- No HTTP API for external integration
- CMD: `python -m blocksecops_orchestration.workers.scan_worker`

**New Architecture** (v0.7.0):
- FastAPI REST server with background tasks
- In-memory scan storage (non-persistent)
- HTTP endpoints for scan execution
- OpenAPI documentation
- CMD: `uvicorn blocksecops_orchestration.api.main:app --host 0.0.0.0 --port 8004`

**Limitations**:
- ❌ No integration with existing Celery infrastructure
- ❌ Scans lost on pod restart (in-memory only)
- ❌ No distributed execution capabilities
- ❌ Missing automatic retry logic

### v0.7.0 → v0.7.1: Celery Integration

**New Architecture** (v0.7.1):
- 4 containers: Worker, Beat, Flower, **FastAPI** (new)
- FastAPI writes scans to database with status='queued'
- Celery Beat polled database every 10s via `poll_scan_queue` and dispatched to workers
- Celery workers executed scanners as subprocesses and updated the database
- FastAPI read results from database

**Changes from v0.7.0**:
1. Added `contract_id` and `user_id` to `ScanRequest` schema
2. Replaced in-memory dict with database inserts/queries
3. Removed FastAPI BackgroundTasks execution
4. Added 4th container to Kubernetes deployment
5. Added async database session dependency

**Note:** This architecture was superseded when scanner execution moved to Kubernetes Jobs managed by the tool-integration service. See the removal note below.

### v0.7.1 → current: poll_scan_queue Removed (PR #111, 2026-06-20)

The `poll_scan_queue` Celery beat task has been removed from `blocksecops-orchestration`. This task was the mechanism by which the orchestration service discovered queued scans and dispatched in-pod scanner subprocesses.

**Current dispatch path:**
- The API service calls the tool-integration service directly at scan-creation time (HTTP POST per scanner).
- The tool-integration KubernetesJobManager (`blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py`) creates one Kubernetes Job per scanner per scan.
- Scanner containers run in isolation and POST results back to tool-integration via `CALLBACK_URL`.
- The orchestration Celery Beat retains only `check_stale_scans` (every 30s) for detecting stuck `running` scans.

**Known gap (BSO-SEC-030):** Scans reset to `queued` by `check_stale_scans` (after a stale-timeout retry) are not automatically re-dispatched. The admin retry endpoint similarly resets status without triggering a new Job. This gap is tracked as BSO-SEC-030.

### v0.7.1 → v0.7.3: Bug Fixes and Stability

**Changes in v0.7.2**:
- Fixed REDIS_URL environment variable configuration
- Updated deployment-patch.yaml to include REDIS_URL for orchestration-api container
- Resolved ValidationError preventing FastAPI from starting

**Changes in v0.7.3**:
- Fixed `ScannerRegistry.get_all_scanner_ids()` method name errors
- Updated scanners.py:84 to use correct method name
- Updated health.py:43,47 to use correct method name
- All API endpoints now functional (scanners list, health checks, scan submission)
- Foreign key constraints enforced (validates contract_id existence)

**Deployment Status** (v0.7.3):
- ✅ All 4/4 containers running
- ✅ 12 scanners available
- ✅ Health probes passing
- ✅ API endpoints validated
- ✅ Database integration working

### Migration Guide (v0.6.3 → v0.7.3)

1. **Update Health Check Endpoints**:
   - Old: `/health`
   - New: `/api/v1/health/live` or `/api/v1/health/ready`

2. **Update Kubernetes Manifests**:
   ```yaml
   # Add 4th container to deployment
   - name: orchestration-api
     image: blocksecops-orchestration:0.7.3
     command: ["uvicorn", "blocksecops_orchestration.api.main:app", "--host", "0.0.0.0", "--port", "8004"]
     ports:
     - name: http
       containerPort: 8004

   # Add API port to service
   spec:
     ports:
     - port: 8004
       targetPort: http
       protocol: TCP
       name: http-api
   ```

3. **Update Client Integration**:
   ```python
   # Old: Direct Celery task invocation (not possible externally)
   # N/A - external clients couldn't trigger scans

   # New: HTTP POST to create scan
   import requests
   response = requests.post("http://orchestration:8004/api/v1/scans", json={
       "scanner_id": "slither",
       "contract_id": "uuid-here",
       "user_id": "uuid-here",
       "contract_path": "/contracts/test.sol"
   })
   scan_id = response.json()["scan_id"]

   # Poll for results
   result = requests.get(f"http://orchestration:8004/api/v1/scans/{scan_id}")
   ```

4. **Update Monitoring**:
   - Keep Flower for Celery worker monitoring
   - Add API endpoint monitoring at `/api/v1/health/ready`
   - Monitor both systems for complete visibility

---

## Future Enhancements (Phase 6)

### Database Persistence

Replace in-memory scan storage with PostgreSQL:
- Persistent scan history
- Result pagination
- Advanced filtering and search
- Scan analytics and trends

### Advanced Features

- **Batch Scanning**: Submit multiple contracts in one request
- **Scan Comparison**: Compare results across different versions
- **Custom Scanner Configs**: Per-request scanner options
- **Webhooks**: Callback URLs for scan completion
- **Streaming Results**: Server-sent events for real-time updates

### Performance Optimizations

- **Caching**: Redis cache for scanner metadata
- **Connection Pooling**: Optimize database connections
- **Result Compression**: Gzip compression for large payloads
- **CDN Integration**: Static asset delivery

---

## References

### Related Documentation

- [Orchestration Service Deployment](../deployment/orchestration-service-deployment.md)
- [Result Routing Architecture](orchestration-result-routing.md)
- [Phase 5 Implementation](../../TaskDocs-Apogee/blocksecops/06-phase-5-rest-api/PHASE-5-REST-API-COMPLETE.md)

### Code Files

- **Main API**: `src/blocksecops_orchestration/api/main.py`
- **Health Routes**: `src/blocksecops_orchestration/api/routes/health.py`
- **Scanner Routes**: `src/blocksecops_orchestration/api/routes/scanners.py`
- **Scan Routes**: `src/blocksecops_orchestration/api/routes/scans.py`
- **Pydantic Schemas**: `src/blocksecops_orchestration/api/schemas/`

### External Resources

- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **OpenAPI Specification**: https://swagger.io/specification/
- **Pydantic**: https://docs.pydantic.dev/

---

**Last Updated**: October 21, 2025
**Version**: 0.7.3 (Celery Integration - Production)
**Status**: Production Ready - Fully Tested
