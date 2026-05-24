# Playbook: Scanner Data Audit

**Version:** 1.1.0
**Last Updated:** February 19, 2026

## Overview

This playbook provides a systematic audit of scanner data integrity, pattern mappings, fingerprints, deduplication groups, and ConfigMap consistency. Run this audit after scanner upgrades, clean-slate operations, or periodically to detect data drift.

---

## Prerequisites

- [ ] PostgreSQL accessible (kubectl exec or port-forward)
- [ ] API service running (v0.28.54+)
- [ ] Tool-integration service running
- [ ] Valid JWT token for API authentication (Supabase)
- [ ] Admin session for pattern audit (see [Admin Session Setup](#admin-session-setup-for-pattern-audit))
- [ ] Database backup created before any fixes

---

## Quick Reference

```bash
# Full audit cycle
1. Pre-flight: service health checks
2. Scanner data overview (vuln counts, missing fields)
3. ConfigMap version consistency check
4. Fingerprint coverage analysis
5. Pattern mapping gap analysis
6. Deduplication group integrity check
7. Scan severity count accuracy check
8. API endpoint verification
9. ML training data review
10. Generate report and prioritize fixes
```

---

## Phase 1: Pre-Flight Checks

### 1.1 Service Health

```bash
# API Service
curl -sL https://app.0xapogee.com/api/v1/health/ready | jq '.'

# Tool Integration (from inside pod)
kubectl exec -n tool-integration-local deployment/tool-integration -- \
  curl -s http://localhost:8005/health

# PostgreSQL
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c "SELECT 1 AS connected;"
```

### 1.2 Get Auth Token

```bash
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')
TOKEN=$(curl -s "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"<EMAIL>","password":"<PASSWORD>"}' | jq -r '.access_token')
```

### 1.3 Database Backup

```bash
kubectl exec -n postgresql-local postgresql-0 -- pg_dump \
  -U blocksecops -d solidity_security -F c \
  -f /tmp/pre_audit_backup.dump
kubectl cp postgresql-local/postgresql-0:/tmp/pre_audit_backup.dump \
  ~/backups/solidity_security_$(date +%Y%m%d_%H%M%S)_pre_audit.dump
```

---

## Phase 2: Scanner Data Overview

### 2.1 Vulnerability Counts and Missing Fields

```sql
SELECT
  scanner_id,
  COUNT(*) AS total_vulns,
  COUNT(*) FILTER (WHERE fingerprint_composite IS NULL OR fingerprint_composite = '') AS missing_fingerprint,
  COUNT(*) FILTER (WHERE pattern_id IS NULL OR pattern_id = '') AS missing_pattern,
  COUNT(*) FILTER (WHERE deduplication_group_id IS NULL) AS ungrouped
FROM vulnerabilities
GROUP BY scanner_id
ORDER BY total_vulns DESC;
```

**What to look for:**
- `missing_fingerprint` should be 0 (or near 0) for all scanners
- `missing_pattern` should be 0 for scanners with mapped detectors
- `ungrouped` near 0 indicates healthy deduplication

### 2.2 Severity Distribution

```sql
SELECT scanner_id, severity, COUNT(*) AS cnt
FROM vulnerabilities
GROUP BY scanner_id, severity
ORDER BY scanner_id, severity;
```

**What to look for:**
- No `info` or `informational` severity values (not in DB enum)
- Distribution should match expected scanner behavior

### 2.3 Data Integrity Checks

```sql
-- NULL scanner_id or category
SELECT COUNT(*) AS null_scanner FROM vulnerabilities
WHERE scanner_id IS NULL OR scanner_id = '';

SELECT COUNT(*) AS null_category FROM vulnerabilities
WHERE category IS NULL OR category = '';

-- Orphaned dedup groups (canonical points to deleted vuln)
SELECT COUNT(*) AS orphaned_groups
FROM deduplication_groups dg
LEFT JOIN vulnerabilities v ON dg.canonical_finding_id = v.id
WHERE v.id IS NULL;
```

**Expected:** All counts should be 0.

---

## Phase 3: Scanner Version Consistency

### 3.1 Verify API Response Shows Live Versions

api-service fetches version/developer metadata from tool-integration at runtime (5-minute TTL cache). The API response should always reflect the current tool-integration state without requiring a pod restart or ConfigMap sync.

```bash
curl -sk "https://app.0xapogee.com/api/v1/scanners" \
  -H "Authorization: Bearer $TOKEN" | jq '[.scanners[] | {id, version}]'
```

**Compare against tool-integration source of truth:**

```bash
kubectl get cm scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_METADATA}' | jq 'to_entries[] | "\(.key): \(.value.version)"' -r
```

**What to look for:** API response versions should match tool-integration's ConfigMap. If they don't, wait 5 minutes (TTL cache) and retry. If still mismatched, check the fallback chain below.

### 3.2 Diagnose Stale Versions

If api-service returns stale versions after the cache TTL:

1. **Check tool-integration is reachable:** `kubectl logs -n api-service-prod -l app.kubernetes.io/name=api-service --tail=50 | grep "tool-integration"`
2. **Check fallback source:** api-service falls back to the `scanner_versions` DB table, then to the `SCANNER_METADATA` env var (startup ConfigMap bake), then to `"unknown"`.
3. **Verify DB table:** `SELECT scanner_name, current_version FROM scanner_versions;` — updated during admin dashboard upgrades.
4. **No manual ConfigMap sync is needed.** The api-service ConfigMap is a startup fallback only, not the UI source of truth.

---

## Phase 4: Fingerprint Coverage

### 4.1 Fingerprint Field Breakdown

```sql
SELECT scanner_id,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE fingerprint_code IS NOT NULL AND fingerprint_code != '') AS fp_code,
  COUNT(*) FILTER (WHERE fingerprint_ast IS NOT NULL AND fingerprint_ast != '') AS fp_ast,
  COUNT(*) FILTER (WHERE fingerprint_location IS NOT NULL AND fingerprint_location != '') AS fp_location,
  COUNT(*) FILTER (WHERE fingerprint_semantic IS NOT NULL AND fingerprint_semantic != '') AS fp_semantic,
  COUNT(*) FILTER (WHERE fingerprint_composite IS NOT NULL AND fingerprint_composite != '') AS fp_composite
FROM vulnerabilities
GROUP BY scanner_id
ORDER BY scanner_id;
```

**What to look for:**
- `fp_composite` should be populated for all vulnerabilities with `fp_code` or `fp_location`
- If `fp_composite` is 0 but components exist, dedup maintenance backfill is needed
- If a scanner has near-zero fingerprints (all components), the scanner wrapper may not be generating them

### 4.2 Fix: Run Fingerprint Backfill

```bash
# Via API endpoint
curl -sk -X POST "https://app.0xapogee.com/api/v1/deduplication/maintenance/run-full-backfill" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

Or via CLI:

```bash
cd /home/pwner/Git/blocksecops-api-service
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python -c "
from src.infrastructure.tasks.deduplication_maintenance import run_full_maintenance
import asyncio
asyncio.run(run_full_maintenance())
"
```

---

## Admin Session Setup for Pattern Audit

The admin pattern audit endpoint requires full admin authentication. Set up before Phase 5:

```bash
# 1. Ensure user has admin flags
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
UPDATE users SET is_superuser = true, admin_role = 'platform_admin', admin_mfa_enabled = true
WHERE email = '<ADMIN_EMAIL>';"

# 2. Create MFA-verified admin session
# Token is stored as SHA-256 hex digest; raw token passed in X-Admin-Session header
RAW_TOKEN="admin-audit-$(date +%Y-%m-%d)"
HASHED=$(echo -n "$RAW_TOKEN" | sha256sum | awk '{print $1}')
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
INSERT INTO admin_sessions (user_id, session_token, ip_address, mfa_verified, mfa_verified_at, expires_at, last_activity)
SELECT id, '$HASHED', '10.244.0.1', true, NOW(), NOW() + INTERVAL '4 hours', NOW()
FROM users WHERE email = '<ADMIN_EMAIL>';"

# 3. Verify
curl -sk 'https://app.0xapogee.com/api/v1/admin/patterns/mappings/audit' \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Admin-Session: $RAW_TOKEN" | jq '.total_unmapped'
```

> **IP binding:** Traefik forwards client IP as `10.244.0.1` (pod network). The admin session must match this IP. If accessing directly (port-forward), use `127.0.0.1` instead.

---

## Phase 5: Pattern Mapping Gaps

### 5.1 Find Unmapped Detectors

**Via Admin API (recommended):**

```bash
curl -sk "https://app.0xapogee.com/api/v1/admin/patterns/mappings/audit?limit=100" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Admin-Session: $RAW_TOKEN" | jq '.unmapped[] | "\(.scanner_id) / \(.detector_id): \(.finding_count) findings"' -r
```

> **Note:** Requires `is_superuser=true` + `admin_role='platform_admin'` + MFA-verified admin session with matching IP. See [Admin Session Setup](#admin-session-setup-for-pattern-audit) above.

**Via SQL (alternative):**

```sql
SELECT v.scanner_id, v.category AS detector_id, COUNT(*) AS vuln_count
FROM vulnerabilities v
LEFT JOIN pattern_tool_mappings ptm
  ON v.scanner_id = ptm.scanner_id AND v.category = ptm.detector_id
WHERE ptm.id IS NULL
  AND v.category IS NOT NULL AND v.category != ''
GROUP BY v.scanner_id, v.category
ORDER BY v.scanner_id, vuln_count DESC;
```

### 5.2 Check Mapping Status Per Category

```sql
SELECT v.scanner_id, v.category,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pattern_tool_mappings ptm
      WHERE ptm.scanner_id = v.scanner_id AND ptm.detector_id = v.category
    ) THEN 'MAPPED'
    ELSE 'UNMAPPED'
  END AS mapping_status,
  COUNT(*) AS vuln_count,
  COUNT(*) FILTER (WHERE v.pattern_id IS NOT NULL AND v.pattern_id != '') AS has_pattern_id
FROM vulnerabilities v
GROUP BY v.scanner_id, v.category
ORDER BY v.scanner_id, vuln_count DESC;
```

**What to look for:**
- High-count UNMAPPED categories indicate scanner wrappers outputting broad category names instead of specific detector IDs
- `has_pattern_id` > 0 for UNMAPPED categories means some vulns were assigned patterns through other mechanisms

### 5.3 Pattern Mapping Coverage Summary

```sql
SELECT ptm.scanner_id, COUNT(DISTINCT ptm.detector_id) AS mapped_detectors
FROM pattern_tool_mappings ptm
WHERE ptm.is_active = true
GROUP BY ptm.scanner_id
ORDER BY ptm.scanner_id;
```

### 5.4 Fix: Seed Missing Patterns

```bash
cd /home/pwner/Git/blocksecops-api-service

# Dry-run
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <scanner_id> --dry-run

# Apply
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <scanner_id> --apply
```

---

## Phase 6: Deduplication Group Integrity

### 6.1 Group Size Mismatches

```sql
SELECT dg.id, dg.group_size AS recorded_size,
  (SELECT COUNT(*) FROM vulnerabilities v
   WHERE v.deduplication_group_id = dg.id) AS actual_size,
  dg.strategy
FROM deduplication_groups dg
WHERE dg.group_size != (
  SELECT COUNT(*) FROM vulnerabilities v
  WHERE v.deduplication_group_id = dg.id
)
ORDER BY dg.group_size DESC;
```

### 6.2 Fix: Recalculate Group Sizes

```sql
-- MANDATORY: Create backup before running
UPDATE deduplication_groups
SET group_size = (
  SELECT COUNT(*) FROM vulnerabilities
  WHERE deduplication_group_id = deduplication_groups.id
)
WHERE group_size != (
  SELECT COUNT(*) FROM vulnerabilities
  WHERE deduplication_group_id = deduplication_groups.id
);
```

### 6.3 Verify Fix

```sql
SELECT COUNT(*) AS remaining_mismatches
FROM deduplication_groups dg
WHERE dg.group_size != (
  SELECT COUNT(*) FROM vulnerabilities v
  WHERE v.deduplication_group_id = dg.id
);
-- Expected: 0
```

---

## Phase 6b: Scan Duration Integrity

### 6b.1 Find Scans Missing Duration

```sql
SELECT COUNT(*) AS missing_duration
FROM scans
WHERE started_at IS NOT NULL AND completed_at IS NOT NULL AND duration_seconds IS NULL;
```

### 6b.2 Fix: Backfill Duration Seconds

```sql
UPDATE scans SET duration_seconds = EXTRACT(EPOCH FROM (completed_at - started_at))::int
WHERE started_at IS NOT NULL AND completed_at IS NOT NULL AND duration_seconds IS NULL;
```

**Expected:** 0 missing after backfill. New scans automatically persist `duration_seconds` at completion (API service 0.28.53+, orchestration 0.9.16+).

---

## Phase 6c: Solana Pattern CWE Coverage

### 6c.1 Check CWE Coverage by Ecosystem

```sql
SELECT
  CASE
    WHEN id LIKE 'BVD-SOLANA-%' THEN 'Solana'
    WHEN id LIKE 'BVD-SOLIDITY-%' THEN 'Solidity'
    WHEN id LIKE 'BVD-EVM-%' THEN 'EVM'
    ELSE 'Other'
  END AS ecosystem,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE cwe_id IS NOT NULL) AS has_cwe
