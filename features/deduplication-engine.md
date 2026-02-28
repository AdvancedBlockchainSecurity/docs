# Deduplication Engine - Technical Documentation

**Version**: v0.8.0 (core), v0.29.13 (hybrid architecture + GCP audit)
**Status**: Production Ready
**Phase**: 4E - Intelligence Layer

---

## Overview

The Deduplication Engine automatically identifies and groups duplicate vulnerability findings across multiple security scanners, reducing noise and improving the signal-to-noise ratio in security analysis results.

### Key Benefits

- **40-60% reduction** in duplicate findings
- **Improved user experience** with cleaner, consolidated results
- **Cross-scanner intelligence** leveraging strengths of multiple tools
- **Automatic operation** requires no manual intervention
- **Full API access** for manual review and adjustment

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────┐
│         Scan Workflow Pipeline              │
├─────────────────────────────────────────────┤
│ 1. Scanner Execution (Phase 4A)             │
│ 2. Result Parsing (Phase 4B)                │
│ 3. Enrichment + Fingerprinting (Phase 4C/D) │
│ 4. Deduplication (Phase 4E) ← This Module   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│      Deduplication Service                  │
├─────────────────────────────────────────────┤
│ • DeduplicationMatcher                      │
│   - Multi-level fingerprint matching        │
│   - Confidence calculation                  │
│                                             │
│ • DeduplicationService                      │
│   - Workflow orchestration                  │
│   - Group management                        │
│   - Canonical selection                     │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│           Database Layer                    │
├─────────────────────────────────────────────┤
│ • deduplication_groups                      │
│ • deduplication_group_members               │
│ • Automated triggers                        │
└─────────────────────────────────────────────┘
```

---

## Matching Algorithm

### Multi-Level Fingerprint Strategy

The deduplication engine uses a tiered matching approach with four confidence levels:

#### Level 1: EXACT (100% confidence)
**Fingerprints**: `code_hash` + `location_hash`

**When Used**: Identical code at exact same location

**Example**:
```solidity
// Contract A - Line 42
function withdraw() public {
    msg.sender.call{value: balance}("");
}

// Contract A - Line 42 (different scan)
function withdraw() public {
    msg.sender.call{value: balance}("");
}
```

**Match**: ✅ EXACT - Same code, same location

---

#### Level 2: HIGH (95% confidence)
**Fingerprints**: `code_hash` + `location_hash_fuzzy`

**When Used**: Same code with minor location differences (whitespace, comments)

**Example**:
```solidity
// Scan 1 - Line 42
function withdraw() public {
    msg.sender.call{value: balance}("");
}

// Scan 2 - Line 45 (after adding comments)
// Added safety check
function withdraw() public {
    msg.sender.call{value: balance}("");
}
```

**Match**: ✅ HIGH - Same code, fuzzy location match

---

#### Level 3: MEDIUM (80% confidence)
**Fingerprints**: `ast_hash` + `location_hash_fuzzy`

**When Used**: Semantically equivalent code (reformatted, renamed variables)

**Example**:
```solidity
// Scan 1 - Original
function withdraw() public {
    msg.sender.call{value: balance}("");
}

// Scan 2 - Reformatted
function withdraw() public
{
    msg.sender.call{value:balance}("");
}
```

**Match**: ✅ MEDIUM - Same AST structure, fuzzy location

---

#### Level 4: LOW (60% confidence)
**Fingerprints**: `pattern_code` + `location_hash_fuzzy`

**When Used**: Same vulnerability type, similar location

**Example**:
```solidity
// Scan 1 - Slither detects
function withdraw() public {
    msg.sender.call{value: balance}("");
}

// Scan 2 - Mythril detects similar pattern
function transfer() public {
    payable(msg.sender).call{value: amount}("");
}
```

**Match**: ⚠️ LOW - Same pattern (REE-001), needs review

---

## Canonical Finding Selection

When multiple findings are grouped, one is selected as the "canonical" (primary) finding shown to users.

### Selection Algorithm

```python
def select_canonical(findings):
    priority = {
        "slither": 100,    # Most detailed static analysis
        "mythril": 90,     # Symbolic execution insights
        "aderyn": 80,      # Rust-based analysis
        "semgrep": 70,     # Pattern matching
        "default": 50
    }

    for finding in findings:
        scanner_score = priority.get(finding.scanner_id, 50)

        # Count non-null fingerprints
        completeness = count_fingerprints(finding)

        # Sort by: scanner_score DESC, completeness DESC, finding_id ASC

    return highest_scoring_finding
