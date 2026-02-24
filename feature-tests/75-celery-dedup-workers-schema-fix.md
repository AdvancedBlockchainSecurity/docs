# Celery Dedup Workers and is_canonical Schema Fix

**Priority**: P1 - High
**Last Tested**: 2026-02-24
**Scope**: Celery worker dedup processing, is_canonical API response, init-time callable defaults
**API Version**: 0.29.13 - 0.29.19

---

## 1. Celery Worker Dedup Processing

### 1.1 Worker Pod Running

- [x] `celery-worker` deployment exists in `api-service-local` namespace
- [x] Worker pod status is `Running`
- [x] Worker image matches api-service image (same version tag)
- [x] Worker command is `celery -A src.infrastructure.celery_app worker --queues=dedup --concurrency=3`

```bash
kubectl get pods -n api-service-local -l app.kubernetes.io/name=celery-worker
kubectl get deployment -n api-service-local celery-worker -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### 1.2 Task Dispatch from API Pod

- [x] `store_scan_results()` calls `run_dedup_task.delay()` (not `asyncio.create_task()`)
- [x] Dispatch is non-blocking (API response returns immediately)
- [x] Task only dispatched when `created_vulnerability_ids` is non-empty
- [x] API logs show "Dedup task dispatched to Celery"

### 1.3 Worker Processes All 3 Phases

- [x] Phase 1 (intra-scan dedup) runs in worker
- [x] Phase 2 (cross-scan dedup) runs in worker
- [x] Phase 3 (post-scan maintenance) runs in worker
- [x] Worker logs show `[celery-dedup]` prefixed entries
- [x] Each phase has independent error isolation (try/except/rollback)

### 1.4 API Pod Stays Healthy During Heavy Dedup

- [x] Health check `/api/v1/health/live` responds during dedup processing
- [x] Health check `/api/v1/health/ready` responds during dedup processing
- [x] API pod does not restart when worker processes large scans

### 1.5 Celery Retry on Failure

- [x] Task configured with `max_retries=2`, `default_retry_delay=30`
- [x] Soft time limit: 5 minutes (raises `SoftTimeLimitExceeded`)
- [x] Hard time limit: 10 minutes (SIGKILL)
- [x] Failed tasks are re-queued in Redis

---

## 2. is_canonical in API Responses (v0.29.19)

### 2.1 Vulnerability List Endpoint

- [x] `GET /api/v1/vulnerabilities` includes `is_canonical` field
- [x] `is_canonical` is `true` for primary findings
- [x] `is_canonical` is `false` for duplicate findings
- [x] JSON field name is `is_canonical` (not `is_primary`)

```bash
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://app.blocksecops.local/api/v1/vulnerabilities?limit=5" | \
  python3 -c "import sys,json; [print(f'{v[\"title\"][:40]}: is_canonical={v[\"is_canonical\"]}') for v in json.load(sys.stdin)['vulnerabilities'][:5]]"
```

### 2.2 Schema Alias Correctness

- [x] `VulnerabilityResponse.is_canonical` uses `validation_alias=AliasChoices("is_canonical", "is_primary")`
- [x] `populate_by_name = True` in Config (allows both field name and alias)
- [x] Pydantic reads `is_primary` from DB model, serializes as `is_canonical` in JSON
- [x] Manual construction with `is_canonical=True` still works

### 2.3 Deduplication Group Context

- [x] `deduplication_group_id` populated for grouped vulnerabilities
- [x] `duplicate_count` populated (>0 for groups with duplicates)
- [x] Primary finding has `is_canonical=true`
- [x] Duplicate findings have `is_canonical=false`

---

## 3. Init-Time Callable Defaults (v0.29.18)

### 3.1 UUID Generation at Construction

- [x] `VulnerabilityModel()` gets a real UUID at `__init__` time (not None)
- [x] All 78 models with `default=uuid4` get UUIDs at construction
- [x] Explicit `id=some_uuid` values are not overwritten by the listener
- [x] Each instance gets a unique UUID

### 3.2 Celery Task Arguments

- [x] `vulnerability_ids` passed to Celery task are real UUIDs (not "None")
- [x] `scan_id` and `contract_id` are real UUIDs
- [x] Worker successfully parses UUID strings back to UUID objects

---

## 4. E2E Test: Full Scan-to-Dedup Pipeline

### 4.1 Test Procedure

```bash
# 1. Upload a contract with known vulnerabilities (API key auth)
curl -sk -H "X-API-Key: $API_KEY" \
  -F "file=@VulnerableE2E.sol" \
  -F "contract_name=VulnerableE2E-IsCanonical-Test" \
  -F "network=ethereum" \
  "https://app.blocksecops.local/api/v1/upload"

