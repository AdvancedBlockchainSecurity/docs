# Scanner Intelligence Layer Integration Guide

**Version:** 1.0.0
**Last Updated:** November 1, 2025
**Status:** Active Documentation
**Companion to:** [Scanner Integration Guide](SCANNER-INTEGRATION-GUIDE.md)

> **📚 IMPORTANT - Claude Code Users:** This is a companion document to SCANNER-INTEGRATION-GUIDE.md.
> When assisting with scanner integration, read **both documents** to understand:
> 1. Manual integration steps (main guide)
> 2. Automatic enrichment process (this guide)

## Purpose

This guide explains how the **Intelligence Layer** automatically enriches scanner findings with pattern classification, fingerprinting, and cross-scanner deduplication. This happens **automatically** after your parser extracts findings - no additional code required in scanner integration.

---

## Table of Contents

1. [Overview](#overview)
2. [What Gets Enriched Automatically](#what-gets-enriched-automatically)
3. [Pattern Classification](#pattern-classification)
4. [Fingerprint Generation](#fingerprint-generation)
5. [Cross-Scanner Deduplication](#cross-scanner-deduplication)
6. [Database Schema Reference](#database-schema-reference)
7. [Verification & Testing](#verification--testing)
8. [Troubleshooting](#troubleshooting)
9. [Performance Impact](#performance-impact)

---

## Overview

### What is the Intelligence Layer?

The Intelligence Layer is an automatic enrichment pipeline that runs after scanner findings are parsed. It adds standardized metadata to enable:

- **Pattern matching** across different scanner naming conventions
- **Fingerprinting** for duplicate detection
- **Deduplication** when multiple scanners find the same vulnerability
- **Cross-scanner analytics** and comparison

### When Does Enrichment Happen?

```
┌─────────────┐
│   Scanner   │ ──► Runs security analysis
└─────────────┘
       │
       ▼
┌─────────────┐
│   Parser    │ ──► Extracts findings → ParsedFinding objects
└─────────────┘
       │
       ▼
┌─────────────────────────────────────────────┐
│        Intelligence Layer (AUTOMATIC)        │
│  1. Pattern Classification (1-2s)           │
│  2. Fingerprint Generation (2-5s)           │
│  3. Deduplication Matching (5-10s)          │
└─────────────────────────────────────────────┘
       │
       ▼
┌─────────────┐
│  Database   │ ──► Enriched vulnerabilities stored
└─────────────┘
```

**Total enrichment time:** 10-30 seconds per scan (automatic, no user action required)

### No Action Required for Scanner Integration

As a scanner integrator, you **do not need to**:
- ❌ Call enrichment APIs manually
- ❌ Generate fingerprints in your parser
- ❌ Handle deduplication logic
- ❌ Assign pattern codes in scanner code

Just ensure your parser returns valid `ParsedFinding` objects with the required fields (see [Database Schema Reference](#database-schema-reference)).

---

## What Gets Enriched Automatically

After your parser extracts findings, the Intelligence Layer automatically adds:

| Enrichment Type | Fields Added | Purpose |
|----------------|--------------|---------|
| **Pattern Classification** | `pattern_id`, `pattern_code`, `classification_confidence`, `classification_method` | Standardize vulnerability types across scanners |
| **Fingerprints** | `fingerprint_code`, `fingerprint_location`, `fingerprint_ast`, `fingerprint_location_fuzzy` | Enable duplicate detection |
| **Deduplication** | `deduplication_group_id`, `is_canonical`, `duplicate_count`, `scanner_count` | Group identical findings from multiple scanners |

---

## Pattern Classification

### What is Pattern Classification?

Pattern classification maps your scanner's detector IDs to standardized **BVD pattern codes** (Blockchain Vulnerability Database). This enables consistent vulnerability categorization across all scanners.

### Pattern Code Format

```
BVD-{ECOSYSTEM}-{CATEGORY}-{NUMBER}

Examples:
- BVD-EVM-REE-001    → Ethereum reentrancy (classic)
- BVD-EVM-ACC-002    → Ethereum access control (missing modifier)
- BVD-VYPER-ARI-001  → Vyper arithmetic overflow
- BVD-SOLANA-MEM-001 → Solana memory corruption
- BVD-CAIRO-L2S-001  → Cairo Layer 2 security issue
```

**Pattern Categories:**
- `REE`: Reentrancy
- `ACC`: Access Control
- `INT`: Integer Overflow/Underflow
- `EXT`: External Calls
- `STA`: State Management
- `TIM`: Timestamp Dependence
- `GAS`: Gas Optimization
- `LOG`: Logic Errors
- `DAT`: Data Validation
- `VER`: Version/Compiler Issues
- `ARI`: Arithmetic Issues
- `MEM`: Memory Issues
- `L2S`: Layer 2 Security
- `QUA`: Code Quality

### How Pattern Matching Works

1. **Your parser** extracts findings with `detector_id` (e.g., `"reentrancy-eth"`)
2. **Intelligence Layer** looks up detector_id in pattern mappings database
3. **Matched pattern code** assigned (e.g., `"BVD-EVM-REE-001"`)
4. **Classification confidence** set (0.9 for rule-based, varies for ML)
5. **Classification method** recorded (`rule_based`, `ml_based`, `hybrid`)

### Pattern Mapping Example

If your scanner outputs:
```json
{
  "detector_id": "reentrancy-eth",
  "title": "Reentrancy vulnerability in withdraw()",
  "severity": "high"
}
```

Intelligence Layer automatically adds:
```json
{
  "detector_id": "reentrancy-eth",
  "title": "Reentrancy vulnerability in withdraw()",
  "severity": "high",

  // Added by Intelligence Layer:
  "pattern_id": "550e8400-e29b-41d4-a716-446655440001",
  "pattern_code": "BVD-EVM-REE-001",
  "classification_confidence": 0.9,
  "classification_method": "rule_based"
}
```

### Creating Pattern Mappings (Scanner Integration Step)

**During scanner integration**, you create a pattern mapping file:

**File:** `blocksecops-api-service/seeds/<scanner>_pattern_mappings.json`

```json
{
  "version": "1.0",
  "scanner": "your-scanner-id",
  "scanner_version": "1.0.0",
  "mappings": [
    {
      "detector_id": "reentrancy-eth",
      "pattern_code": "BVD-EVM-REE-001",
      "category": "Reentrancy",
      "description": "Reentrancy vulnerability with ETH transfer"
    },
    {
      "detector_id": "missing-access-control",
      "pattern_code": "BVD-EVM-ACC-001",
      "category": "Access Control",
      "description": "Missing access control on sensitive function"
    }
  ]
}
```

Then run the seed script:
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
python scripts/seed_vulnerability_patterns.py
```

**After seeding, pattern matching happens automatically for all future scans.**

---

## Fingerprint Generation

### What are Fingerprints?

Fingerprints are SHA-256 hashes of vulnerability characteristics used for duplicate detection. The Intelligence Layer generates **4 types of fingerprints**:

| Fingerprint Type | What it Hashes | Purpose | Strictness |
|-----------------|----------------|---------|------------|
| `fingerprint_code` | Normalized code snippet | Detect identical code patterns | Exact match |
| `fingerprint_location` | `file:line:function` | Detect same location | Exact match |
| `fingerprint_ast` | AST structure (if available) | Detect structural equivalence | Exact match |
| `fingerprint_location_fuzzy` | Location ±3 lines | Detect near-duplicates | Fuzzy match |

### How Fingerprints are Generated

1. **Code Normalization:**
   - Remove whitespace
   - Lowercase keywords
   - Normalize variable names (optional)
   - Hash with SHA-256

2. **Location Hashing:**
   - Combine: `file_path + ":" + line_number + ":" + function_name`
   - Hash with SHA-256

3. **AST Hashing (if available):**
   - Parse code snippet to AST
   - Serialize AST structure
   - Hash with SHA-256

4. **Fuzzy Location Hashing:**
   - Use line_number ±3 lines tolerance
   - Hash location with fuzzy range
   - Enables detection of findings moved slightly

### Example Fingerprints

For this finding:
```python
ParsedFinding(
    detector_id="reentrancy-eth",
    file_path="contracts/Bank.sol",
    line_number=42,
    function_name="withdraw",
    code_snippet="msg.sender.call{value: amount}(\"\")"
)
```

Intelligence Layer generates:
```json
{
  "fingerprint_code": "a3f5e2c8b1d7f9e4c6a8d2f5b7e9c1a4d6f8e0a2c4b6d8e0f2a4c6e8b0d2f4a6",
  "fingerprint_location": "b7d4a1f92c8e6f3ad5e7c9f1b4d6a8e2c4f6d8e0a2b4c6d8e0f2a4b6c8d0e2f4",
  "fingerprint_ast": "c9e2f5d8a6b3c1e7f4d2a5c8b1e6d9f3a5c7e9d1b3e5f7d9c1a3e5d7f9b1c3e5",
  "fingerprint_location_fuzzy": "d8f3a9e7c2b5d1f6e4a8c0b2d4f6e8a0c2b4d6f8e0a2c4b6d8e0f2a4b6c8d0e2"
}
```

### Parser Requirements for Fingerprinting

To enable fingerprint generation, your parser **must populate** these fields:

**Required:**
- `code_snippet` (string) - Code fragment containing the vulnerability
- `file_path` (string) - File location
- `line_number` (int) - Line number in file

**Recommended:**
- `function_name` (string) - Function/method name
- `contract_name` (string) - Contract/class name

**If missing:**
- No `code_snippet` → `fingerprint_code` will be NULL
- No `line_number` → `fingerprint_location` will be NULL
- AST parsing fails → `fingerprint_ast` will be NULL

---

## Cross-Scanner Deduplication

### What is Deduplication?

When multiple scanners detect the **same vulnerability**, deduplication groups them together. This allows:
- Seeing which scanners agree on a finding
- Prioritizing vulnerabilities detected by multiple tools
- Comparing scanner accuracy and coverage

### How Deduplication Works

1. **After fingerprints generated**, Intelligence Layer compares new findings with existing findings
2. **Matching criteria** (in order of strictness):
   - Exact: `fingerprint_code` matches AND `fingerprint_location` matches
   - High: `fingerprint_code` matches OR (`pattern_code` matches AND `fingerprint_location_fuzzy` matches)
   - Medium: `pattern_code` matches AND `fingerprint_location_fuzzy` matches
   - Low: `pattern_code` matches AND same `file_path`

3. **Group creation:**
   - First finding creates a new deduplication group
   - Subsequent matching findings added to group
   - One finding marked as **canonical** (primary reference)

4. **Metadata updated:**
   - `deduplication_group_id` (UUID) - Shared across all duplicates
   - `is_canonical` (boolean) - True for primary finding
   - `duplicate_count` (int) - Number of duplicates in group
   - `scanner_count` (int) - Number of unique scanners

### Deduplication Example

**Scenario:** Contract scanned with Slither and Aderyn. Both detect reentrancy.

**After enrichment:**

| Finding ID | Scanner | Pattern Code | Fingerprint Code | Dedup Group ID | Is Canonical | Scanner Count |
|-----------|---------|--------------|------------------|----------------|--------------|---------------|
| vuln-001 | slither | BVD-EVM-REE-001 | a3f5e2c8... | group-123 | **TRUE** | 2 |
| vuln-002 | aderyn | BVD-EVM-REE-001 | a3f5e2c8... | group-123 | FALSE | 2 |

**Dashboard display:**
- Shows **1 vulnerability** (canonical)
- Badge: "🔍 Found by 2 scanners"
- Click badge → See both findings side-by-side

### Canonical Finding Selection

The **canonical finding** is selected by priority:
1. Highest `classification_confidence`
2. Most detailed `description`
3. Scanner reputation (configurable)
4. First detected (tie-breaker)

### Querying Deduplication Groups

```sql
-- Find all deduplication groups
SELECT
    deduplication_group_id,
    COUNT(*) as finding_count,
    COUNT(DISTINCT scanner_id) as scanner_count,
    MAX(CASE WHEN is_canonical THEN id END) as canonical_id
FROM vulnerabilities
WHERE deduplication_group_id IS NOT NULL
GROUP BY deduplication_group_id;

-- Get all findings in a group
SELECT
    scanner_id,
    title,
    description,
    is_canonical,
    classification_confidence
FROM vulnerabilities
WHERE deduplication_group_id = '550e8400-e29b-41d4-a716-446655440123'
ORDER BY is_canonical DESC, classification_confidence DESC;
```

---

## Database Schema Reference

### Intelligence Layer Fields (Auto-populated)

```sql
-- vulnerabilities table additions

-- Pattern Classification
pattern_id                    UUID           -- FK to vulnerability_patterns.id
pattern_code                  VARCHAR(50)    -- e.g., "BVD-EVM-REE-001"
classification_confidence     FLOAT          -- 0.0-1.0 (0.9 for rule-based)
classification_method         VARCHAR(20)    -- rule_based, ml_based, hybrid

-- Fingerprints (SHA-256 hashes)
fingerprint_code             VARCHAR(64)    -- Hash of normalized code
fingerprint_location         VARCHAR(64)    -- Hash of file:line:function
fingerprint_ast              VARCHAR(64)    -- Hash of AST structure
fingerprint_location_fuzzy   VARCHAR(64)    -- Hash with ±3 line tolerance

-- Deduplication
deduplication_group_id       UUID           -- FK to deduplication_groups.id
is_canonical                 BOOLEAN        -- True for primary finding
duplicate_count              INTEGER        -- Number of duplicates in group
scanner_count                INTEGER        -- Number of scanners that found it
```

### Parser Output Requirements

Your parser's `ParsedFinding` must include:

**For Pattern Classification:**
- `detector_id` (string, required) - Your scanner's detector identifier

**For Fingerprint Generation:**
- `code_snippet` (string, optional but recommended) - Code containing vulnerability
- `file_path` (string, required) - File location
- `line_number` (int, optional but recommended) - Line number
- `function_name` (string, optional) - Function/method name
- `contract_name` (string, optional) - Contract/class name

**Example ParsedFinding:**
```python
ParsedFinding(
    scanner_id="your-scanner",
    detector_id="reentrancy-eth",          # → Used for pattern matching
    title="Reentrancy vulnerability",
    description="...",
    severity=Severity.HIGH,
    file_path="contracts/Bank.sol",        # → Used for location fingerprint
    line_number=42,                        # → Used for location fingerprint
    function_name="withdraw",              # → Used for location fingerprint
    contract_name="Bank",                  # → Used for context
    code_snippet="msg.sender.call...",     # → Used for code fingerprint
    raw_output=original_scanner_output     # → Preserved for debugging
)
```

---

## Verification & Testing

### Test 1: Verify Pattern Classification

After running a test scan:

```sql
SELECT
    detector_id,
    pattern_code,
    classification_confidence,
    classification_method
FROM vulnerabilities
WHERE scan_id = '<your-scan-id>'
  AND scanner_id = '<your-scanner-id>';
```

**Expected results:**
- ✅ `pattern_code` is NOT NULL (e.g., "BVD-EVM-REE-001")
- ✅ `classification_confidence` = 0.9 (for rule-based)
- ✅ `classification_method` = 'rule_based'

**If pattern_code is NULL:**
- Pattern mapping not seeded (re-run seed script)
- Detector ID mismatch (check spelling in mapping file)
- See [Troubleshooting: Pattern Classification](#troubleshooting)

### Test 2: Verify Fingerprint Generation

```sql
SELECT
    title,
    fingerprint_code,
    fingerprint_location,
    fingerprint_ast,
    fingerprint_location_fuzzy
FROM vulnerabilities
WHERE scan_id = '<your-scan-id>'
LIMIT 5;
```

**Expected results:**
- ✅ `fingerprint_code` is a 64-character SHA-256 hash
- ✅ `fingerprint_location` is a 64-character SHA-256 hash
- ✅ `fingerprint_ast` is a 64-character hash (or NULL if AST parsing failed)
- ✅ `fingerprint_location_fuzzy` is a 64-character hash

**If all fingerprints are NULL:**
- Parser not providing `code_snippet` (check parser implementation)
- Enrichment service crashed (check logs)
- See [Troubleshooting: Fingerprint Generation](#troubleshooting)

### Test 3: Verify Deduplication (Multi-Scanner Test)

Run the same contract with **2+ scanners** that detect the same vulnerability:

```bash
curl -X POST http://localhost:8000/api/v1/scans \
  -H "Content-Type: application/json" \
  -d '{
    "contract_id": "<test-contract-id>",
    "scanners": ["slither", "aderyn"],
    "project_id": "test-project"
  }'
```

Then verify deduplication:

```sql
-- Check deduplication groups created
SELECT
    deduplication_group_id,
    scanner_id,
    title,
    is_canonical,
    scanner_count,
    duplicate_count
FROM vulnerabilities
WHERE scan_id = '<scan-id>'
  AND deduplication_group_id IS NOT NULL
ORDER BY deduplication_group_id, is_canonical DESC;
```

**Expected results:**
- ✅ Same `deduplication_group_id` for identical findings from different scanners
- ✅ Exactly **1 finding** per group has `is_canonical = true`
- ✅ `scanner_count` matches number of scanners that detected it (e.g., 2)
- ✅ `duplicate_count` = total findings in group - 1

**If no deduplication groups created:**
- Scanners detected different vulnerabilities (not duplicates)
- Fingerprints don't match (check code snippets are identical)
- See [Troubleshooting: Deduplication](#troubleshooting)

### Test 4: Check Enrichment Logs

```bash
kubectl logs -n orchestration-local deployment/orchestration --tail=200 | grep -i "enrichment\|intelligence"
```

**Look for:**
- ✅ `"Starting intelligence enrichment for scan <scan-id>"`
- ✅ `"Pattern classification complete: X/Y findings matched"`
- ✅ `"Fingerprint generation complete: X fingerprints created"`
- ✅ `"Deduplication complete: X groups created"`
- ❌ No ERROR messages

---

## Troubleshooting

### Issue: pattern_code is NULL

**Symptoms:**
- All vulnerabilities have `pattern_code = NULL`
- `classification_confidence = NULL`

**Diagnosis:**
```sql
-- Check if pattern mappings exist for your scanner
SELECT COUNT(*)
FROM pattern_tool_mappings
WHERE tool_name = '<your-scanner-id>';
```

**If count = 0:**
1. Pattern mappings not seeded
2. Re-run seed script:
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-api-service
   python scripts/seed_vulnerability_patterns.py
   ```
3. Verify mappings file exists: `seeds/<scanner>_pattern_mappings.json`

**If count > 0:**
1. Detector ID mismatch
2. Check exact spelling in mapping file vs parser output:
   ```sql
   SELECT DISTINCT detector_id FROM vulnerabilities WHERE scanner_id = '<your-scanner>';
   ```
3. Update mapping file with correct detector_ids

### Issue: All Fingerprints are NULL

**Symptoms:**
- `fingerprint_code = NULL`
- `fingerprint_location = NULL`
- `fingerprint_ast = NULL`

**Diagnosis:**
```sql
-- Check if parser provided code snippets
SELECT
    id,
    code_snippet IS NULL as missing_snippet,
    line_number IS NULL as missing_line
FROM vulnerabilities
WHERE scan_id = '<scan-id>'
LIMIT 10;
```

**If missing_snippet = true:**
1. Parser not extracting `code_snippet` from scanner output
2. Update parser to populate `code_snippet` field:
   ```python
   ParsedFinding(
       # ...
       code_snippet=item.get("code", item.get("code_snippet", "")),
       # ...
   )
   ```

**If snippets exist but fingerprints still NULL:**
1. Enrichment service crashed during fingerprint generation
2. Check orchestration logs:
   ```bash
   kubectl logs deployment/orchestration | grep -i "fingerprint\|error"
   ```

### Issue: No Deduplication Groups Created

**Symptoms:**
- Multiple scanners detect same vulnerability
- All findings have `deduplication_group_id = NULL`

**Diagnosis:**
```sql
-- Check if fingerprints match between scanners
SELECT
    scanner_id,
    fingerprint_code,
    fingerprint_location,
    pattern_code
FROM vulnerabilities
WHERE title ILIKE '%reentrancy%'
  AND scan_id IN ('<scan1-id>', '<scan2-id>')
ORDER BY pattern_code, fingerprint_code;
```

**Common causes:**

1. **Fingerprints don't match** (different code snippets):
   - Scanners extract different code snippets
   - Normalization differences
   - **Fix:** Review code snippet extraction in both parsers

2. **Pattern codes don't match**:
   - Scanners use different detector IDs
   - Pattern mappings assign different codes
   - **Fix:** Align pattern mappings to use same BVD code

3. **Confidence threshold not met**:
   - Fuzzy matching threshold too high
   - **Fix:** Review deduplication confidence settings

4. **Timing issue** (rare):
   - Second scan enriched before first scan completed
   - **Fix:** Ensure scans complete sequentially in testing

### Issue: Wrong Finding Marked as Canonical

**Symptoms:**
- Lower-quality finding marked `is_canonical = true`
- Better finding is not canonical

**Diagnosis:**
```sql
-- Check canonical selection criteria
SELECT
    scanner_id,
    is_canonical,
    classification_confidence,
    LENGTH(description) as desc_length
FROM vulnerabilities
WHERE deduplication_group_id = '<group-id>'
ORDER BY is_canonical DESC;
```

**Canonical selection priority:**
1. Highest `classification_confidence`
2. Longest `description`
3. Scanner reputation (if configured)
4. First detected

**Fix:**
If selection seems wrong, check:
- Classification confidence correct in mappings
- Scanner reputation weights configured
- Description extraction working properly

### Issue: Enrichment Taking Too Long

**Symptoms:**
- Scan stuck in "running" status for >5 minutes
- Findings stored but enrichment not complete

**Diagnosis:**
```bash
# Check enrichment task status
kubectl logs deployment/orchestration | grep "enrichment" | tail -50
```

**Common causes:**
1. Large number of findings (>1000)
2. Database slow (too many concurrent enrichments)
3. AST parsing timeout (complex code snippets)

**Fix:**
- Increase enrichment timeout in orchestration config
- Scale up database resources
- Disable AST fingerprinting for large scans (optional)

---

## Performance Impact

### Enrichment Overhead

| Enrichment Stage | Time per Finding | Time for 100 Findings |
|-----------------|------------------|----------------------|
| Pattern Classification | ~10ms | ~1s |
| Fingerprint Generation | ~50ms | ~5s |
| Deduplication Matching | ~100ms | ~10s |
| **Total per Scan** | ~160ms | ~16s |

**Expected total enrichment time:**
- Small scan (<10 findings): **2-5 seconds**
- Medium scan (10-100 findings): **10-30 seconds**
- Large scan (100-1000 findings): **1-3 minutes**
- Very large scan (>1000 findings): **3-10 minutes**

### Database Impact

Enrichment adds **13 columns** to the `vulnerabilities` table:
- 4 pattern classification fields
- 4 fingerprint fields
- 5 deduplication fields

**Storage increase:** ~200 bytes per vulnerability (hashes are 64 chars each)

**Index impact:**
- Pattern code index: +10ms query time (negligible)
- Fingerprint indexes: +50ms for deduplication queries
- Deduplication group index: +5ms for group lookups

### Scaling Considerations

**Current capacity (tested):**
- 1000 vulnerabilities/scan: ✅ Works well
- 10,000 vulnerabilities/scan: ⚠️ Slow but functional
- 100,000 vulnerabilities/scan: ❌ Not recommended (consider batch processing)

**For very large scans:**
- Consider disabling AST fingerprinting
- Use batch enrichment (process in chunks of 1000)
- Scale up orchestration service resources

---

## Related Documentation

- **[Scanner Integration Guide](SCANNER-INTEGRATION-GUIDE.md)** - Main scanner integration process
- **[Platform Development Standards](/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md)** - Platform coding standards
- **[API Endpoints Reference](/Users/pwner/Git/ABS/blocksecops-docs/api/endpoints-reference.md)** - Intelligence Layer API fields
- **[Phase 4D Pattern Matching](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/03-phase-4-intelligence/PHASE-4D-NEXT-STEPS.md)** - Pattern classification deep-dive
- **[Phase 4E Deduplication](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/implementation-summaries/PHASE-4E-DEDUPLICATION-COMPLETE.md)** - Deduplication implementation

---

**Document Owner:** Engineering Team
**Last Updated:** November 1, 2025
**Next Review:** When Intelligence Layer architecture changes