```

### Example Selection

**Group with 3 findings:**
1. Slither - 5 fingerprints - Score: (100, 5, uuid1) → ✅ **CANONICAL**
2. Mythril - 4 fingerprints - Score: (90, 4, uuid2)
3. Semgrep - 3 fingerprints - Score: (70, 3, uuid3)

**Result**: Slither finding selected as canonical (highest scanner priority + completeness)

---

## Database Schema

### deduplication_groups

```sql
CREATE TABLE deduplication_groups (
    id UUID PRIMARY KEY,
    project_id UUID,                              -- Optional project scoping
    canonical_finding_id UUID NOT NULL UNIQUE,    -- Primary finding to show
    pattern_code VARCHAR(20),                     -- E.g., REE-001
    confidence_level VARCHAR(20) NOT NULL,        -- exact, high, medium, low
    matched_fingerprints TEXT,                    -- JSON array
    finding_count INTEGER DEFAULT 0,              -- Auto-maintained
    scanner_count INTEGER DEFAULT 0,              -- Auto-maintained
    first_seen TIMESTAMP WITH TIME ZONE,
    last_seen TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,

    CHECK (confidence_level IN ('exact', 'high', 'medium', 'low'))
);
```

### deduplication_group_members

```sql
CREATE TABLE deduplication_group_members (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES deduplication_groups(id) ON DELETE CASCADE,
    finding_id UUID NOT NULL REFERENCES vulnerabilities(id) ON DELETE CASCADE,
    match_confidence VARCHAR(20) NOT NULL,        -- Individual match confidence
    matched_fingerprints TEXT,                    -- Which fingerprints matched
    is_canonical BOOLEAN DEFAULT FALSE,           -- Is this the canonical finding?
    added_at TIMESTAMP WITH TIME ZONE,

    UNIQUE(group_id, finding_id),
    CHECK (match_confidence IN ('exact', 'high', 'medium', 'low'))
);
```

### Automatic Statistics

Database triggers automatically maintain:
- `finding_count` - Number of findings in group
- `scanner_count` - Number of unique scanners
- `last_seen` - Most recent detection timestamp

---

## API Reference

### Base URL
```
/api/v1/deduplication
```

### Endpoints

#### 1. List Groups
```http
GET /deduplication/groups?project_id={uuid}&limit=100&offset=0&confidence_level=exact
```

**Response**:
```json
{
  "groups": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "canonical_finding_id": "660e8400-e29b-41d4-a716-446655440111",
      "pattern_code": "REE-001",
      "confidence_level": "exact",
      "finding_count": 3,
      "scanner_count": 2,
      "canonical_finding_title": "Reentrancy in withdraw()",
      "canonical_finding_severity": "high"
    }
  ],
  "total": 50,
  "limit": 100,
  "offset": 0
}
```

#### 2. Get Group Details
```http
GET /deduplication/groups/{group_id}
```

**Response**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "pattern_code": "REE-001",
  "confidence_level": "exact",
  "matched_fingerprints": ["code_hash", "location_hash"],
  "findings": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440111",
      "scanner_id": "slither",
      "severity": "high",
      "title": "Reentrancy in withdraw()",
      "file_path": "contracts/Token.sol",
      "line_number": 42,
      "match_confidence": "exact",
      "is_canonical": true
    },
    {
      "id": "770e8400-e29b-41d4-a716-446655440222",
      "scanner_id": "mythril",
      "severity": "high",
      "title": "External call reentrancy",
      "file_path": "contracts/Token.sol",
      "line_number": 42,
      "match_confidence": "exact",
      "is_canonical": false
    }
  ]
}
```

#### 3. Merge Groups
```http
POST /deduplication/groups/merge
Content-Type: application/json

{
  "source_group_id": "550e8400-e29b-41d4-a716-446655440000",
  "target_group_id": "660e8400-e29b-41d4-a716-446655440111"
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Groups merged successfully",
  "target_group_id": "660e8400-e29b-41d4-a716-446655440111",
  "finding_count": 5
}
```

#### 4. Ungroup Finding
```http
DELETE /deduplication/findings/{finding_id}/ungroup
```

**Response**:
```json
{
  "status": "success",
  "message": "Finding removed from group successfully",
  "finding_id": "770e8400-e29b-41d4-a716-446655440222"
}
```

#### 5. Get Statistics
```http
GET /deduplication/stats?project_id={uuid}
```

**Response**:
```json
{
  "total_groups": 50,
  "total_findings_deduplicated": 150,
  "average_group_size": 3.0,
  "confidence_breakdown": {
    "exact": 20,
    "high": 15,
    "medium": 10,
    "low": 5
  }
}
```

---

## Usage Examples

### Programmatic Access

