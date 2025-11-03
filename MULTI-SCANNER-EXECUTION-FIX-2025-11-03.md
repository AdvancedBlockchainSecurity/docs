# Multi-Scanner Execution Fix - 2025-11-03

**Session Date**: November 3, 2025
**Status**: ✅ PRIMARY ISSUE RESOLVED - Scanner orchestration working, deployment fixes pending
**Services Modified**: blocksecops-api-service (v0.2.3), blocksecops-tool-integration (v0.2.2)

---

## Executive Summary

Fixed critical multi-scanner execution issue where Deep Scan preset only triggered Slither scanner instead of all 8 selected scanners. Root cause was scanner whitelist mismatch between API service (8 scanners) and tool-integration service (3 scanners), causing silent failures with HTTP 200 OK responses containing `{"success": false}` in body.

**Impact**: Deep Scan now successfully triggers all 8 scanners (slither, aderyn, semgrep, solhint, halmos, echidna, wake, medusa) as jobs. 4/8 complete successfully, 4/8 fail due to missing Docker images or implementation issues (separate from orchestration fix).

---

## Problem Statement

### Initial Issue
User reported: "Deep Scan on http://127.0.0.1:3000/scans/74244b10-35a7-462a-8ab2-6acf64c316a1 only shows Slither scanner"

### Investigation Findings

**Scanner Registration Mismatch:**
- API Service registered scanners: 8 (slither, aderyn, semgrep, solhint, halmos, echidna, wake, medusa)
- Tool-Integration valid_scanners: 3 (slither, mythril, aderyn)
- Result: 5 scanners silently rejected

**Silent Failure Mechanism:**
When API triggered unsupported scanners (semgrep, solhint, halmos, echidna, wake, medusa), tool-integration:
1. Returned HTTP 200 OK (not 400/404 error)
2. Included `{"success": false, "error": "Invalid scanner: X"}` in response body
3. Did NOT log rejection at INFO level (only at error level)
4. API's `response.raise_for_status()` didn't catch this (only checks HTTP status code, not body)

**Evidence from Logs:**
```
# API logs showed:
scanners_used=None  # Never set because triggers failed silently

# Tool-integration logs showed:
POST /scans/{id}/trigger?scanner=semgrep - 200 OK  # But {"success": false}
POST /scans/{id}/trigger?scanner=halmos - 200 OK   # But {"success": false}
POST /scans/{id}/trigger?scanner=medusa - 200 OK   # But {"success": false}

# Kubernetes jobs:
Only 2 jobs created: scan-slither-*, scan-aderyn-*
Expected: 8 jobs (one per scanner)
```

---

## Solution Implemented

### Phase 1: Multi-Scanner Triggering (API Service v0.2.3)

**File**: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:195-279`

**Changes**:
1. **Replaced single scanner trigger with loop**:
   ```python
   # OLD: Triggered only first scanner
   scanner_id = scan_data.scanner_ids[0] if scan_data.scanner_ids else "slither"

   # NEW: Trigger all scanners from request
   scanners_to_trigger = scan_data.scanner_ids if scan_data.scanner_ids else ["slither"]
   for scanner_id in scanners_to_trigger:
       # Trigger each scanner job
   ```

2. **Added rate limiting with consecutive failure tracking**:
   ```python
   MAX_CONSECUTIVE_FAILURES = 3
   consecutive_failures = 0

   for scanner_id in scanners_to_trigger:
       if consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
           scan.status = "failed"
           raise HTTPException(503, "Scanner triggering aborted after 3 consecutive failures")

       try:
           # Trigger scanner
           consecutive_failures = 0  # Reset on success
       except Exception:
           consecutive_failures += 1
   ```

3. **Added comprehensive logging**:
   ```python
   logger.info(f"Triggering {len(scanners_to_trigger)} scanner(s) for scan {scan.id}: {scanners_to_trigger}")
   logger.info(f"Successfully triggered {scanner_id} scanner for scan {scan.id}")
   logger.error(f"Failed to trigger {scanner_id} scanner: {e}. Consecutive failures: {consecutive_failures}/{MAX_CONSECUTIVE_FAILURES}")
   ```

4. **Added scan failure protection**:
   ```python
   if len(successful_triggers) == 0:
       logger.error(f"No scanners successfully triggered for scan {scan.id}")
       scan.status = "failed"
       raise HTTPException(503, "Failed to trigger any scanners")
   ```

**Deployment**:
- Built Docker image: `blocksecops-api-service:0.2.3`
- Updated kustomization: `newTag: 0.2.3`
- Deployed to Kubernetes: `kubectl apply -k k8s/overlays/local`
- Verified pod running: `api-service-689546fc5b-4b2nt`

---

### Phase 2: Scanner Whitelist Expansion (Tool-Integration v0.2.2)

**File**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/src/main.py:122-128`

