# API Service Platform-Wide Fixes & Hardening

## Version 0.27.0 - Severity Cleanup, Validation & Access Control - February 6, 2026

**Date:** 2026-02-06
**Component:** blocksecops-api-service (0.26.1 -> 0.27.0)
**Type:** Enhancement + Bug Fix
**Priority:** High
**Status:** Complete

---

## Summary

11 changes across the API service covering three themes:
1. **Severity cleanup** (A1) — Removed "info" severity platform-wide, mapped all info/informational to "low" with DB migration
2. **Input validation & error handling** (A2-A5, A10) — Fixed scan status mapping, added Literal type validation, audit log error handling, search schema alias, semantic search 503 handling
3. **Access control hardening** (A8-A9) — Tier-gated search export, admin-only role management with self-demotion and last-admin protection
4. **Endpoint reviews** (A6-A7) — Confirmed scanner effectiveness and scan vulnerability counts already fully implemented
5. **Version bump** (A11) — 0.26.1 to 0.27.0

---

## Issues Resolved

- Info/informational severity caused inconsistent categorization across intelligence, scanning, analytics, and ML modules
- Scans endpoint accepted "pending" as a status value (should be "queued")
- Deduplication endpoint accepted arbitrary severity strings without validation
- Audit logs endpoint returned 500 on database errors instead of graceful empty response
- Search endpoint required `contract_ids` (array) but frontend sent `contract_id` (singular)
- Search export endpoint lacked tier enforcement
- Role management endpoint lacked admin-only checks, self-demotion prevention, and last-admin protection
- Semantic search endpoint returned raw 500 on intelligence engine unavailability

---

## Added

### A1: Remove "Info" Severity Platform-Wide

Replaced all "info" and "informational" severity references with "low" across 7 service modules:

| File | Change |
|------|--------|
| `src/domain/services/intelligence_service.py` | Severity mapping: info/informational -> low |
| `src/domain/services/scanner_upgrade_service.py` | Severity mapping: info/informational -> low |
| `src/domain/services/analytics.py` | Severity categorization: info -> low |
| `src/domain/services/risk_scorer.py` | Risk weight mapping: info -> low |
| `src/domain/services/prioritizer.py` | Priority mapping: info -> low |
| `src/domain/services/feature_extractor.py` | Feature extraction: info -> low |
| `src/domain/services/economic_risk_scorer.py` | Economic risk: info -> low |

**Database migration:** `alembic/versions/20260206_0100-034_remove_info_severity.py`
```sql
UPDATE vulnerability_patterns SET severity = 'low' WHERE severity IN ('info', 'informational');
```

### A2: Scan Status "Pending" to "Queued" Fix

**File:** `src/presentation/api/v1/endpoints/scans.py`
- Added input validation for status query parameter
- Maps "pending" to "queued" for backward compatibility
- Returns 422 for invalid status values

### A3: Deduplication Severity Literal Validation

**File:** `src/presentation/api/v1/endpoints/deduplication.py`
- Changed severity parameter type to `Literal["critical", "high", "medium", "low"]`
- Invalid severity values now auto-return 422 via FastAPI validation
- Removed "info" from accepted values

### A4: Audit Logs Error Handling

**File:** `src/presentation/api/v1/endpoints/audit_logs.py`
- Wrapped database queries in try/except blocks
- Returns empty paginated response on database errors instead of 500
- Logs database errors for debugging

### A5: Search Schema Contract ID Alias

**File:** `src/presentation/schemas/search.py`
- Added `contract_id` field as alias for `contract_ids` array
- Frontend can send either `contract_id` (singular) or `contract_ids` (array)

**File:** `src/presentation/api/v1/endpoints/search.py`
- Maps singular `contract_id` to `contract_ids` array in search endpoint logic

### A8: Search Export Tier Enforcement

**File:** `src/presentation/api/v1/endpoints/search.py`
- Added `require_tier("team")` dependency to search export endpoint
- Free-tier users now receive 403 when attempting to export search results

### A9: Role Management Access Control

**File:** `src/presentation/api/v1/endpoints/organizations.py`
- Added admin-only permission check for role update endpoint
- Self-demotion prevention: users cannot change their own role
- Last-admin protection: prevents demoting the last admin/owner in an organization

### A10: Semantic Search 503 Handling

**File:** `src/presentation/api/v1/endpoints/intelligence.py`
- Added try/except for intelligence engine connection errors
- Returns 503 with `"Intelligence service temporarily unavailable"` message
- Prevents raw 500 errors when intelligence engine is down

---

## Changed

### A6: Scanner Effectiveness Endpoint Review

**Status:** No changes needed - already fully implemented
- Endpoint returns scanner metrics, overlap matrix, and recommendations
- Confirmed complete implementation during code review

### A7: Scan Vulnerability Count Aggregation Review

**Status:** No changes needed - already present
- Vulnerability count aggregation confirmed working in scan list endpoint
- No missing functionality identified

### A11: Version Bump

| File | Change |
|------|--------|
| `pyproject.toml` | `version = "0.26.1"` -> `version = "0.27.0"` |
| `k8s/overlays/local/api-service/kustomization.yaml` | `newTag: "0.26.1"` -> `newTag: "0.27.0"` |