```python
import httpx

async def get_deduplication_groups(project_id: str):
    """Fetch deduplication groups for a project."""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"http://api/v1/deduplication/groups",
            params={"project_id": project_id, "limit": 100}
        )
        return response.json()

async def merge_duplicate_groups(source_id: str, target_id: str):
    """Merge two groups that were incorrectly separated."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "http://api/v1/deduplication/groups/merge",
            json={
                "source_group_id": source_id,
                "target_group_id": target_id
            }
        )
        return response.json()
```

### CLI Access

```bash
# List all deduplication groups
curl http://localhost:8000/api/v1/deduplication/groups

# Get specific group details
curl http://localhost:8000/api/v1/deduplication/groups/{group_id}

# Get statistics
curl http://localhost:8000/api/v1/deduplication/stats
```

---

## Performance Characteristics

### Expected Latency

| Scan Size | Findings | Deduplication Time | Total Overhead |
|-----------|----------|-------------------|----------------|
| Small     | <10      | <1 second         | Negligible     |
| Medium    | 10-100   | 1-5 seconds       | <5%            |
| Large     | 100-1000 | 5-30 seconds      | <10%           |
| Very Large| 1000+    | 30-120 seconds    | <15%           |

### Optimization Strategies

1. **Indexed Queries** - All fingerprint lookups use database indexes
2. **Batch Processing** - Single transaction per scan
3. **Async Execution** - Non-blocking workflow integration
4. **Trigger-based Stats** - Pre-calculated aggregate data

---

## Error Handling

### Graceful Degradation

If deduplication fails, the system:
1. ✅ Logs the error with full context
2. ✅ Continues scan completion normally
3. ✅ Stores all findings without grouping
4. ✅ Returns scan results to user

**No scan is ever blocked by deduplication failures.**

### Common Error Scenarios

#### 1. Database Connection Failure
```python
try:
    await dedup_service.process_scan_findings(scan_id)
except DatabaseError as e:
    logger.warning("deduplication_failed", error=str(e))
    # Continue - findings already stored
```

#### 2. Invalid Fingerprints
```python
# Gracefully handle None/missing fingerprints
if not finding.location_hash_fuzzy:
    logger.debug("skipping_finding_no_fuzzy_location")
    continue  # Skip this finding
```

---

## Monitoring & Metrics

### Key Metrics

Track these metrics for deduplication health:

1. **Deduplication Rate**
   ```
   (total_findings - unique_groups) / total_findings * 100
   ```
   Target: 40-60%

2. **Confidence Distribution**
   - EXACT: 30-40% (highest quality)
   - HIGH: 25-35%
   - MEDIUM: 15-25%
   - LOW: 5-15%

3. **Processing Time**
   - p50: <5 seconds
   - p95: <30 seconds
   - p99: <120 seconds

4. **Error Rate**
   - Target: <1% of scans

### Logging

Structured logs at key points:

```python
logger.info("deduplication_scan_start", scan_id=scan_id)
logger.info("duplicates_found", count=len(duplicates), confidence=highest_confidence)
logger.info("deduplication_completed",
    findings_processed=50,
    groups_created=5,
    groups_updated=3
)
```

---

## Best Practices

### For Users

1. **Review LOW confidence matches** - May require manual verification
2. **Use canonical findings** - Most complete and reliable information
3. **Check group details** - Understand what was matched
4. **Report false positives** - Help improve the system

### For Developers

1. **Always provide fingerprints** - Required for deduplication
2. **Test with multiple scanners** - Validate cross-scanner matching
3. **Monitor confidence distributions** - Detect matching quality issues
4. **Use batch operations** - More efficient than individual queries

---

## Limitations & Known Issues

### Current Limitations

1. **Project scoping optional** - Full cross-project deduplication not yet enforced
2. **Manual review for LOW confidence** - May have false positives
3. **No cross-language support** - Only Solidity currently
4. **No historical analysis** - Groups only current/recent findings

### Future Enhancements

- [ ] Machine learning-based matching refinement
- [ ] User feedback loop for match quality
- [ ] Cross-project deduplication with privacy controls
- [ ] Historical trend analysis
- [ ] Support for Rust (Move, Clarity) contracts

---

## Troubleshooting

### Issue: No groups being created

**Symptoms**: Deduplication runs but creates no groups

**Possible Causes**:
1. Findings missing `location_hash_fuzzy`
2. All findings are truly unique
3. Pattern codes don't match

**Solution**:
```sql
-- Check fingerprint coverage
SELECT
    COUNT(*) as total,
    COUNT(fingerprint_location_fuzzy) as with_fuzzy,
    COUNT(pattern_code) as with_pattern
FROM vulnerabilities
WHERE scan_id = 'your-scan-id';
```

### Issue: Too many groups (low deduplication rate)

**Symptoms**: <20% of findings deduplicated

