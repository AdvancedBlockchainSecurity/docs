# Pattern Code Backfill and Column Widening

**Date:** January 16, 2026
**Author:** BlockSecOps Team
**Services Affected:** api-service
**Version:** 0.10.9

## Summary

Fixed the issue where `pattern_code` column on vulnerabilities and deduplication groups was never populated. Created Alembic migration to:
1. Widen `pattern_id` and `pattern_code` columns from varchar(20) to varchar(50) to accommodate longer BVD codes
2. Backfill `pattern_id` and `pattern_code` for existing vulnerabilities using `pattern_tool_mappings`
3. Backfill `pattern_code` for deduplication groups from their canonical findings

## Problem

The deduplication page tiles were showing "Pattern pending classification" instead of BVD pattern codes (e.g., `BVD-SOLIDITY-DEFI-LIQUIDITY-001`). Investigation revealed:
1. `vulnerabilities.pattern_id` was never set during scan ingestion
2. `vulnerabilities.pattern_code` was never set (denormalized copy of pattern_id)
3. `deduplication_groups.pattern_code` was derived from vulnerabilities, so also empty
4. Column width of 20 chars was too narrow for longer BVD codes (up to 34 chars)

## Solution

### Database Migration (033_backfill_pattern_code)

**File:** `alembic/versions/20260116_1000-033_backfill_pattern_code.py`

The migration performs these steps:

1. **Widen columns** - Increase varchar(20) to varchar(50) for both `pattern_id` and `pattern_code` on vulnerabilities table

2. **Backfill vulnerabilities** - Use `pattern_tool_mappings` table to look up pattern_id:
   ```sql
   UPDATE vulnerabilities v
   SET pattern_id = ptm.pattern_id,
       pattern_code = ptm.pattern_id
   FROM pattern_tool_mappings ptm
   WHERE v.scanner_id = ptm.scanner_id
     AND v.title = ptm.detector_id
     AND ptm.is_active = true
     AND (v.pattern_id IS NULL OR v.pattern_id = '')
   ```

3. **Sync pattern_code** - Copy pattern_id to pattern_code for any remaining mismatches

4. **Backfill deduplication_groups** - Get pattern_code from canonical finding:
   ```sql
   UPDATE deduplication_groups dg
   SET pattern_code = v.pattern_code
   FROM vulnerabilities v
   WHERE dg.canonical_finding_id = v.id
     AND v.pattern_code IS NOT NULL
     AND (dg.pattern_code IS NULL OR dg.pattern_code = '')
   ```

## Changes

### Files Modified

| Repository | File | Change |
|------------|------|--------|
| blocksecops-api-service | `alembic/versions/20260116_1000-033_backfill_pattern_code.py` | NEW - Data migration for pattern code backfill |
| blocksecops-api-service | `pyproject.toml` | Version bump 0.10.8 -> 0.10.9 |
| blocksecops-api-service | `k8s/overlays/local/api-service/kustomization.yaml` | Updated newTag to 0.10.9 |

## Results

After running the migration:

| Metric | Before | After |
|--------|--------|-------|
| Vulnerabilities with pattern_id | 0 | 5,002 |
| Deduplication groups with pattern_code | 0 | 79 |
| Total deduplication groups | 137 | 137 |

Sample BVD codes now visible on deduplication page:
- `BVD-SOLIDITY-DEFI-LIQUIDITY-001`
- `BVD-SOLIDITY-VAL-001`
- `BVD-SOLIDITY-DEFI-VAULT-001`
- `BVD-SOLIDITY-MEV-003`
- `BVD-SOLIDITY-QUALITY-001`

## Deployment

```bash
cd /home/pwner/Git/blocksecops-api-service

# Build image (use cache for faster builds in local dev)
docker build -t blocksecops-api-service:0.10.9 .

# Import to containerd (kubeadm environment)
docker save blocksecops-api-service:0.10.9 | sudo ctr -n k8s.io images import -

# Apply kustomization
kubectl apply -k k8s/overlays/local/api-service/

# Restart deployment
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local
```

## Verification

### Database Verification

```sql
-- Check vulnerabilities backfill (should be 0)
SELECT COUNT(*) FROM vulnerabilities
WHERE pattern_id IS NOT NULL AND pattern_code IS NULL;

-- Check deduplication groups (should show BVD codes)
SELECT pattern_code FROM deduplication_groups
WHERE pattern_code IS NOT NULL LIMIT 10;
```

### UI Verification

1. Navigate to `http://app.blocksecops.local/deduplication`
2. Verify tiles show BVD codes instead of "Pattern pending classification"

## Rollback

If issues occur:

```bash
# Rollback migration
cd /home/pwner/Git/blocksecops-api-service
source .venv/bin/activate
alembic downgrade 032_add_quality_gates

# Redeploy previous version
# Update kustomization.yaml to 0.10.8
kubectl apply -k k8s/overlays/local/api-service/
kubectl rollout restart deployment/api-service -n api-service-local
```

## Related Documentation

- [Intelligence Integration Standards](/docs/standards/INTELLIGENCE-INTEGRATION-STANDARDS.md)
- [Database Migrations](/docs/database/MIGRATIONS.md)
- [Pattern Code Convention](/docs/intelligence/README.md#pattern-code-convention)

## Notes

- The migration is idempotent - running it multiple times is safe
- 58 deduplication groups (137-79=58) still show "Pattern pending classification" because their vulnerabilities don't have mappings in `pattern_tool_mappings`
- Future scans will automatically populate pattern_code during ingestion (code change pending)