FROM vulnerability_patterns
GROUP BY 1 ORDER BY 1;
```

**Expected:** All Solana patterns should have CWE IDs (mapped from `cwe_ids` array in pattern JSON). If missing, re-run the Solana CWE mapping:

```bash
cd /home/pwner/Git/blocksecops-api-service
python3 scripts/intelligence/seed_solana_direct.py | kubectl exec -i -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security
```

---

## Phase 7: Scan Severity Count Accuracy

### 7.1 Find Scans with Wrong Counts

```sql
SELECT s.id,
  s.critical_count, s.high_count, s.medium_count, s.low_count,
  (SELECT COUNT(*) FROM vulnerabilities v WHERE v.scan_id = s.id AND v.severity = 'critical') AS actual_critical,
  (SELECT COUNT(*) FROM vulnerabilities v WHERE v.scan_id = s.id AND v.severity = 'high') AS actual_high,
  (SELECT COUNT(*) FROM vulnerabilities v WHERE v.scan_id = s.id AND v.severity = 'medium') AS actual_medium,
  (SELECT COUNT(*) FROM vulnerabilities v WHERE v.scan_id = s.id AND v.severity = 'low') AS actual_low
FROM scans s
WHERE s.critical_count != (SELECT COUNT(*) FROM vulnerabilities v WHERE v.scan_id = s.id AND v.severity = 'critical')
   OR s.high_count != (SELECT COUNT(*) FROM vulnerabilities v WHERE v.scan_id = s.id AND v.severity = 'high')
   OR s.medium_count != (SELECT COUNT(*) FROM vulnerabilities v WHERE v.scan_id = s.id AND v.severity = 'medium')
   OR s.low_count != (SELECT COUNT(*) FROM vulnerabilities v WHERE v.scan_id = s.id AND v.severity = 'low');