**Changes**:
```python
# OLD:
valid_scanners = ["slither", "mythril", "aderyn"]

# NEW:
valid_scanners = [
    "slither", "mythril", "aderyn",
    "semgrep", "solhint",
    "halmos", "echidna", "wake", "medusa"
]
```

**Added error logging**:
```python
if scanner not in valid_scanners:
    logger.error(f"Invalid scanner requested: {scanner}. Valid scanners: {valid_scanners}")
    return {
        "success": False,
        "error": f"Invalid scanner: {scanner}. Must be one of {valid_scanners}"
    }
```

**Deployment**:
- Built Docker image: `tool-integration:0.2.2`
- Updated kustomization: `newTag: 0.2.2`
- Deployed to Kubernetes: `kubectl apply -k k8s/overlays/local`
- Verified pods running: 2 pods with image `tool-integration:0.2.2`

---

### Phase 3: Documentation Updates

**File**: `/Users/pwner/Git/ABS/blocksecops-docs/SCANNER-INTEGRATION-GUIDE.md`

**Updates Made**:

1. **Added Critical Integration Requirements (lines 55-66)**:
   ```markdown
   **⚠️ IMPORTANT:** Scanner integration requires **THREE components**:
   1. Tool-Integration Executor - Scanner in `valid_scanners` list
   2. API Service Metadata - Scanner in `scanners.py` configuration
   3. Dashboard Configuration - Scanner in `scannerConfigurations.ts`

   **Common Pitfall:** Installing scanner but forgetting to register in all three
   locations results in silent failures or invisible scanners.
   ```

2. **Updated Phase 6 Checklist (lines 118-123)**:
   Added critical step:
   ```markdown
   - [ ] **⚠️ CRITICAL:** Add scanner ID to tool-integration `valid_scanners` list
         (`blocksecops-tool-integration/src/main.py:122`)
   ```

3. **Added New Troubleshooting Section (lines 934-1003)**:
   ```markdown
   ### Issue: Scanner registered in API but not in tool-integration

   **Symptoms:**
   - ✅ Scanner appears in API: GET /api/v1/scanners
   - ✅ Scanner appears in dashboard preset selector
   - ✅ API sends trigger request
   - ✅ Tool-integration returns 200 OK
   - ❌ But response body: {"success": false, "error": "Invalid scanner: X"}
   - ❌ NO Kubernetes job created
   - ❌ NO error logged at INFO level
   - ❌ API doesn't check response body success field

   **Root Cause:** Tool-integration hardcoded valid_scanners list

   **Fix:** Update tool-integration valid_scanners list in src/main.py:122
   ```

---

## Verification & Testing

### Test 1: Deep Scan Execution (Scan ID: 88e31443-a0af-4d4a-b6bf-f5edbe914686)

**Command**:
```bash
kubectl get jobs -n tool-integration-local -l scan-id=88e31443-a0af-4d4a-b6bf-f5edbe914686
```

