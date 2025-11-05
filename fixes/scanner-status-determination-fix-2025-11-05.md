# Scanner Status Determination Fix - 2025-11-05

## Overview

Fixed a production-critical issue where scanner Jobs that successfully posted results were incorrectly marked as "failed" in the database due to Slither's exit code 255 behavior. Implemented a production-ready solution that queries the database to verify results before marking scans as failed.

## Problem Statement

### Symptoms
- Scans showing as "completed" in Kubernetes dashboard
- Same scans showing as "failed" in database
- Slither successfully posting vulnerabilities before exiting with code 255
- False positive failures cluttering the system

### Root Cause
The result collector (`result_collector.py`) was treating all Kubernetes Job failures the same way:
1. Kubernetes marked Jobs as "failed" when Slither exited with code 255 (normal behavior when findings detected)
2. Result collector detected failed Job and sent "failed" status to API
3. This overwrote the "completed" status that was already set when scanner posted results

### Why It Happened
- Initial fix (0.2.3) simply skipped sending status updates for all failed Jobs
- This created a new problem: true failures (network issues, API down) would never be reported
- Need to distinguish between:
  - **False Positive**: Job failed but results successfully posted (Slither exit 255)
  - **True Failure**: Job failed and no results posted (actual scanner failure)

## Solution Architecture

### Design Approach
Implemented database verification to check if scanner actually posted results before determining failure status.

### Components Modified

#### 1. API Service (blocksecops-api-service:0.2.3)
**File**: `src/presentation/api/v1/endpoints/scans.py`

**Added Endpoint**: `GET /api/v1/scans/{scan_id}/check-results` (lines 139-187)

```python
@router.get(
    "/{scan_id}/check-results",
    summary="Check if scan has results",
    description="Check if a scan has vulnerabilities in the database (used by tool-integration service)",
)
async def check_scan_has_results(
    scan_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> JSONResponse:
    """
    Check if a scan has results/vulnerabilities in the database.

    This endpoint is used by the tool-integration service to determine
    if a failed scanner Job actually posted results before failing.

    Returns:
        {"has_results": bool, "vulnerability_count": int}
    """
    # Check if scan exists
    query = select(ScanModel).where(ScanModel.id == scan_id)
    result = await db.execute(query)
    scan = result.scalar_one_or_none()

    if scan is None:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={
                "has_results": False,
                "vulnerability_count": 0,
                "error": f"Scan {scan_id} not found"
            }
        )

    # Count vulnerabilities for this scan
    count_query = select(func.count()).select_from(VulnerabilityModel).where(
        VulnerabilityModel.scan_id == scan_id
    )
    count_result = await db.execute(count_query)
    vulnerability_count = count_result.scalar_one()

    logger.debug(f"Scan {scan_id} has {vulnerability_count} vulnerabilities")

    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content={
            "has_results": vulnerability_count > 0,
            "vulnerability_count": vulnerability_count
        }
    )
```

**Purpose**: Provides a way for tool-integration service to verify if a scan has results in the database.

**Features**:
- No authentication required (internal service-to-service call)
- Returns both boolean flag and vulnerability count
- Handles missing scans gracefully

#### 2. Tool Integration Service (tool-integration:0.2.4)
**File**: `src/scanners/result_collector.py`

**Modified Failed Job Handling** (lines 67-98):

```python
elif status.failed and status.failed >= (job.spec.backoff_limit or 0):
    # Job failed after all retries
    # NOTE: Scanner containers POST results directly before exiting.
    # We need to check if results were actually posted before marking as failed.
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

    # Cleanup ConfigMap for failed job
    try:
        self.job_manager.delete_configmap(scan_id)
        logger.info(f"Deleted ConfigMap for scan {scan_id}")
    except Exception as e:
        logger.warning(f"Failed to delete ConfigMap for scan {scan_id}: {e}")

    self.processed_jobs.add(job_name)
    processed_count += 1
```

**Added Database Check Method** (lines 176-214):

```python
async def _check_scan_has_results(self, scan_id: str) -> bool:
    """
    Check if a scan has results in the database.

    This is used to determine if a failed Job actually posted results before
    failing, or if it's a true failure with no results.

    Args:
        scan_id: Scan ID to check

    Returns:
        True if scan has results/vulnerabilities, False otherwise
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # Query the API to check scan status
            response = await client.get(
                f"{self.api_service_url}/api/v1/scans/{scan_id}/check-results",
                timeout=10.0
            )

            if response.status_code == 200:
                data = response.json()
                has_results = data.get("has_results", False)
                logger.debug(f"Scan {scan_id} has_results: {has_results}")
                return has_results
            else:
                logger.warning(
                    f"Failed to check results for scan {scan_id}: "
                    f"HTTP {response.status_code}. Assuming no results."
                )
                return False

    except httpx.TimeoutException:
        logger.warning(f"Timeout checking results for scan {scan_id}. Assuming no results.")
        return False
    except Exception as e:
        logger.warning(f"Error checking results for scan {scan_id}: {e}. Assuming no results.")
        return False
```

**Key Features**:
- Queries API to verify results exist before sending failure status
- Uses safe defaults (assumes no results on timeout/error)
- Handles network failures gracefully
- Comprehensive logging for debugging

## How It Works

### Execution Flow

1. **Scanner Execution**:
   ```
   Scanner runs → Detects findings → POSTs results to API → Exits with 255
   ```

2. **Kubernetes Response**:
   ```
   Container exits with 255 → K8s marks Job as "Failed"
   ```