```

### 7.2 Fix: Recalculate Severity Counts

```sql
UPDATE scans SET
  critical_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'critical'),
  high_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'high'),
  medium_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'medium'),
  low_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'low')
WHERE critical_count != (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'critical')
   OR high_count != (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'high')
   OR medium_count != (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'medium')
   OR low_count != (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'low');
```

---

## Phase 8: API Endpoint Verification

### 8.1 Scanner List

```bash
curl -sk "https://app.0xapogee.com/api/v1/scanners" \
  -H "Authorization: Bearer $TOKEN" | jq '{count: (.scanners | length), ids: [.scanners[].id]}'
```

### 8.2 Scanner Effectiveness

```bash
curl -sk "https://app.0xapogee.com/api/v1/analytics/scanner-effectiveness" \
  -H "Authorization: Bearer $TOKEN" | \
  jq '.scanners[] | {scanner_id, total_findings, unique_findings, overlap_rate, false_positive_rate}'
```

**What to look for:**
- All scanners with data should appear
- `overlap_rate` and `false_positive_rate` should not be NULL

### 8.3 Deduplication Groups

```bash
# Valid severity filter
curl -sk "https://app.0xapogee.com/api/v1/deduplication/groups?severity=high" \
  -H "Authorization: Bearer $TOKEN" | jq '{total: .total}'

