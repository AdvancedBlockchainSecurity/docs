# Deduplication & Vulnerability Metadata Audit Fixes

**Date:** February 4, 2026
**Version:** API Service v0.25.1, Tool Integration v0.3.9
**Type:** Bug Fix / Enhancement

---

## Summary

Comprehensive fixes for 27 issues identified in the deduplication, patterns, vulnerability entries, and metadata systems audit. Fixes span database models, scanner parsers, and API endpoints.

---

## Critical Fixes

### 1. String Length Mismatch - DATA TRUNCATION (Fixed)

**Location:** `blocksecops-api-service/src/infrastructure/database/models.py:784-789`

**Problem:** `pattern_id` and `pattern_code` columns were defined as `String(20)`, causing truncation of pattern IDs like "BVD-SOLANA-CPI-001" (21+ chars).

**Fix:** Changed to `String(50)` to accommodate all pattern ID formats.

```python
# Before
pattern_id: Mapped[Optional[str]] = mapped_column(String(20), ...)

# After
pattern_id: Mapped[Optional[str]] = mapped_column(String(50), ...)
```

**Migration Required:** Yes - column type change

### 2. MythrilParser Returns Empty Results (Fixed)

**Location:** `blocksecops-tool-integration/src/scanners/parser.py:253-303`

**Problem:** MythrilParser never populated the vulnerabilities list, returning empty results for all scans.

