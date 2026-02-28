# Scanner Workflow and Troubleshooting Guide

**Version:** 1.1.0
**Last Updated:** December 9, 2025
**Status:** Active
**Purpose:** Comprehensive reference for scanner workflow architecture, data flow, and troubleshooting

## Table of Contents

1. [Overview](#overview)
2. [Complete Scanner Workflow](#complete-scanner-workflow)
3. [Scanner Identification Flow](#scanner-identification-flow)
4. [Data Flow Diagram](#data-flow-diagram)
5. [Critical Integration Points](#critical-integration-points)
6. [Common Issues and Solutions](#common-issues-and-solutions)
7. [Troubleshooting Checklist](#troubleshooting-checklist)
8. [Debugging Tools and Techniques](#debugging-tools-and-techniques)

---

## Overview

The Apogee Platform scanner workflow involves **five major services** working together to execute vulnerability scans. Understanding the complete data flow is critical for troubleshooting scanner identification, result submission, and cross-scanner isolation issues.

### Key Services

1. **Dashboard** (React/Next.js) - User interface for scan initiation
2. **API Service** (FastAPI) - REST API for scan management
3. **Tool Integration Service** (FastAPI) - Kubernetes job orchestration and result collection
4. **Scanner Jobs** (Kubernetes Jobs) - Containerized scanner execution
5. **PostgreSQL Database** - Scan and vulnerability data persistence

---

## Complete Scanner Workflow

### Phase 1: Scan Initiation (Dashboard → API)

**Location:** `blocksecops-dashboard/src/components/ScanModal.tsx`

```typescript
// User selects scanners in UI
const selectedScanners = ["wake", "slither"];

// POST to API
const response = await fetch("http://127.0.0.1:8000/api/v1/scans", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    contract_id: "uuid-here",
    scanner_ids: selectedScanners,  // ✅ Scanner IDs sent
    scan_type: "full"
  })
});
```

**What Should Happen:**
- ✅ Dashboard sends `scanner_ids` array in POST body
- ✅ API receives `scanner_ids` parameter
- ✅ Database `scans` table stores `scanners_used` field

**File Reference:** `blocksecops-dashboard/src/components/ScanModal.tsx:120-145`

---

### Phase 2: Scan Creation (API Service)

**Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py`

```python
@router.post("/", response_model=ScanResponse)
async def create_scan(
    scan_request: ScanCreate,  # Contains scanner_ids
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Validate scanner_ids
    scanner_ids = scan_request.scanner_ids or []

    # Create scan record with scanners_used field
    scan = Scan(
        id=str(uuid4()),
        contract_id=scan_request.contract_id,
        user_id=current_user.id,
        scanners_used=scanner_ids,  # ✅ Store scanner IDs
        status="pending"
    )
    db.add(scan)
    db.commit()

    # Forward to tool-integration service
    await trigger_tool_integration(scan.id, scanner_ids)
```

**What Should Happen:**
- ✅ API validates `scanner_ids` from request
- ✅ API creates `scans` record with `scanners_used` populated
- ✅ API forwards `scanner_ids` to tool-integration service

**File Reference:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:195-230`

---

### Phase 3: Job Orchestration (Tool Integration Service)

**Location:** `blocksecops-tool-integration/src/main.py`

```python
@app.post("/api/v1/trigger-scan/{scan_id}")
async def trigger_scan(
    scan_id: str,
    request: Request,
    scanner: str = "slither"  # ⚠️ Default fallback (should be required)
):
    """
    Creates Kubernetes Job for specified scanner.
    """
    data = await request.json()
    scanner_id = data.get("scanner", scanner)  # Get scanner from request

    # Create Kubernetes Job
    job_manager = KubernetesJobManager()
    job_name = f"scan-{scanner_id}-{scan_id[:8]}"

    job_spec = create_job_spec(
        name=job_name,
        scanner=scanner_id,
        scan_id=scan_id,
        callback_url=f"http://tool-integration:8005/api/v1/scans/{scan_id}/results"
    )

    job_manager.create_job(job_spec)
```

**What Should Happen:**
- ✅ Tool-integration receives `scanner` parameter
- ✅ Creates Kubernetes Job with correct scanner image
- ✅ Passes `CALLBACK_URL` and `SCAN_ID` to scanner container

**File Reference:** `blocksecops-tool-integration/src/main.py:95-145`

---

### Phase 4: Scanner Execution (Scanner Job)

**Location:** `blocksecops-tool-integration/scanner-images/wake/wake-scan`

```bash
#!/bin/bash
set -euo pipefail

# Environment variables from Kubernetes Job
CONTRACTS_DIR="${CONTRACTS_DIR:-/work}"
OUTPUT_FILE="${OUTPUT_FILE:-/output/results.json}"
CALLBACK_URL="${CALLBACK_URL:-}"
SCAN_ID="${SCAN_ID:-}"

# Validate required vars
if [ -z "$CALLBACK_URL" ] || [ -z "$SCAN_ID" ]; then
    echo "ERROR: CALLBACK_URL and SCAN_ID required"
    exit 1
fi

# Run scanner
wake detect all > wake-output.txt

# Convert to JSON format
cat > "$OUTPUT_FILE" <<EOF
{
  "scanner": "wake",           # ✅ Scanner identification
  "version": "$(wake --version)",
  "status": "completed",
  "vulnerabilities": [
    {
      "id": "wake-reentrancy",
      "title": "Reentrancy Vulnerability",
      "severity": "high",
      "locations": [{"file": "Contract.sol", "line": 42}]
    }
  ]
}
EOF

# POST results to callback URL
curl -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -d @"$OUTPUT_FILE"
```

**What Should Happen:**
- ✅ Scanner executes vulnerability detection
- ✅ Scanner outputs JSON with `"scanner": "wake"` field
- ✅ Scanner POSTs results to `CALLBACK_URL`

**File References:**
- Wake: `blocksecops-tool-integration/scanner-images/wake/wake-scan:1-197`
- Slither: `blocksecops-tool-integration/scanner-images/slither/run-slither.sh:1-250`

---

### Phase 5: Result Collection (Tool Integration Service)

**Location:** `blocksecops-tool-integration/src/main.py`

```python
@app.post("/api/v1/scans/{scan_id}/results")
async def collect_scan_results(scan_id: str, request: Request):
    """
    Receives scan results from scanner Jobs.
    This endpoint is called by scanner containers to POST results.
    """
    results_json = await request.json()

    # ✅ CRITICAL: Read scanner type from JSON payload
    scanner_type = results_json.get("scanner", "unknown")

    if scanner_type == "unknown":
        logger.warning(f"Scanner type not specified for scan {scan_id}")

    logger.info(f"Processing results from scanner: {scanner_type}")

    # Process based on scanner type
    if scanner_type == "slither":
        # Parse Slither-specific format
        vulnerabilities = parse_slither_results(results_json)
    else:
        # Parse standardized format (wake, aderyn, etc.)
        vulnerabilities = results_json.get("vulnerabilities", [])

    # Format for API service
    vulnerability_results = []
    for vuln in vulnerabilities:
        vulnerability_results.append({
            "vulnerability_type": vuln.get("id"),
            "severity": vuln.get("severity"),
            "title": vuln.get("title"),
            "description": vuln.get("description"),
            "scanner_id": scanner_type,     # ✅ Use dynamic scanner type
            "scanner_name": scanner_type,   # ✅ Use dynamic scanner type
        })

    # Forward to API service
    scan_results = {
        "scanner": scanner_type,  # ✅ Pass correct scanner
        "status": "completed",
        "vulnerabilities": vulnerability_results
    }

    await post_to_api_service(scan_id, scan_results)
```

**What Should Happen:**
- ✅ Tool-integration reads `"scanner"` field from JSON
- ✅ Tool-integration uses scanner type dynamically (NOT hardcoded)
- ✅ Tool-integration forwards results with correct scanner identification

**File Reference:** `blocksecops-tool-integration/src/main.py:225-404`

---

### Phase 6: Result Storage (API Service)

**Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py`

```python
@router.post("/{scan_id}/results", response_model=ScanResultsResponse)
async def receive_scan_results(
    scan_id: str,
    results: ScanResults,
    db: Session = Depends(get_db)
):
    """
    Receives results from tool-integration service.
    """
    scan = db.query(Scan).filter(Scan.id == scan_id).first()

    # Update scanners_used array
    if scan.scanners_used is None:
        scan.scanners_used = []

    if results.scanner not in scan.scanners_used:
        scan.scanners_used.append(results.scanner)  # ✅ Track scanner

    # Save vulnerabilities with scanner_id
    for vuln_data in results.vulnerabilities:
        vulnerability = Vulnerability(
            id=str(uuid4()),
            scan_id=scan_id,
            scanner_id=vuln_data.scanner_id,  # ✅ Scanner identification
            vulnerability_type=vuln_data.vulnerability_type,
            severity=vuln_data.severity,
            title=vuln_data.title,
            # ... other fields
        )
        db.add(vulnerability)

    db.commit()
```

**What Should Happen:**
- ✅ API receives `scanner` field from tool-integration
- ✅ API updates `scans.scanners_used` array
- ✅ API saves vulnerabilities with correct `scanner_id`

**File Reference:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:485-580`

---

## Scanner Identification Flow

### Critical Data Points

| Stage | Location | Field | Expected Value |
|-------|----------|-------|----------------|
| 1. User Selection | Dashboard | `scanner_ids` | `["wake"]` |
| 2. Scan Creation | API Database | `scans.scanners_used` | `{wake}` (PostgreSQL array) |
| 3. Job Trigger | Tool-Integration | `scanner` param | `"wake"` |
| 4. Job Spec | Kubernetes Job | `labels.scanner` | `"wake"` |
| 5. Scanner Output | Scanner Container | `"scanner"` JSON field | `"wake"` |
| 6. Result Collection | Tool-Integration | `scanner_type` variable | `"wake"` |
| 7. Result Forward | Tool-Integration → API | `"scanner"` JSON field | `"wake"` |
| 8. Vulnerability Storage | API Database | `vulnerabilities.scanner_id` | `"wake"` |

### Verification Query

```sql
-- Check complete scanner identification chain
SELECT
    s.id AS scan_id,
    s.scanners_used AS scanners_selected,
    v.scanner_id AS vuln_scanner,
    COUNT(*) AS vulnerability_count
FROM scans s
LEFT JOIN vulnerabilities v ON s.id = v.scan_id
WHERE s.id = 'your-scan-id-here'
GROUP BY s.id, s.scanners_used, v.scanner_id;
```

**Expected Result:**
```
scan_id              | scanners_selected | vuln_scanner | vulnerability_count
---------------------|-------------------|--------------|--------------------
d17cc6fb-29e5-...    | {wake}            | wake         | 5
```

**❌ Bug Symptom (Scanner Contamination):**
```
scan_id              | scanners_selected | vuln_scanner | vulnerability_count
---------------------|-------------------|--------------|--------------------
d17cc6fb-29e5-...    | {slither}         | slither      | 5
                     # ^^^ WRONG! Should be "wake"
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SCANNER WORKFLOW DIAGRAM                        │
└─────────────────────────────────────────────────────────────────────────┘

  ┌─────────────┐
  │  Dashboard  │ User selects: scanner_ids = ["wake"]
  └──────┬──────┘
         │ POST /api/v1/scans
         │ Body: {"scanner_ids": ["wake"]}
         ▼
  ┌─────────────┐
  │ API Service │ Creates scan record
  └──────┬──────┘ scanners_used = ["wake"]
         │
         │ POST /api/v1/trigger-scan/{scan_id}
         │ Body: {"scanner": "wake"}
         ▼
  ┌──────────────────┐
  │ Tool Integration │ Creates Kubernetes Job
  └────────┬─────────┘ Image: scanner-wake:0.2.1
           │           Env: CALLBACK_URL, SCAN_ID
           │
           │ kubectl create job
           ▼
  ┌─────────────────────────────┐
  │    Kubernetes Job           │
  │  scan-wake-d17cc6fb-29e5    │
  └──────────────┬──────────────┘
                 │ Executes wake-scan script
                 │ Generates results.json
                 ▼
  {
    "scanner": "wake",  ◄─── CRITICAL FIELD
    "vulnerabilities": [...]
  }
                 │
                 │ curl POST $CALLBACK_URL
                 │ -d @results.json
                 ▼
  ┌──────────────────┐
  │ Tool Integration │ Receives results
  └────────┬─────────┘ Reads: scanner_type = "wake"
           │
           │ POST /api/v1/scans/{scan_id}/results
           │ Body: {"scanner": "wake", "vulnerabilities": [...]}
           ▼
  ┌─────────────┐
  │ API Service │ Saves to database
  └──────┬──────┘ scanner_id = "wake"
         │
         ▼
  ┌─────────────────────┐
  │ PostgreSQL Database │
  └─────────────────────┘

  scans:
    scanners_used: {wake}

  vulnerabilities:
    scanner_id: wake
```

---

## Critical Integration Points

### Integration Point 1: Dashboard → API

**File:** `blocksecops-dashboard/src/components/ScanModal.tsx:120-145`

**Potential Issues:**
- ❌ Dashboard not sending `scanner_ids` parameter
- ❌ Scanner selection state not updating
- ❌ Auto-loading from localStorage overriding user selection

**Debugging:**
```bash
# Check browser network tab
# Look for POST /api/v1/scans request
# Verify body contains: {"scanner_ids": ["wake"]}

# Or check API logs
kubectl logs -n api-service-local deployment/api-service | grep "scanner_ids"
```

---

### Integration Point 2: API → Tool Integration

**File:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:195-230`

**Potential Issues:**
- ❌ API not reading `scanner_ids` from request
- ❌ API not storing `scanners_used` in database
- ❌ API not forwarding `scanner` parameter to tool-integration

**Debugging:**
```sql
-- Check if scanners_used is populated
SELECT id, scanners_used, status FROM scans ORDER BY created_at DESC LIMIT 5;
```

---

### Integration Point 3: Tool Integration → Scanner Jobs

**File:** `blocksecops-tool-integration/src/main.py:95-145`

**Potential Issues:**
- ❌ Tool-integration using default `scanner = "slither"` fallback
- ❌ Job spec not using correct scanner image
- ❌ Environment variables not passed to scanner container

**Debugging:**
```bash
# Check created jobs
kubectl get jobs -n tool-integration-local

# Check job labels
kubectl describe job scan-wake-<scan-id> -n tool-integration-local | grep scanner

# Check container image
kubectl get job scan-wake-<scan-id> -n tool-integration-local -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

### Integration Point 4: Scanner → Tool Integration (Result Submission)

**File:** `blocksecops-tool-integration/scanner-images/wake/wake-scan:167-185`

**Potential Issues:**
- ❌ Scanner not POSTing results to callback URL
- ❌ Scanner output missing `"scanner"` field in JSON
- ❌ CALLBACK_URL or SCAN_ID environment variables not set

**Debugging:**
```bash
# Check scanner job logs
kubectl logs -n tool-integration-local job/scan-wake-<scan-id>

# Look for these lines:
# ✅ "Callback URL: http://tool-integration..."
# ✅ "Posting results to..."
# ✅ "✓ Results posted successfully (HTTP 200)"

# If missing, scanner didn't POST results
```

---

### Integration Point 5: Tool Integration Result Processing

**File:** `blocksecops-tool-integration/src/main.py:225-404`

**Potential Issues:**
- ❌ **CRITICAL**: Hardcoded `scanner_type = "slither"`
- ❌ Not reading `"scanner"` field from JSON
- ❌ Using hardcoded scanner in vulnerability mapping

**Debugging:**
```bash
# Check tool-integration logs
kubectl logs -n tool-integration-local deployment/tool-integration | grep "Processing results from scanner"

# Should see:
# ✅ "Processing results from scanner: wake"

# NOT:
# ❌ "Processing results from scanner: slither"  (when Wake scan ran)
```

---

### Integration Point 6: API Result Storage

**File:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:485-580`

**Potential Issues:**
- ❌ API overwriting `scanners_used` instead of appending
- ❌ API not validating scanner field
- ❌ Vulnerabilities saved without `scanner_id`

**Debugging:**
```sql
-- Check vulnerabilities have scanner_id
SELECT scan_id, scanner_id, COUNT(*)
FROM vulnerabilities
GROUP BY scan_id, scanner_id;

-- Check scanners_used matches vulnerability scanner_ids
SELECT
    s.id,
    s.scanners_used,
    array_agg(DISTINCT v.scanner_id) AS actual_scanners
FROM scans s
LEFT JOIN vulnerabilities v ON s.id = v.scan_id
GROUP BY s.id, s.scanners_used;
```

---

## Common Issues and Solutions

### Issue 1: Scanner Contamination (All Results Labeled "slither")

**Symptom:**
- User selects "wake" scanner
- Job runs successfully (scanner-wake image used)
- Database shows `scanners_used: {slither}`
- Vulnerabilities have `scanner_id: slither`

**Root Cause:**
Tool-integration service hardcodes `scanner_type = "slither"` instead of reading from JSON.

**File:** `blocksecops-tool-integration/src/main.py:249`

**Fix:**
```python
# BEFORE (Bug):
scanner_type = "slither"  # Default, can detect from JSON structure

# AFTER (Fix):
scanner_type = results_json.get("scanner", "unknown")
```

**Verification:**
```bash
# After fix, check tool-integration logs
kubectl logs -n tool-integration-local deployment/tool-integration | grep "Processing results"

# Should show correct scanner:
# ✅ "Processing results from scanner: wake"
```

---

### Issue 2: Scanner Not Submitting Results

**Symptom:**
- Scanner job completes successfully
- `scanners_used` field is empty/NULL
- No vulnerabilities saved

**Root Cause:**
Scanner wrapper script not POSTing results to callback URL.

**Debugging:**
```bash
# Check scanner job logs
kubectl logs -n tool-integration-local job/scan-wake-<scan-id>

# Look for callback URL and POST messages
# If missing, scanner is not submitting results
```

**Fix:**
Update scanner wrapper script to include result submission:

```bash
# POST results to callback URL
curl -X POST "$CALLBACK_URL" \
  -H "Content-Type: application/json" \
  -d @"$OUTPUT_FILE"
```

**File Example:** `blocksecops-tool-integration/scanner-images/wake/wake-scan:167-185`

---

### Issue 3: Wrong Scanner Image Used

**Symptom:**
- User selects "wake"
- Slither image executes instead

**Root Cause:**
- ConfigMap version reference outdated
- Job spec using wrong image tag

**Debugging:**
```bash
# Check scanner-versions ConfigMap
kubectl get configmap scanner-versions -n tool-integration-local -o yaml | grep SCANNER_IMAGE_WAKE

# Check actual job image
kubectl get job scan-wake-<scan-id> -n tool-integration-local -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Fix:**
Update ConfigMap with correct version:

```yaml
# k8s/base/scanner-versions-configmap.yaml
data:
  SCANNER_IMAGE_WAKE: "scanner-wake:0.2.1"  # ← Update version
```

Apply changes:
```bash
kubectl apply -k k8s/overlays/local/
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

---

### Issue 4: Cross-Scanner Vulnerability Leakage

**Symptom:**
- Scan A uses Wake, finds 5 vulnerabilities
- Scan B uses Slither on different contract
- Scan B shows Wake's 5 vulnerabilities too

**Root Cause:**
API service queries vulnerabilities without filtering by `scanner_id`.

**File:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scan_results.py:77-120`

**Fix:**
```python
# Query vulnerabilities with scanner isolation
vulnerabilities = db.query(Vulnerability).filter(
    Vulnerability.scan_id == scan_id,
    Vulnerability.scanner_id.in_(scan.scanners_used)  # ✅ Filter by scanners used
).all()
```

---

### Issue 5: Multiple Scanners Race Condition

**Symptom:**
- User selects both "wake" and "slither"
- Only one scanner's results appear
- Scan status updates incorrectly

**Root Cause:**
API service overwrites `scanners_used` array and status instead of accumulating.

**Fix:**
```python
# Accumulate scanners instead of overwriting
if results.scanner not in scan.scanners_used:
    scan.scanners_used.append(results.scanner)

# Only mark complete when ALL expected scanners finish
expected_scanners = set(scan.scanners_used)
completed_scanners = set([v.scanner_id for v in scan.vulnerabilities])

if expected_scanners == completed_scanners:
    scan.status = "completed"
```

---

### Issue 6: Parser Confidence Field Type Mismatch (HTTP 422 Validation Error)

**Symptom:**
- Scanner job completes successfully
- Scanner container POSTs results to tool-integration
- Tool-integration receives results and processes them
- API returns HTTP 422 Unprocessable Entity
- Scan remains stuck in "processing" or "failed" state

**Root Cause:**
Parser converts confidence field to a string (e.g., `"high"`, `"low"`) instead of a float (e.g., `0.9`, `0.5`) as expected by the API schema.

**Example Error:**
```json
{
  "detail": [
    {
      "type": "float_parsing",
      "loc": ["body", "vulnerabilities", 0, "confidence"],
      "msg": "Input should be a valid number, unable to parse string as a number",
      "input": "high"
    }
  ]
}
```

**Files Affected:**
- Parser file: `blocksecops-tool-integration/src/parsers/<scanner>_parser.py`
- API schema: `blocksecops-api-service/src/presentation/schemas/vulnerability.py`

**Fix:**
Update the parser to convert string confidence values to floats:

```python
def _map_confidence(self, confidence_str: str) -> float:
    """Convert string confidence to float."""
    confidence_map = {
        "high": 0.9,
        "medium": 0.7,
        "low": 0.5,
    }
    if isinstance(confidence_str, (int, float)):
        return float(confidence_str)
    return confidence_map.get(str(confidence_str).lower(), 0.5)
```

**Verification:**
```bash
# Check tool-integration logs for 422 errors
kubectl logs -n tool-integration-local deployment/tool-integration | grep "422"

# After fix, verify successful posting
kubectl logs -n tool-integration-local deployment/tool-integration | grep "HTTP/1.1 200 OK"
```

**Scanners Known to Have This Issue:**
- Aderyn (fixed December 2025) - confidence field was string

**Related Documentation:**
- Changelog: `/Users/pwner/Git/ABS/docs/changelogs/SCANNER-VALIDATION-ADERYN-SOLIDITYDEFEND-2025-12-09.md`

---

### Issue 7: Scans Marked as "Failed" Despite Successful Results (Slither Exit 255)

**Symptom:**
- Scanner job completes successfully
- Results are posted to database
- Scan shows as "completed" in Kubernetes dashboard
- Same scan shows as "failed" in database/UI
- Slither scanner specifically affected

**Root Cause:**
Slither exits with code 255 when it finds vulnerabilities (normal behavior). Kubernetes marks the Job as "Failed" when container exits with non-zero code. The result collector was treating all failed Jobs the same way, sending "failed" status to API even though results were successfully posted.

**Technical Details:**
1. Slither finds vulnerabilities → exits with code 255
2. Scanner wrapper detects exit 255, but results already posted → exits with 0
3. Kubernetes sees exit 0 → marks Job as "Complete"
4. Result collector polls every 60s, sees "Failed" Job
5. **Bug**: Result collector sends "failed" status without checking if results exist

**Files Affected:**
- `blocksecops-tool-integration/src/scanners/result_collector.py:67-98`
- `blocksecops-tool-integration/src/scanners/result_collector.py:176-214`
- `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:139-187`

**Production Fix (tool-integration:0.2.4 + api-service:0.2.3):**

Added database verification before marking scans as failed:

```python
# result_collector.py - Modified failed job handling
elif status.failed and status.failed >= (job.spec.backoff_limit or 0):
    logger.info(f"Job {job_name} marked as failed by Kubernetes")

    # Check if scan has results in the database
    has_results = await self._check_scan_has_results(scan_id)

    if has_results:
        logger.info(
            f"Scan {scan_id} has results in database despite Job failure. "
            f"Scanner successfully posted results before container exit. "
            f"Skipping failure status update."
        )
    else:
        logger.warning(
            f"Scan {scan_id} has no results in database. "
            f"This is a true failure - scanner did not post results. "
            f"Sending failure status to API."
        )
        await self._process_failed_job(scan_id, scanner, job_name)
```

**New API Endpoint (scans.py:139-187):**

```python
@router.get("/{scan_id}/check-results")
async def check_scan_has_results(scan_id: UUID, db: AsyncSession = Depends(get_db)):
    """Check if a scan has results/vulnerabilities in the database."""

    # Count vulnerabilities for this scan
    count_query = select(func.count()).select_from(VulnerabilityModel).where(
        VulnerabilityModel.scan_id == scan_id
    )
    count_result = await db.execute(count_query)
    vulnerability_count = count_result.scalar_one()

    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content={
            "has_results": vulnerability_count > 0,
            "vulnerability_count": vulnerability_count
        }
    )
```

**Verification:**

```bash
# Check result collector logs for database verification
kubectl logs -n tool-integration-local deployment/tool-integration | grep "has results"

# Should show for false positives (Slither exit 255 with results):
# ✅ "Scan {id} has results in database despite Job failure"
# ✅ "Skipping failure status update"

# Should show for true failures (network issues, no results):
# ⚠️  "Scan {id} has no results in database"
# ⚠️  "This is a true failure - scanner did not post results"
```

**Deployment:**

```bash
# API Service (0.2.3)
cd /Users/pwner/Git/ABS/blocksecops-api-service
eval $(minikube docker-env)
docker build -t blocksecops-api-service:0.2.3 -t blocksecops-api-service:latest -f Dockerfile .
kubectl rollout restart deployment/api-service -n api-service-local

# Tool Integration (0.2.4)
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
eval $(minikube docker-env)
docker build -t tool-integration:0.2.4 -t tool-integration:latest -f Dockerfile .
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

**Note**: Local development kustomization uses `newTag: latest`, so tagging the versioned image as `latest` and restarting the deployment picks up the new image automatically. No manual kustomization updates needed. See `/Users/pwner/Git/ABS/docs/standards/docker-image-versioning.md` for details.

**Related Documentation:**
- Detailed fix document: `/Users/pwner/Git/ABS/docs/fixes/scanner-status-determination-fix-2025-11-05.md`
- Deployment date: 2025-11-05

---

## Troubleshooting Checklist

When a scanner issue occurs, follow this checklist:

### Step 1: Verify Dashboard Request
```bash
# Check browser network tab for POST /api/v1/scans
# Verify body contains scanner_ids
```

**Expected:**
```json
{
  "contract_id": "uuid",
  "scanner_ids": ["wake"],
  "scan_type": "full"
}
```

---

### Step 2: Verify Database Scan Record
```sql
SELECT id, scanners_used, status, created_at
FROM scans
ORDER BY created_at DESC
LIMIT 1;
```

**Expected:**
```
scanners_used: {wake}
status: pending
```

---

### Step 3: Verify Kubernetes Job Created
```bash
kubectl get jobs -n tool-integration-local | grep wake
```

**Expected:**
```
scan-wake-<scan-id>   1/1    45s
```

---

### Step 4: Verify Job Image and Labels
```bash
# Check image
kubectl get job scan-wake-<scan-id> -n tool-integration-local \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check labels
kubectl get job scan-wake-<scan-id> -n tool-integration-local \
  -o jsonpath='{.metadata.labels}'
```

**Expected:**
```
Image: scanner-wake:0.2.1
Labels: {"scanner": "wake", "scan-id": "..."}
```

---

### Step 5: Verify Scanner Execution
```bash
kubectl logs -n tool-integration-local job/scan-wake-<scan-id>
```

**Expected Lines:**
```
Starting Wake static analysis...
Callback URL: http://tool-integration...
Scan ID: <scan-id>
Posting results to...
✓ Results posted successfully (HTTP 200)
```

---

### Step 6: Verify Tool-Integration Processing
```bash
kubectl logs -n tool-integration-local deployment/tool-integration | grep "Processing results"
```

**Expected:**
```
Processing results from scanner: wake
Posted 5 vulnerabilities to API service for scan <scan-id>
```

---

### Step 7: Verify Final Database State
```sql
SELECT
    s.id,
    s.scanners_used,
    s.status,
    v.scanner_id,
    COUNT(*) AS vuln_count
FROM scans s
LEFT JOIN vulnerabilities v ON s.id = v.scan_id
WHERE s.id = '<scan-id>'
GROUP BY s.id, s.scanners_used, s.status, v.scanner_id;
```

**Expected:**
```
scanners_used: {wake}
status: completed
scanner_id: wake
vuln_count: 5
```

---

## Debugging Tools and Techniques

### Tool 1: Scanner Workflow Tracer Script

```bash
#!/bin/bash
# trace-scanner-workflow.sh
# Traces complete scanner workflow for a scan

SCAN_ID=$1

echo "=== Scanner Workflow Trace for Scan: $SCAN_ID ==="
echo ""

echo "1. Database Scan Record:"
psql -U postgres -d solidity_security -c \
  "SELECT id, scanners_used, status FROM scans WHERE id='$SCAN_ID';"
echo ""

echo "2. Kubernetes Jobs:"
kubectl get jobs -n tool-integration-local | grep ${SCAN_ID:0:8}
echo ""

echo "3. Scanner Job Logs (last 20 lines):"
JOB_NAME=$(kubectl get jobs -n tool-integration-local -o name | grep ${SCAN_ID:0:8} | head -1)
kubectl logs -n tool-integration-local $JOB_NAME | tail -20
echo ""

echo "4. Tool-Integration Logs:"
kubectl logs -n tool-integration-local deployment/tool-integration | grep $SCAN_ID
echo ""

echo "5. Database Vulnerabilities:"
psql -U postgres -d solidity_security -c \
  "SELECT scanner_id, COUNT(*) FROM vulnerabilities WHERE scan_id='$SCAN_ID' GROUP BY scanner_id;"
echo ""
```

---

### Tool 2: Scanner Identification Validator

```bash
#!/bin/bash
# validate-scanner-identification.sh
# Validates scanner identification at all workflow stages

SCAN_ID=$1

echo "=== Scanner Identification Validation ==="
echo ""

echo "Stage 1: Database scanners_used field"
EXPECTED=$(psql -U postgres -d solidity_security -t -c \
  "SELECT scanners_used[1] FROM scans WHERE id='$SCAN_ID';")
echo "Expected: $EXPECTED"
echo ""

echo "Stage 2: Kubernetes Job Label"
JOB_LABEL=$(kubectl get jobs -n tool-integration-local -l scan-id=${SCAN_ID:0:8} \
  -o jsonpath='{.items[0].metadata.labels.scanner}')
echo "Job Label: $JOB_LABEL"
echo ""

echo "Stage 3: Database vulnerabilities scanner_id"
ACTUAL=$(psql -U postgres -d solidity_security -t -c \
  "SELECT DISTINCT scanner_id FROM vulnerabilities WHERE scan_id='$SCAN_ID';")
echo "Actual: $ACTUAL"
echo ""

if [ "$EXPECTED" = "$ACTUAL" ]; then
  echo "✅ Scanner identification is CORRECT"
else
  echo "❌ Scanner contamination detected!"
  echo "   Expected: $EXPECTED"
  echo "   Got: $ACTUAL"
fi
```

---

### Tool 3: Live Workflow Monitor

```bash
#!/bin/bash
# monitor-scan-workflow.sh
# Real-time monitoring of scan workflow

SCAN_ID=$1

echo "Monitoring scan workflow for: $SCAN_ID"
echo "Press Ctrl+C to stop"
echo ""

while true; do
  clear
  echo "=== Scan Status: $SCAN_ID ==="
  echo "Time: $(date)"
  echo ""

  # Database status
  psql -U postgres -d solidity_security -c \
    "SELECT status, scanners_used FROM scans WHERE id='$SCAN_ID';"
  echo ""

  # Job status
  kubectl get jobs -n tool-integration-local | grep ${SCAN_ID:0:8}
  echo ""

  # Recent logs
  echo "Recent Tool-Integration Logs:"
  kubectl logs -n tool-integration-local deployment/tool-integration --tail=5 | grep $SCAN_ID
  echo ""

  sleep 5
done
```

---

## Related Documentation

- **Scanner Integration Guide:** `/Users/pwner/Git/ABS/blocksecops-docs/scanners/SCANNER-INTEGRATION-GUIDE.md`
- **Scanner Update Guide:** `/Users/pwner/Git/ABS/blocksecops-docs/scanners/SCANNER-UPDATE-GUIDE.md`
- **Docker Image Versioning:** `/Users/pwner/Git/ABS/docs/standards/docker-image-versioning.md`
- **Database Schema:** `/Users/pwner/Git/ABS/database/SCHEMA.md`

---

**Document Owner:** Platform Development Team
**Last Reviewed:** November 5, 2025
**Next Review:** December 5, 2025