**Possible Causes**:
1. Findings from different contracts
2. Scanner-specific patterns not mapped
3. Code variations too significant

**Solution**:
```sql
-- Analyze pattern distribution
SELECT pattern_code, COUNT(*)
FROM vulnerabilities
WHERE scan_id = 'your-scan-id'
GROUP BY pattern_code;
```

### Issue: Wrong canonical selection

**Symptoms**: Less detailed finding chosen as canonical

**Possible Causes**:
1. Scanner priority misconfigured
2. Completeness scores equal
3. Timing issues

**Solution**:
```python
# Manually reassign canonical
await dedup_service.ungroup_finding(wrong_canonical_id)
# System will auto-select new canonical from remaining members
```

---

## References

- **Implementation Plan**: PHASE-4E-DEDUPLICATION-ENGINE-PLAN.md
- **Completion Report**: PHASE-4E-DEDUPLICATION-COMPLETE.md
- **Phase 4C**: Enrichment Engine
- **Phase 4D**: Pattern Matching & Fingerprinting
- **Version**: v0.8.0

---

## Testing Results (2025-12-25)

### API Verification

| Endpoint | Status | Notes |
|----------|--------|-------|
| `GET /deduplication/stats` | PASS | 137 groups, 421 findings |
| `GET /deduplication/groups` | PASS | Pagination, filtering working |
| `GET /deduplication/groups/{id}` | PASS | Detail view with all findings |

### Current Statistics

| Metric | Value |
|--------|-------|
| Total Groups | 137 |
| Total Deduplicated Findings | 421 |
| Average Group Size | 3.07 |
| Primary Match Type | Location-based |

### Sample Cross-Scanner Match

```
Group: "State Variable Could Be Constant"
├── Slither: "Constable States" (line 18) - CANONICAL
└── Aderyn: "State Variable Could Be Constant" (line 18) - duplicate
```

**Test Documentation**: `/Users/pwner/Git/ABS/docs/feature-tests/24-cross-scanner-deduplication.md`

---

## Frontend Integration (Dashboard v0.15.1)

### TypeScript Interface Alignment

**Issue (Fixed December 26, 2025)**: Dashboard frontend types did not match API response structure, causing runtime errors on deduplication pages.

**Root Cause**: Frontend interfaces expected fields like `fingerprint_code` that don't exist in the API response. The API returns:
- `canonical_finding_id` - UUID of the canonical finding
- `canonical_finding_title` - Title from canonical finding
- `canonical_finding_severity` - Severity from canonical finding
- `matched_fingerprints` - Array of matched fingerprint types (detail view only)

**Files Updated**:
| File | Change |
|------|--------|
| `src/lib/api/deduplication.ts` | Updated `DeduplicationGroup` and `DeduplicationGroupDetail` interfaces |
| `src/components/intelligence/DeduplicationGroupCard.tsx` | Display canonical finding info |
| `src/pages/DeduplicationDetail.tsx` | Use `matched_fingerprints` array, added missing import |

**API Response Reference**:
```json
// GET /deduplication/groups
{
  "id": "uuid",
  "canonical_finding_id": "uuid",
  "canonical_finding_title": "Reentrancy Vulnerability",
  "canonical_finding_severity": "high",
  "pattern_code": "REE-001",
  "confidence_level": "location",
  "finding_count": 3,
  "scanner_count": 2,
  "first_seen": "2025-12-24T01:25:42.680455Z",
  "last_seen": "2025-12-24T18:04:46.440225Z"
}

// GET /deduplication/groups/{id}
{
  ...same as above,
  "matched_fingerprints": ["location_hash_fuzzy"],
  "findings": [{ ...DuplicateFinding }]
}
```

---

## Hybrid Architecture (v0.29.11 - February 23, 2026)

Added inline post-scan maintenance that runs 4 scoped dedup tasks during scan result ingestion:

| Task | Scoped By | Description |
|------|-----------|-------------|
| Fuzzy fingerprints | scan_id | Generate `fingerprint_location_fuzzy` for new vulns |
| Semantic fingerprints | scan_id | Generate `fingerprint_semantic` via intelligence-engine |
| Tool consensus | contract_id | Calculate cross-tool agreement scores |
| Orphan grouping | contract_id | Assign ungrouped vulns to dedup groups |

Weekly CronJob housekeeping continues running all 18 tasks for full-sweep maintenance.

See: [Deduplication Pipeline](../pipelines/deduplication-pipeline.md) | [Changelog](/docs/changelogs/API-SERVICE-V0.29.11-HYBRID-DEDUPLICATION-2026-02-23.md)

---

**Last Updated**: February 23, 2026
**Maintained By**: Apogee Platform Team