**Results**:
```
NAME                    STATUS     COMPLETIONS   DURATION   AGE
scan-aderyn-88e31443    Running    0/1           25s        25s
scan-echidna-88e31443   Running    0/1           25s        25s
scan-halmos-88e31443    Running    0/1           25s        25s
scan-medusa-88e31443    Complete   1/1           20s        24s
scan-semgrep-88e31443   Complete   1/1           20s        25s
scan-slither-88e31443   Complete   1/1           15s        25s
scan-solhint-88e31443   Complete   1/1           17s        25s
scan-wake-88e31443      Running    0/1           25s        25s
```

**✅ SUCCESS**: All 8 scanner jobs created (was 2 before fix)

**Scanner Status**:
- ✅ slither - Completed
- ✅ semgrep - Completed
- ✅ solhint - Completed
- ✅ medusa - Completed
- ⚠️ aderyn - Error: "Not a directory (os error 20)"
- ⚠️ halmos - ImagePullBackOff: scanner-halmos:0.2.0 not found
- ⚠️ echidna - ImagePullBackOff: scanner-echidna:0.2.0 not found
- ⚠️ wake - ImagePullBackOff: scanner-wake:0.2.0 not found

**Pod Details**:
```bash
kubectl get pods -n tool-integration-local -l scan-id=88e31443-a0af-4d4a-b6bf-f5edbe914686
```
```
NAME                          READY   STATUS             RESTARTS   AGE
scan-aderyn-88e31443-7cjcs    0/1     Error              0          26s
scan-echidna-88e31443-ldqtk   0/1     ImagePullBackOff   0          26s
scan-halmos-88e31443-kf9ck    0/1     ImagePullBackOff   0          26s
scan-medusa-88e31443-j78c7    0/1     Completed          0          25s
scan-semgrep-88e31443-w484m   0/1     Completed          0          26s
scan-slither-88e31443-hd7gs   0/1     Completed          0          26s
scan-solhint-88e31443-lvnpq   0/1     Completed          0          26s
scan-wake-88e31443-mrj9t      0/1     ImagePullBackOff   0          26s
```

---

## Pending Issues (Out of Scope)

The orchestration fix is complete, but individual scanner implementations have issues:

### Issue 1: Missing Docker Images (3 scanners)
**Scanners**: halmos, echidna, wake
**Error**: `ImagePullBackOff: scanner-{name}:0.2.0 image not found`
**Status**: Dockerfiles exist, images not built
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/{scanner}/`

**Fix Required**:
```bash
# Build each scanner image
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/halmos
eval $(minikube docker-env)
docker build -t scanner-halmos:0.2.0 .

cd ../echidna
docker build -t scanner-echidna:0.2.0 .

# Wake scanner needs investigation (no directory found)
```

### Issue 2: Aderyn Runtime Error
**Scanner**: aderyn
**Error**: `Error making context: Not a directory (os error 20)`
**Root Cause**: Aderyn expects project directory structure, not single contract file
**Status**: Requires wrapper script or Dockerfile modification

**Fix Required**:
- Option A: Add wrapper script (like halmos-scan, semgrep-scan)
- Option B: Modify Dockerfile entrypoint to handle single files
- Option C: Update KubernetesJobManager to create project structure

### Issue 3: Wake Scanner Implementation
**Scanner**: wake
**Status**: Registered in API but no implementation found
**Location**: No directory at `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/wake/`

**Decision Required**:
- Remove wake from API/tool-integration (clean removal)
- OR: Implement wake scanner (requires research on wake tool)

---

## Files Modified

### blocksecops-api-service
```
modified:   k8s/overlays/local/kustomization.yaml
            - Updated newTag: 0.2.2 → 0.2.3

modified:   pyproject.toml
            - Updated version: 0.2.2 → 0.2.3

modified:   src/presentation/api/v1/endpoints/scans.py
            - Added multi-scanner triggering loop (lines 195-279)
            - Added rate limiting with MAX_CONSECUTIVE_FAILURES=3
            - Added comprehensive logging
            - Added scan failure protection
```

### blocksecops-tool-integration
```
modified:   k8s/overlays/local/kustomization.yaml
            - Updated newTag: 0.2.1 → 0.2.2