---

## Fixed

- **A2:** Scans endpoint now correctly maps "pending" to "queued" instead of accepting invalid status
- **A4:** Audit logs endpoint no longer returns 500 on database errors
- **A5:** Search endpoint accepts both `contract_id` and `contract_ids` from frontend

---

## Code Changes

### Files Modified (16 files)

| File | Item | Change |
|------|------|--------|
| `src/domain/services/intelligence_service.py` | A1 | info/informational severity -> low |
| `src/domain/services/scanner_upgrade_service.py` | A1 | info/informational severity -> low |
| `src/domain/services/analytics.py` | A1 | info severity -> low |
| `src/domain/services/risk_scorer.py` | A1 | info risk weight -> low |
| `src/domain/services/prioritizer.py` | A1 | info priority -> low |
| `src/domain/services/feature_extractor.py` | A1 | info feature extraction -> low |
| `src/domain/services/economic_risk_scorer.py` | A1 | info economic risk -> low |
| `src/presentation/api/v1/endpoints/scans.py` | A2 | Status validation, pending -> queued mapping |
| `src/presentation/api/v1/endpoints/deduplication.py` | A3 | Literal type severity validation |
| `src/presentation/api/v1/endpoints/audit_logs.py` | A4 | try/except error handling |
| `src/presentation/schemas/search.py` | A5 | contract_id alias field |
| `src/presentation/api/v1/endpoints/search.py` | A5, A8 | contract_id mapping, tier enforcement |
| `src/presentation/api/v1/endpoints/organizations.py` | A9 | Admin-only role management |
| `src/presentation/api/v1/endpoints/intelligence.py` | A10 | 503 error handling |
| `pyproject.toml` | A11 | Version 0.26.1 -> 0.27.0 |
| `k8s/overlays/local/api-service/kustomization.yaml` | A11 | newTag 0.26.1 -> 0.27.0 |

### New Files (1 file)

| File | Item | Description |
|------|------|-------------|
| `alembic/versions/20260206_0100-034_remove_info_severity.py` | A1 | DB migration: update info/informational severity to low |

---

## Testing

### Verification Checklist

- [ ] **A1:** Run migration 034, verify `SELECT COUNT(*) FROM vulnerability_patterns WHERE severity IN ('info', 'informational')` returns 0
- [ ] **A2:** `GET /api/v1/scans?status=pending` returns results with status "queued"
- [ ] **A2:** `GET /api/v1/scans?status=invalid` returns 422
- [ ] **A3:** `GET /api/v1/deduplication?severity=info` returns 422
- [ ] **A3:** `GET /api/v1/deduplication?severity=high` returns results
- [ ] **A4:** Simulate DB error on audit logs endpoint, verify empty response (not 500)
- [ ] **A5:** Search with `contract_id` (singular) returns same results as `contract_ids` (array)
- [ ] **A8:** Free-tier user attempts search export, receives 403
- [ ] **A8:** Team-tier user attempts search export, receives results
- [ ] **A9:** Non-admin attempts role change, receives 403
- [ ] **A9:** Admin attempts self-demotion, receives 400
- [ ] **A9:** Attempt to demote last admin, receives 400
- [ ] **A10:** Stop intelligence engine, call semantic search, verify 503 response

---

## Impact

### User Impact
- Consistent four-level severity model (critical/high/medium/low) across all API responses
- Better error messages instead of generic 500 errors
- Search works with both singular and plural contract ID parameter names
- Role management is now safe from accidental lockouts

### Breaking Changes
- "info" and "informational" severity values no longer appear in API responses
- Deduplication endpoint rejects "info" severity parameter (returns 422)
- Search export requires "team" tier or above

### Performance
- No performance impact; changes are validation and mapping logic only

---

## Deployment

### Build and Deploy

```bash
cd /home/pwner/Git/blocksecops-api-service

VERSION=0.27.0
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/api-service:${VERSION} .

docker push harbor.blocksecops.local/blocksecops/api-service:${VERSION}
kubectl apply -k k8s/overlays/local/api-service/
kubectl rollout restart deployment/api-service -n api-service-local
```

### Run Database Migration

```bash
kubectl exec -n api-service-local deploy/api-service -- alembic upgrade head
```

---

## Related Documentation

- [Task Documentation](../../TaskDocs-Apogee/DOCUMENTATION-UPDATE-2026-02-06-API-SERVICE-V0.27.0.md)
- [Intelligence Integration Standards](../standards/INTELLIGENCE-INTEGRATION-STANDARDS.md)
- [Tier Standards](../standards/tier-standards.md)
- [API Endpoint Authentication](../standards/api-endpoint-auth.md)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.27.0 | 2026-02-06 | Remove info severity, validation hardening, access control, error handling |
| 0.26.1 | 2026-02-05 | OAuth error passthrough, CI/CD tab expansion, support tickets |
| 0.26.0 | 2026-02-05 | ML retraining moved to admin, scanner upgrade pipeline |

---

**Maintained By:** Apogee Team
**Status:** Complete