# Invalid severity should return 422
curl -sk "https://app.0xapogee.com/api/v1/deduplication/groups?severity=info" \
  -H "Authorization: Bearer $TOKEN" | jq '.detail'
```

### 8.4 Tool Integration Scanner Health

```bash
kubectl exec -n tool-integration-local deployment/tool-integration -- \
  curl -s http://localhost:8005/scanners/health | jq '.scanners | to_entries[] | {scanner: .key, status: .value.status, version: .value.version}'
```

---

## Phase 9: ML Training Data Review

### 9.1 Label Distribution by Scanner

```sql
SELECT scanner_id, user_classification, COUNT(*)
FROM vulnerabilities
WHERE user_classification IS NOT NULL
GROUP BY scanner_id, user_classification
ORDER BY scanner_id, user_classification;
```

**What to look for:**
- Minimum 50 labeled vulnerabilities for ML training
- Balanced distribution between `confirmed` and `false_positive`
- All active scanners should have some labels
- Heavy imbalance (e.g., 90% FP for one scanner) may indicate bulk labeling from a prior operation

---

## Audit Report Template

```markdown
## Scanner Data Audit Report — YYYY-MM-DD

### Summary
| Metric | Value |
|--------|-------|
| Total vulnerabilities | |
| Total scans | |
| Total dedup groups | |
| Active scanners with data | |