modified:   src/main.py
            - Updated valid_scanners from 3 to 9 scanners (line 122)
            - Added ERROR-level logging for invalid scanners
```

### blocksecops-docs
```
modified:   SCANNER-INTEGRATION-GUIDE.md
            - Added Critical Integration Requirements section (lines 55-66)
            - Updated Phase 6 checklist with tool-integration step (lines 118-123)
            - Added comprehensive troubleshooting section (lines 934-1003)
```

---

## Deployment Status

### Services Deployed
| Service | Version | Status | Pods | Image |
|---------|---------|--------|------|-------|
| api-service | 0.2.3 | ✅ Running | 1/1 | blocksecops-api-service:0.2.3 |
| tool-integration | 0.2.2 | ✅ Running | 2/2 | tool-integration:0.2.2 |
| dashboard | latest | ✅ Running | - | http://127.0.0.1:3000 |

### Port-Forwards Active
```bash
kubectl port-forward -n api-service-local svc/api-service 8000:8000
# Dashboard on port 3000 (npm run dev)
```

---

## Next Steps

### Immediate (Scanner Image Building)
1. Build missing scanner images: halmos, echidna, aderyn
2. Load images to minikube
3. Investigate wake scanner status (remove or implement)
4. Fix aderyn runtime error (add wrapper script)
5. Test Deep Scan with all scanners completing successfully

### Short-term (Response Body Validation)
Add response body validation to API service scanner triggering:
```python
response = await client.post(...)
response.raise_for_status()
result = response.json()

# NEW: Check success field
if not result.get("success", True):
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail=f"Scanner trigger failed: {result.get('error', 'Unknown error')}"
    )
```

### Long-term (Architecture Improvement)
Replace hardcoded `valid_scanners` list with database-driven scanner registry:
- Scanners table stores enabled/disabled state
- Tool-integration queries database instead of hardcoded list
- API and tool-integration always in sync
- No deployment required when adding/removing scanners

---

## Lessons Learned

### Silent Failure Anti-Pattern
**Problem**: HTTP 200 OK with `{"success": false}` in body bypasses error detection.

**Prevention**:
1. Always return proper HTTP status codes (400, 404, 503)
2. If using success/error in response body, check it in client code
3. Add ERROR-level logging for all rejection cases
4. Document API response contracts explicitly

### Scanner Registration Synchronization
**Problem**: Multiple services maintain scanner lists independently (API, tool-integration, dashboard).

**Prevention**:
1. Document THREE required components in integration guide
2. Add checklist item for each component
3. Consider single source of truth (database) in future architecture
4. Add verification commands to detect mismatches

### Configuration Drift Detection
**Prevention**:
```bash
# Check for scanner registration mismatches
comm -13 <(grep "valid_scanners = " tool-integration/src/main.py | grep -oP '"\K[^"]+' | sort) \
         <(curl -s 'http://localhost:8000/api/v1/scanners?language=solidity' | jq -r '.scanners[].id' | sort)
```

---

## References

**Related Documentation**:
- `/Users/pwner/Git/ABS/blocksecops-docs/SCANNER-INTEGRATION-GUIDE.md` - Scanner integration checklist
- `/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md` - Platform standards
- `/Users/pwner/Git/ABS/docs/architecture-templates/kubernetes-kustomize-structure-template.md` - K8s structure

**Related Issues**:
- Deep Scan only triggering Slither (RESOLVED)
- Scanner whitelist mismatch (RESOLVED)
- Missing scanner Docker images (PENDING)
- Aderyn runtime error (PENDING)
- Wake scanner implementation (PENDING)

---

## Conclusion

**Primary Issue**: ✅ RESOLVED
**Status**: Multi-scanner orchestration working correctly. All 8 scanners now triggered as Kubernetes jobs.

**Remaining Work**: Individual scanner implementation fixes (Docker images, runtime errors, missing implementations) - tracked in separate task list for next session.

**Impact**: Deep Scan preset now functional for multi-scanner execution. Platform can scale to support additional scanners by following three-component integration checklist.