3. **Result Collector Processing** (NEW):
   ```
   Detects failed Job → Queries database for results

   IF results exist:
     - Log: "Scanner posted results despite failure"
     - Skip sending failure status
     - Scan status remains "completed"

   ELSE:
     - Log: "True failure - no results found"
     - Send failure status to API
     - Scan status set to "failed"
   ```

### Edge Cases Handled

1. **False Positive (Slither exit 255)**:
   - Job marked "failed" by Kubernetes
   - Scanner successfully posted results before exit
   - Database check finds results → No failure status sent
   - **Result**: Scan correctly shows as "completed"

2. **True Failure (Network Issue)**:
   - Scanner cannot reach API to POST results
   - Job fails, container exits
   - Database check finds no results → Failure status sent
   - **Result**: Scan correctly shows as "failed"

3. **API Timeout During Verification**:
   - Result collector queries API to check results
   - API timeout or error occurs
   - Uses safe default: assumes no results
   - **Result**: Sends failure status (better to report failure than miss it)

4. **Scanner Posts Then Crashes**:
   - Scanner successfully POSTs results
   - Container crashes immediately after
   - Job marked "failed"
   - Database check finds results → No failure status sent
   - **Result**: Scan correctly shows as "completed"

## Deployment

### Version Information
- **API Service**: `blocksecops-api-service:0.2.3`
- **Tool Integration**: `tool-integration:0.2.4`
- **Deployment Date**: 2025-11-05

### Deployment Commands

```bash
# API Service
cd /Users/pwner/Git/ABS/blocksecops-api-service
docker build --no-cache -t blocksecops-api-service:0.2.3 -t blocksecops-api-service:latest -f Dockerfile .
kubectl set image deployment/api-service api-service=blocksecops-api-service:0.2.3 -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# Tool Integration
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
docker build --no-cache -t tool-integration:0.2.4 -t tool-integration:latest -f Dockerfile .
kubectl set image deployment/tool-integration tool-integration=tool-integration:0.2.4 -n tool-integration-local
kubectl rollout status deployment/tool-integration -n tool-integration-local
```

## Testing Recommendations

### Test Scenarios

1. **Normal Scan with Findings**:
   - Trigger Slither scan on contract with vulnerabilities
   - Verify scanner posts results and exits with 255
   - Verify Job marked as "Failed" in Kubernetes
   - **Expected**: Scan status remains "completed" in database

2. **True Scanner Failure**:
   - Simulate network failure preventing result posting
   - Let scanner Job fail
   - **Expected**: Scan status correctly marked as "failed" in database

3. **API Unavailable During Verification**:
   - Bring down API service temporarily
   - Let scanner Job complete/fail
   - Result collector attempts to verify results
   - **Expected**: Safe default behavior - marks as failed

4. **Scanner Success (No Findings)**:
   - Trigger scan on clean contract
   - Scanner posts empty results, exits with 0
   - Job completes successfully
   - **Expected**: Scan status "completed" in database

## Monitoring

### Log Patterns to Watch

**Successful Result Verification**:
```
INFO: Scan {scan_id} has results in database despite Job failure.
INFO: Scanner successfully posted results before container exit.
INFO: Skipping failure status update.
```

**True Failure Detected**:
```
WARNING: Scan {scan_id} has no results in database.
WARNING: This is a true failure - scanner did not post results.
WARNING: Sending failure status to API.
```

**Verification Errors** (needs investigation):
```
WARNING: Timeout checking results for scan {scan_id}. Assuming no results.
WARNING: Failed to check results for scan {scan_id}: HTTP {status}. Assuming no results.
WARNING: Error checking results for scan {scan_id}: {error}. Assuming no results.
```

### Metrics to Track

- Number of failed Jobs with results (false positives avoided)
- Number of failed Jobs without results (true failures caught)
- API verification endpoint response times
- API verification endpoint error rates

## Rollback Plan

If issues arise, rollback to previous versions:

```bash
# Rollback API Service to 0.2.2
kubectl set image deployment/api-service api-service=blocksecops-api-service:0.2.2 -n api-service-local

# Rollback Tool Integration to 0.2.3
kubectl set image deployment/tool-integration tool-integration=tool-integration:0.2.3 -n tool-integration-local
```

**Note**: Version 0.2.3 has the initial fix but may miss reporting true failures. Version 0.2.2 has the original issue where all Slither scans show as failed.

## Future Improvements

1. **Caching**: Cache result verification checks to reduce API load
2. **Retry Logic**: Add exponential backoff for API verification requests
3. **Metrics**: Expose Prometheus metrics for false positive vs true failure rates
4. **Alerting**: Alert when verification error rate exceeds threshold
5. **Testing**: Add integration tests for failure scenarios

## Related Documentation

- Scanner Integration Guide: `/Users/pwner/Git/ABS/blocksecops-docs/scanners/SCANNER-INTEGRATION-GUIDE.md`
- Scanner Workflow Troubleshooting: `/Users/pwner/Git/ABS/blocksecops-docs/scanners/SCANNER-WORKFLOW-TROUBLESHOOTING.md`
- Multi-Scanner Execution Fix: `/Users/pwner/Git/ABS/docs/MULTI-SCANNER-EXECUTION-FIX-2025-11-03.md`

## References

- Issue: Slither exit code 255 behavior causing false positive failures
- Previous Fix: tool-integration:0.2.3 (symptom fix - skipped all failures)
- Production Fix: tool-integration:0.2.4 + api-service:0.2.3 (root cause fix)