**Fix:** Complete rewrite of MythrilParser with:
- Full JSON output parsing (Mythril's `--json` format)
- Legacy text format fallback
- SWC-ID to severity mapping (36 SWC IDs)
- Code snippet extraction from `code` field
- Comprehensive recommendations per SWC-ID

---

## High Priority Fixes

### 3. Missing FK Constraint on pattern_id (Fixed)

**Location:** `models.py` - VulnerabilityModel

**Fix:** Added ForeignKey constraint:
```python
pattern_id: Mapped[Optional[str]] = mapped_column(
    String(50), ForeignKey("vulnerability_patterns.id", ondelete="SET NULL"),
    nullable=True, index=True
)
```

### 4. Missing FK Constraint on deduplication_group_id (Fixed)

**Location:** `models.py` - VulnerabilityModel

**Fix:** Added ForeignKey constraint:
```python
deduplication_group_id: Mapped[Optional[Uuid]] = mapped_column(
    Uuid, ForeignKey("deduplication_groups.id", ondelete="SET NULL"),
    nullable=True, index=True
)
```

### 5. Orphaned Records on Cascade Delete (Fixed)

**Location:** `blocksecops-api-service/src/infrastructure/database/specialized_models/intelligence.py:126`

**Problem:** DeduplicationGroupModel used `CASCADE` on `canonical_finding_id`, which conflicts with soft-delete strategy for vulnerabilities.

**Fix:** Changed to `SET NULL`:
```python
canonical_finding_id: Mapped[UUID | None] = mapped_column(
    PG_UUID(as_uuid=True), ForeignKey("vulnerabilities.id", ondelete="SET NULL"), nullable=True
)
```

### 6. Missing ORM Relationships (Fixed)

**Location:** `models.py` - VulnerabilityModel

**Fix:** Added relationships for ORM navigation:
```python
deduplication_group = relationship(
    "DeduplicationGroupModel",
    foreign_keys=[deduplication_group_id],
    lazy="selectin",
    uselist=False,
)
pattern = relationship(
    "VulnerabilityPatternModel",
    foreign_keys=[pattern_id],
    lazy="selectin",
    uselist=False,
)
```

### 7. Bidirectional Relationship Added

**Location:** `intelligence.py` - DeduplicationGroupModel

**Fix:** Added `vulnerabilities` relationship for reverse navigation:
```python
vulnerabilities = relationship(
    "VulnerabilityModel",
    foreign_keys="VulnerabilityModel.deduplication_group_id",
    back_populates="deduplication_group",
    lazy="selectin",
)
```

---

## Medium Priority Fixes

### 8. SWC-ID Mapping Implemented

**Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:1905`

**Fix:**
- Updated `_lookup_pattern_category()` to also return `swc_id` from pattern database
- Added `DETECTOR_TO_SWC_FALLBACK` dictionary with 45+ detector-to-SWC mappings
- Added `_get_swc_id_fallback()` function for partial matching
- Vulnerabilities now have `swc_id` populated from pattern lookup or fallback

### 9. Pattern avg_time_to_fix Calculated

**Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/patterns.py:396`

**Fix:** Implemented calculation from `detected_at` to `fix_verified_at` or `updated_at`:
```python
fix_times_hours = []
for v in vulnerabilities:
    if v.status == "fixed" and v.detected_at:
        fix_timestamp = getattr(v, 'fix_verified_at', None) or v.updated_at
        if fix_timestamp and fix_timestamp > v.detected_at:
            delta = fix_timestamp - v.detected_at
            fix_times_hours.append(delta.total_seconds() / 3600)
avg_time_to_fix = round(sum(fix_times_hours) / len(fix_times_hours), 1) if fix_times_hours else None
```

### 10. Missing Database Indexes Added

**Location:** `models.py` - VulnerabilityModel

**Fix:** Added indexes to frequently filtered/aggregated fields:
- `classification_confidence` (index=True)
- `classification_method` (index=True)
- `deduplication_strategy` (index=True)
- `similarity_score` (index=True)
- `multi_class_model_version` (index=True)

### 11. Code Snippet Extraction Improved

**Location:** `blocksecops-tool-integration/src/scanners/parser.py`

**Fix:** Improved code_snippet extraction in 6 parsers:

| Parser | Before | After |
|--------|--------|-------|
| SlitherParser | Function name only | Elements (function, expression, variable, contract) |
| AderynParser | None | `src` field or `hint` as fallback |
| MythrilParser | None | `code` field from JSON |
| EchidnaParser | None | Counterexample/call_sequence |
| MedusaParser | None | Location code, function, or counterexample |

---

## Files Modified

### blocksecops-api-service

| File | Changes |
|------|---------|
| `src/infrastructure/database/models.py` | String(50), FK constraints, indexes, relationships |
| `src/infrastructure/database/specialized_models/intelligence.py` | CASCADE → SET NULL, bidirectional relationship |
| `src/presentation/api/v1/endpoints/scans.py` | SWC-ID mapping with cache and fallback |
| `src/presentation/api/v1/endpoints/patterns.py` | avg_time_to_fix calculation |

### blocksecops-tool-integration

| File | Changes |
|------|---------|
| `src/scanners/parser.py` | MythrilParser rewrite, code_snippet improvements |

---

## Database Migration Required

A migration is required for the following changes:

```sql
-- Change pattern_id and pattern_code column lengths
ALTER TABLE vulnerabilities ALTER COLUMN pattern_id TYPE VARCHAR(50);
ALTER TABLE vulnerabilities ALTER COLUMN pattern_code TYPE VARCHAR(50);

-- Add FK constraints (if not already present)
ALTER TABLE vulnerabilities
ADD CONSTRAINT fk_vuln_pattern
FOREIGN KEY (pattern_id) REFERENCES vulnerability_patterns(id) ON DELETE SET NULL;

ALTER TABLE vulnerabilities
ADD CONSTRAINT fk_vuln_dedup_group
FOREIGN KEY (deduplication_group_id) REFERENCES deduplication_groups(id) ON DELETE SET NULL;

-- Change canonical_finding_id to nullable with SET NULL
ALTER TABLE deduplication_groups ALTER COLUMN canonical_finding_id DROP NOT NULL;
ALTER TABLE deduplication_groups
DROP CONSTRAINT IF EXISTS deduplication_groups_canonical_finding_id_fkey;
ALTER TABLE deduplication_groups
ADD CONSTRAINT deduplication_groups_canonical_finding_id_fkey
FOREIGN KEY (canonical_finding_id) REFERENCES vulnerabilities(id) ON DELETE SET NULL;

-- Add new indexes
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_classification_confidence ON vulnerabilities(classification_confidence);
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_classification_method ON vulnerabilities(classification_method);
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_deduplication_strategy ON vulnerabilities(deduplication_strategy);
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_similarity_score ON vulnerabilities(similarity_score);
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_multi_class_model_version ON vulnerabilities(multi_class_model_version);
```

---

## Testing

### Verify String Length Fix
```sql
-- Should return patterns that would have been truncated
SELECT id FROM vulnerability_patterns WHERE LENGTH(id) > 20;
```

### Verify FK Constraint
```sql
-- Should fail with FK violation
INSERT INTO vulnerabilities (pattern_id, ...) VALUES ('nonexistent-pattern', ...);
```

### Verify MythrilParser
```bash
# Run a Mythril scan and verify vulnerabilities are returned
curl -X POST http://127.0.0.1:8000/api/v1/scans/{scan_id}/results \
  -H "Content-Type: application/json" \
  -d '{"scanner": "mythril", "status": "completed", "vulnerabilities": [...]}'
```

### Verify SWC-ID Mapping
```bash
# Check that vulnerabilities have swc_id populated
curl http://127.0.0.1:8000/api/v1/vulnerabilities | jq '.[0].swc_id'
```

### Verify ORM Relationships
```python
# Should work after fix
vuln = await db.get(VulnerabilityModel, vuln_id)
group = vuln.deduplication_group  # ORM navigation
pattern = vuln.pattern  # ORM navigation
```

---

## Deployment

```bash
# API Service
cd /home/pwner/Git/blocksecops-api-service
docker build --no-cache -t harbor.0xapogee.local/blocksecops/api-service:0.25.1 .
docker push harbor.0xapogee.local/blocksecops/api-service:0.25.1
kubectl rollout restart deployment/blocksecops-api-service -n blocksecops-api-service-local

# Tool Integration
cd /home/pwner/Git/blocksecops-tool-integration
docker build --no-cache -t harbor.0xapogee.local/blocksecops/tool-integration:0.3.9 .
docker push harbor.0xapogee.local/blocksecops/tool-integration:0.3.9
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

---

## Related

- [Cross-Scan Deduplication](./CROSS-SCAN-DEDUPLICATION-2026-02-04.md)
- [Intelligence Layer Documentation](../intelligence/README.md)
- [Database Schema](../database/SCHEMA.md)
