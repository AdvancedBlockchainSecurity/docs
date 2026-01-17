# Activity Logging Integration & Severity Count Fix

**Date:** January 16, 2026
**Version:** API Service 0.10.7, Dashboard 0.30.9
**Status:** Complete

## Summary

1. Integrated the existing `ActivityLoggingService` into the application flow so user activity is logged and displayed on the `/activity` page
2. Fixed scan severity counts being overwritten when multiple scanners post results

## Bug Fix: Severity Counts Overwritten (v0.10.7)

**Problem:** When multiple scanners posted results to the same scan, each scanner's results would **overwrite** the previous counts instead of adding to them. If the last scanner (e.g., echidna fuzzer) had 0 vulnerabilities, all counts would show 0.

**Root Cause:** In `store_scan_results()`, the code did:
```python
scan.critical_count = severity_counts["critical"]  # OVERWRITES
```

**Fix:** Changed to accumulate counts:
```python
scan.critical_count = (scan.critical_count or 0) + severity_counts["critical"]  # ADDS
```

**Database Fix:** Recalculated counts for 100 affected scans.

## Activity Logging Integration (v0.10.6)

Previously, the service existed with all methods implemented, but no code called it when events occurred.

## Problem

The `/activity` page showed no data because:
- `ActivityLoggingService` existed with complete implementation
- The service was only used for READING activity (in `/me/activity` endpoint)
- NO code called the logging methods when events occurred (scans, contracts, uploads)

## Solution

Added activity logging calls at key event points throughout the API service.

## Files Modified

### API Service (`blocksecops-api-service`)

| File | Changes |
|------|---------|
| `src/presentation/api/v1/endpoints/scans.py` | Added `log_scan_started`, `log_scan_completed`, `log_scan_failed` |
| `src/presentation/api/v1/endpoints/contracts.py` | Added `log_contract_created`, `log_contract_deleted` |
| `src/presentation/api/v1/endpoints/upload.py` | Added `log_file_upload`, `log_contract_created` |
| `src/presentation/api/v1/endpoints/deduplication.py` | Fixed pattern_code fallback to canonical finding |
| `pyproject.toml` | Version bump 0.10.5 → 0.10.6 |
| `k8s/overlays/local/kustomization.yaml` | Version bump 0.10.5 → 0.10.6 |

## Activity Types Now Logged

| Activity Type | Event Location | When Triggered |
|--------------|----------------|----------------|
| `file_upload` | upload.py | Single file or archive upload |
| `contract_created` | upload.py, contracts.py | Contract created via upload or API |
| `contract_deleted` | contracts.py | Single or batch contract deletion |
| `scan_started` | scans.py | Scan creation after commit |
| `scan_completed` | scans.py | Successful scan results stored |
| `scan_failed` | scans.py | Scan failure at any point |

## Implementation Details

### Scan Events (scans.py)

```python
# After scan creation
await activity_service.log_scan_started(
    db, current_user.id, scan.id, scan.contract_id, scan_data.scanner_ids
)

# After successful scan results
await activity_service.log_scan_completed(
    db, scan.user_id, scan.id, scan.contract_id,
    results.scanner, credits_used=1, vulnerabilities_found=len(created_vulns)
)

# On scan failure
await activity_service.log_scan_failed(
    db, scan.user_id, scan.id, scan.contract_id,
    scanner_type, error_message=error_msg
)
```

### Contract Events (contracts.py)

```python
# After contract creation
await activity_service.log_contract_created(
    db, current_user.id, contract.id, contract.name, contract.language
)

# After contract deletion
await activity_service.log_contract_deleted(
    db, current_user.id, contract_name, scan_count
)
```

### Upload Events (upload.py)

```python
# After file upload
await activity_service.log_file_upload(
    db, current_user.id, contract.id, file.filename, file_count=file_count
)
```

## Additional Fix: Deduplication Pattern Code

Fixed issue where deduplication groups showed `null` for `pattern_code` by adding fallback to canonical finding's pattern_code:

```python
pattern_code=(
    group.pattern_code
    or (group.canonical_finding.pattern_code if group.canonical_finding else None)
)
```

## Verification Steps

1. **Upload a contract** → Check `/activity` for "File Upload" + "Contract Created"
2. **Run a scan** → Check for "Scan Started" then "Scan Completed" with vulnerability count
3. **Delete a contract** → Check for "Contract Deleted"
4. **Summary cards** → Should show accurate counts for scans completed/failed, credits used

## Related Documentation

- Feature Test: `docs/feature-tests/16-user-activity-logging.md`
- API Endpoint: `GET /api/v1/me/activity`
- Service: `src/application/services/activity_logging_service.py`