### Issues Found

#### Issue N: [SEVERITY] — Title
**Impact:** ...
**Fix:** ...
**Status:** Fixed / Pending

### Recommended Actions
1. ...
2. ...
```

---

## Checklist

- [ ] Database backup created before any fixes
- [ ] Service health verified
- [ ] Scanner data overview reviewed
- [ ] ConfigMap versions consistent across services
- [ ] Fingerprint coverage acceptable
- [ ] Unmapped detectors identified and documented
- [ ] Dedup group sizes accurate
- [ ] Scan severity counts accurate
- [ ] API endpoints returning expected data
- [ ] ML training data reviewed
- [ ] Audit report generated
- [ ] Fixes committed via feature branch + PR

---

## Related Documentation

- [Scanner Upgrade Playbook](upgrade-scanner-image.md) - Full scanner upgrade procedure
- [Scanner Upgrade Pipeline](../pipelines/scanner-upgrade-pipeline.md) - Pipeline phases and clean-slate procedure
- [Scanner Data Audit Pipeline](../pipelines/scanner-data-audit-pipeline.md) - Automated pipeline architecture
- [Deduplication Pipeline](../pipelines/deduplication-pipeline.md) - Daily maintenance tasks
- [AI/ML Audit Playbook](ai-ml-audit-playbook.md) - ML-specific audit procedures
- [Database Management Standards](../standards/database-management.md) - Backup requirements