# 2. Create scan with multiple scanners
curl -sk -H "X-API-Key: $API_KEY" \
  -X POST -H "Content-Type: application/json" \
  -d '{"contract_id":"<id>","scan_type":"custom","scanner_ids":["slither","semgrep","aderyn"],"scan_source":"cli"}' \
  "https://app.blocksecops.local/api/v1/scans"

# 3. Query vulnerabilities and verify is_canonical
curl -sk -H "X-API-Key: $API_KEY" \
  "https://app.blocksecops.local/api/v1/vulnerabilities?scan_id=<id>&limit=20" | \
  python3 -c "import sys,json; [print(f'{v[\"title\"][:40]}: is_canonical={v[\"is_canonical\"]}') for v in json.load(sys.stdin)['vulnerabilities']]"

# 4. Verify in Celery worker logs
kubectl logs -n api-service-local -l app.kubernetes.io/name=celery-worker --tail=30 | \
  grep -i "celery-dedup"
```

### 4.2 Results — Initial Test (February 24, 2026)

| Metric | Value |
|--------|-------|
| Contract | CeleryDedupTest (reentrancy, tx.origin, unchecked returns) |
| Scanners | slither + semgrep |
| Vulnerabilities found | 16 |
| Worker processing time | 9.8s for 11 vulns |
| Intra-scan groups created | 1 |
| Duplicates identified | 1 |
| Embeddings generated | 4 |
| API pod healthy throughout | Yes |

### 4.3 Results — is_canonical E2E Verification (February 24, 2026)

| Metric | Value |
|--------|-------|
| Contract | VulnerableE2E-IsCanonical-Test (reentrancy, tx.origin, unchecked send) |
| Scanners | slither + semgrep + aderyn |
| Vulnerabilities found | 13 (2 critical, 2 high, 2 medium, 7 low) |
| `is_canonical` in API response | `true` for all 13 findings |
| `is_primary` leaked to response | **No** — field correctly aliased |
| Fuzzy fingerprints | 13/13 |
| Semantic fingerprints | 13/13 |
| Celery cross-scan dedup | Completed (0 matches — first scan for contract) |
| Celery post-scan maintenance | Completed in 1.8s |
| API pod healthy throughout | Yes |

**JSON field verification:**
```json
{
  "title": "Reentrancy Attack (Ether)",
  "severity": "critical",
  "is_canonical": true,
  "deduplication_group_id": null
}
// "is_primary" does NOT appear in response
```

---

## 5. Database Verification

```sql
-- Verify is_primary column has correct values
SELECT title, is_primary, deduplication_group_id IS NOT NULL as has_group
FROM vulnerabilities
WHERE deduplication_group_id IS NOT NULL
ORDER BY deduplication_group_id, is_primary DESC
LIMIT 10;

-- Verify no NULL UUIDs from init-time fix
SELECT COUNT(*) as null_id_count
FROM vulnerabilities WHERE id IS NULL;
-- Expected: 0
```

---

## Related Documentation

- [Changelog: v0.29.13-v0.29.19](../changelogs/API-SERVICE-V0.29.13-V0.29.19-CELERY-DEDUP-SCHEMA-FIX-2026-02-24.md)
- [Deduplication Workflow](../workflows/deduplication-workflow.md)
- [Deduplication Pipeline](../pipelines/deduplication-pipeline.md)
- [Deduplication Playbook](../playbooks/deduplication-maintenance.md)
