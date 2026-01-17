# Deduplication Pattern Codes

## Deduplication Page Overview
**How to test**: Navigate to `/deduplication`

- [ ] Page loads with deduplication groups
- [ ] Group tiles/cards display correctly
- [ ] Each tile shows pattern code or "Pattern pending classification"
- [ ] Severity badge is displayed
- [ ] Finding count is shown

## Pattern Code Display
**How to test**: Check the pattern code on each deduplication group tile

- [ ] Groups with pattern mappings show BVD codes (e.g., `BVD-SOLIDITY-DEFI-LIQUIDITY-001`)
- [ ] Groups without pattern mappings show "Pattern pending classification"
- [ ] Pattern code format is `BVD-<CHAIN>-<CATEGORY>-<NUMBER>` (e.g., `BVD-SOLIDITY-REE-001`)
- [ ] Long pattern codes display without truncation or overflow

## Expected BVD Pattern Codes
**How to test**: Verify these common pattern codes appear correctly

- [ ] `BVD-SOLIDITY-REE-001` - Reentrancy
- [ ] `BVD-SOLIDITY-ACC-001` - Access Control
- [ ] `BVD-SOLIDITY-VAL-001` - Validation
- [ ] `BVD-SOLIDITY-DEFI-LIQUIDITY-001` - DeFi Liquidity (34 chars - tests column width)
- [ ] `BVD-SOLIDITY-DEFI-VAULT-001` - DeFi Vault
- [ ] `BVD-SOLIDITY-MEV-003` - MEV
- [ ] `BVD-SOLIDITY-QUALITY-001` - Code Quality

## Group Detail View
**How to test**: Click on a deduplication group to view details

- [ ] Pattern code is displayed in group details
- [ ] Pattern description is shown (if available)
- [ ] Related vulnerabilities list shows pattern codes
- [ ] Canonical finding has matching pattern code

---

## API Endpoints

### GET /api/v1/deduplication/groups
**How to test**:
```bash
curl "http://app.blocksecops.local/api/v1/deduplication/groups" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns array of deduplication groups
- [ ] Each group has `pattern_code` field (may be null)
- [ ] Groups with mappings have non-null `pattern_code`
- [ ] `pattern_code` values match BVD format
- [ ] Returns 401 if not authenticated

### Response Schema Validation
**How to test**: Validate response structure

- [ ] Each group has `id` (UUID)
- [ ] Each group has `pattern_code` (string or null)
- [ ] Each group has `severity` (critical, high, medium, low, informational)
- [ ] Each group has `canonical_finding_id` (UUID)
- [ ] Each group has `finding_ids` (array of UUIDs)

---

## Database Verification

### Vulnerability Pattern Codes
**How to test**: Run SQL query
```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT COUNT(*) as total, COUNT(pattern_code) as with_pattern FROM vulnerabilities;"
```

- [ ] Majority of vulnerabilities have `pattern_code` populated
- [ ] `pattern_code` matches `pattern_id` (denormalized)
- [ ] Pattern codes are varchar(50) (not truncated)

### Deduplication Group Pattern Codes
**How to test**: Run SQL query
```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT COUNT(*) as total, COUNT(pattern_code) as with_pattern FROM deduplication_groups;"
```

- [ ] Deduplication groups with canonical findings have `pattern_code`
- [ ] Pattern codes derive from canonical finding's `pattern_code`
- [ ] 79+ groups should have pattern codes (as of January 2026)

### Pattern Code Consistency
**How to test**: Verify pattern_id = pattern_code
```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT COUNT(*) FROM vulnerabilities WHERE pattern_id IS NOT NULL AND pattern_code IS NOT NULL AND pattern_id != pattern_code;"
```

- [ ] Result should be 0 (pattern_id always equals pattern_code)

---

## Edge Cases

### Long Pattern Codes
**How to test**: Verify codes up to 50 characters display correctly

- [ ] `BVD-SOLIDITY-DEFI-LIQUIDITY-001` (34 chars) displays without truncation
- [ ] UI handles pattern codes gracefully

### Missing Pattern Mappings
**How to test**: Groups without mappings in pattern_tool_mappings

- [ ] Shows "Pattern pending classification" placeholder
- [ ] Does not show error or empty string
- [ ] Clicking group still shows vulnerability details

---

## Bug Fixes (January 2026)

### Pattern Code Backfill (Migration 033)
**Issue**: `pattern_code` was never populated for vulnerabilities or deduplication groups, causing tiles to show "Pattern pending classification" even when pattern mappings existed.

**Root Cause**:
1. `pattern_id` was retrieved from `pattern_tool_mappings` but never assigned to `VulnerabilityModel`
2. `pattern_code` (denormalized copy) was never set
3. `deduplication_groups.pattern_code` derived from empty vulnerability data
4. Column width (varchar 20) was too small for long BVD codes (up to 34 chars)

**Fix Applied**:
1. Widened columns to varchar(50)
2. Backfilled `vulnerabilities.pattern_id` from `pattern_tool_mappings` using `scanner_id + title`
3. Copied `pattern_id` to `pattern_code`
4. Backfilled `deduplication_groups.pattern_code` from canonical findings

**Files Modified**:
- `alembic/versions/20260116_1000-033_backfill_pattern_code.py` (new migration)

**Verification**:
```bash
# Check vulnerabilities backfilled
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT COUNT(*) FROM vulnerabilities WHERE pattern_id IS NOT NULL;"
# Expected: 5000+

# Check deduplication groups backfilled
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT COUNT(*) FROM deduplication_groups WHERE pattern_code IS NOT NULL;"
# Expected: 79+
```

---

## Related Documentation

- [Intelligence Integration Standards](/docs/standards/INTELLIGENCE-INTEGRATION-STANDARDS.md)
- [Pattern Code Backfill Changelog](/docs/changelogs/PATTERN-CODE-BACKFILL-2026-01-16.md)
- [Database Migrations](/docs/database/MIGRATIONS.md#migration-033-pattern-code-backfill)
