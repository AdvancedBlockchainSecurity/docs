

# Scanner Version Tracking Database

**Created**: 2025-10-30
**Purpose**: Database-driven scanner version tracking to replace manual markdown documentation
**Database**: `solidity_security` (existing PostgreSQL database)
**Location**: `/Users/pwner/Git/ABS/database/scanner-version-tracking/`

---

## Overview

This database schema provides structured tracking of scanner versions, releases, and integration status for the BlockSecOps platform. Instead of manually maintaining version information in markdown files, all scanner metadata is now stored in PostgreSQL tables with automated queries and reporting.

### Key Benefits

- ✅ **Single Source of Truth**: All scanner versions in one queryable database
- ✅ **Automated Tracking**: Compare current vs. latest versions programmatically
- ✅ **History Audit Trail**: Complete changelog of all version updates
- ✅ **Integration Progress**: Track detector mapping progress by scanner
- ✅ **Release Monitoring**: Track upstream releases and pending updates
- ✅ **Query-Based Reporting**: Generate reports via SQL instead of parsing markdown

---

## Database Schema

### Tables

#### 1. `scanner_versions` (Main Table)
Tracks current scanner version information and integration status.

**Key Columns:**
- `scanner_name` - Unique scanner identifier (e.g., 'slither', 'aderyn')
- `scanner_type` - Type: 'static-analysis', 'fuzzer', 'formal-verification'
- `ecosystem` - Target blockchain: 'evm', 'solana', 'cairo', 'move'
- `language` - Programming language: 'solidity', 'vyper', 'rust', 'cairo'
- `current_version` - Version currently deployed on platform
- `latest_version` - Latest upstream version (manually or API-updated)
- `version_status` - Status: 'up-to-date', 'outdated', 'unknown', 'deprecated'
- `image_tag` - Docker image tag (e.g., '0.2.1')
- `image_name` - Full image name (e.g., 'scanner-aderyn:0.2.1')
- `detector_count` - Total number of detectors
- `integrated_detector_count` - Number of detectors mapped to patterns
- `integration_percentage` - Calculated field: integrated/total * 100

#### 2. `scanner_version_history` (Audit Trail)
Records all version changes for complete audit history.

**Key Columns:**
- `scanner_name` - Reference to scanner
- `old_version` / `new_version` - Version change tracking
- `old_image_tag` / `new_image_tag` - Image tag changes
- `change_type` - Type: 'major', 'minor', 'patch', 'image-only'
- `breaking_changes` - Boolean flag for breaking changes
- `detector_changes` - Description of detector changes
- `updated_at` - Timestamp of update
- `updated_by` - User or system that performed update

#### 3. `scanner_release_tracking` (Upstream Monitoring)
Tracks upstream releases for comparison and update planning.

**Key Columns:**
- `scanner_name` - Reference to scanner
- `release_version` - Upstream release version
- `release_date` - Release date
- `release_url` - Link to release notes
- `is_prerelease` - Boolean flag for beta/RC releases
- `applied_to_platform` - Whether this release has been applied
- `applied_at` - Timestamp when applied

### Views

#### `scanner_version_status`
Convenient overview of all scanners with calculated fields including pending releases count.

#### `outdated_scanners`
Quick view of scanners that need updating (version_status = 'outdated').

---

## Installation

### 1. Apply Schema & Load Data

```bash
cd /Users/pwner/Git/ABS/database/scanner-version-tracking

# Dry run (preview without applying)
./apply_migration.sh --dry-run

# Apply for real
./apply_migration.sh
```

**What this does:**
1. Creates backup of existing database
2. Creates all tables, indexes, views, and functions
3. Loads initial scanner data from ConfigMap
4. Verifies migration success

### 2. Environment Variables

The migration script uses these environment variables (with defaults):

```bash
export DB_HOST=localhost      # Default: localhost
export DB_PORT=5432           # Default: 5432
export DB_NAME=solidity_security  # Default: solidity_security
export DB_USER=postgres       # Default: postgres
export DB_PASSWORD=postgres   # Default: postgres
```

### 3. Connect to Kubernetes Database

If running against Kubernetes PostgreSQL:

```bash
# Port-forward PostgreSQL service
kubectl port-forward -n api-service-local svc/postgresql 5432:5432 &

# Set environment variables
export PGPASSWORD=postgres

# Apply migration
./apply_migration.sh
```

---

## Usage

### Query Scanner Status

```sql
-- View all scanners
SELECT * FROM scanner_version_status
ORDER BY ecosystem, scanner_type, scanner_name;

-- Check outdated scanners
SELECT * FROM outdated_scanners;

-- Integration progress by ecosystem
SELECT
    ecosystem,
    COUNT(*) as scanners,
    SUM(detector_count) as total_detectors,
    SUM(integrated_detector_count) as integrated,
    ROUND(AVG(integration_percentage), 2) as avg_progress
FROM scanner_versions
WHERE detector_count > 0
GROUP BY ecosystem;
```

### View Version History

```sql
-- Recent updates
SELECT
    scanner_name,
    old_version || ' → ' || new_version as change,
    change_type,
    updated_at,
    updated_by
FROM scanner_version_history
ORDER BY updated_at DESC
LIMIT 10;

-- History for specific scanner
SELECT * FROM scanner_version_history
WHERE scanner_name = 'aderyn'
ORDER BY updated_at DESC;
```

### Record Version Update

Use the built-in function to record updates with automatic history tracking:

```sql
SELECT record_scanner_update(
    'slither',           -- scanner_name
    '0.11.4',            -- new_version
    '0.2.1',             -- new_image_tag
    'patch',             -- change_type
    FALSE,               -- breaking_changes
    'Minor bug fixes',   -- detector_changes
    'Bug fixes and performance improvements'  -- release_notes
);
```

### Check for Updates

```sql
SELECT check_scanner_version_update('aderyn', '0.6.6', '0.2.2');
```

### Track Pending Releases

```sql
-- Add upstream release
INSERT INTO scanner_release_tracking (
    scanner_name, release_version, release_date,
    release_url, is_prerelease
) VALUES (
    'slither', '0.11.4', '2025-11-01',
    'https://github.com/crytic/slither/releases/tag/0.11.4',
    FALSE
);

-- View pending releases
SELECT
    srt.scanner_name,
    srt.release_version,
    sv.current_version,
    srt.release_date
FROM scanner_release_tracking srt
JOIN scanner_versions sv ON srt.scanner_name = sv.scanner_name
WHERE srt.applied_to_platform = FALSE;
```

---

## Common Workflows

### Workflow 1: Update Scanner Version

When updating a scanner version (e.g., after updating Dockerfile):

```sql
BEGIN;

-- Record the update with history
SELECT record_scanner_update(
    'semgrep',
    '1.142.0',
    '0.2.2',
    'minor',
    FALSE,
    'No detector changes',
    'Minor version update with bug fixes'
);

-- Mark any pending release as applied
UPDATE scanner_release_tracking
SET applied_to_platform = TRUE, applied_at = NOW()
WHERE scanner_name = 'semgrep'
AND release_version = '1.142.0';

COMMIT;
```

### Workflow 2: Check Which Scanners Need Updates

```sql
-- Quick check
SELECT scanner_name, current_version, latest_version
FROM scanner_versions
WHERE version_status = 'outdated'
ORDER BY scanner_name;

-- Detailed report
SELECT
    sv.scanner_name,
    sv.ecosystem,
    sv.current_version,
    sv.latest_version,
    sv.last_checked_at,
    COUNT(srt.id) as pending_releases
FROM scanner_versions sv
LEFT JOIN scanner_release_tracking srt
    ON sv.scanner_name = srt.scanner_name
    AND srt.applied_to_platform = FALSE
WHERE sv.version_status != 'up-to-date'
GROUP BY sv.scanner_name, sv.ecosystem, sv.current_version,
         sv.latest_version, sv.last_checked_at;
```

### Workflow 3: Update Integration Progress

After completing detector mappings for a scanner:

```sql
UPDATE scanner_versions
SET
    integrated_detector_count = 99,  -- Updated count
    last_updated_at = NOW(),
    notes = 'Completed Slither integration - 100% coverage'
WHERE scanner_name = 'slither';

-- Verify calculation
SELECT
    scanner_name,
    detector_count,
    integrated_detector_count,
    integration_percentage
FROM scanner_versions
WHERE scanner_name = 'slither';
```

### Workflow 4: Generate Status Report

```sql
-- Comprehensive status report
\echo '\n=== BlockSecOps Scanner Status Report ==='
\echo '\nLast Updated:' `date`

SELECT
    ecosystem,
    scanner_type,
    scanner_name,
    current_version,
    version_status,
    CONCAT(integrated_detector_count, '/', detector_count) as detectors,
    ROUND(integration_percentage, 1) || '%' as progress,
    image_tag
FROM scanner_version_status
ORDER BY ecosystem, scanner_type, scanner_name;

\echo '\n=== Integration Progress by Ecosystem ==='
SELECT
    ecosystem,
    COUNT(*) as scanners,
    SUM(detector_count) as detectors,
    SUM(integrated_detector_count) as integrated,
    ROUND(AVG(integration_percentage), 2) || '%' as progress
FROM scanner_versions
WHERE detector_count > 0
GROUP BY ecosystem;
```

---

## Helper Scripts

### Quick Status Check

```bash
# From database/scanner-version-tracking directory
psql -d solidity_security -f query_helpers.sql
```

This runs all common queries and displays:
- Scanner version status
- Outdated scanners
- Integration progress by ecosystem
- Integration progress by scanner type
- Recent version updates
- Pending releases

### Generate Reports

```bash
# Status report
psql -d solidity_security -c "SELECT * FROM scanner_version_status;"

# Outdated scanners
psql -d solidity_security -c "SELECT * FROM outdated_scanners;"

# Recent updates
psql -d solidity_security -c "
SELECT scanner_name, old_version || ' → ' || new_version as change,
       updated_at, updated_by
FROM scanner_version_history
ORDER BY updated_at DESC LIMIT 5;"
```

---

## Integration with ConfigMap

The database serves as a **complementary** source alongside the ConfigMap:

- **ConfigMap** (`scanner-versions-configmap.yaml`): Runtime configuration for Kubernetes deployments
- **Database**: Historical tracking, analytics, and version comparison

### Sync Process

When updating scanner versions:

1. Update Dockerfile with new version
2. Build and tag new image
3. Update ConfigMap with new metadata and image tag
4. Apply ConfigMap to Kubernetes
5. **Record update in database** using `record_scanner_update()` function
6. Commit ConfigMap changes to Git

The database provides the **history** and **analytics** that ConfigMap cannot.

---

## Data Current as of 2026-01-19

### Scanner Images in Harbor Registry (Verified January 19, 2026)

All 15 scanner images are now in Harbor at `harbor.blocksecops.local/blocksecops/`:

### Automated Version Checking

Use the automated version checker to find outdated scanners:

```bash
# Human-readable output
/home/pwner/Git/blocksecops-tool-integration/scripts/check-scanner-versions.sh

# JSON output for CI
/home/pwner/Git/blocksecops-tool-integration/scripts/check-scanner-versions.sh --json
```

See `/home/pwner/Git/blocksecops-tool-integration/docs/SCANNER-UPDATE-PROCEDURE.md` for step-by-step update instructions.

### Scanners Loaded

**EVM/Solidity Scanners:**
- slither (0.11.5, solc-select 1.1.0) - scanner-slither:0.3.1 - 101/101 detectors (100%) ✅
- aderyn (0.6.7) - scanner-aderyn:0.7.0 (pre-built binary) - 87/87 detectors (100%) ✅
- wake (eth-wake 4.21.0) - scanner-wake:0.3.4 ✅
- semgrep (1.141.0) - scanner-semgrep:0.3.2 - 43/47 detectors (91.5%) - Fixed JSON generation bug (2026-02-05)
- solhint (6.0.2) - scanner-solhint:0.3.0 - 16/20 detectors (80%) ✅ FIXED
- echidna (2.2.7, solc-select 1.1.0) - scanner-echidna:0.2.0 - fuzzer
- medusa (1.3.1) - scanner-medusa:0.2.0 - fuzzer
- halmos (0.3.3) - scanner-halmos:0.2.0 - formal verification
- certora (8.3.1) - 0/5 rules integrated

**EVM/Vyper Scanners:** ✅ All in Harbor, E2E verified (January 19, 2026)
- vyper (0.4.3) - harbor.blocksecops.local/blocksecops/scanner-vyper:0.2.0 - uses slither 0.11.3 ✅
- moccasin (latest, vyper 0.4.3) - harbor.blocksecops.local/blocksecops/scanner-moccasin:0.2.0 - fuzzer ✅
  - Note: Moccasin requires project structure (not shown for single-file contracts in UI)

**Solana Scanners:** ✅ All in Harbor (January 19, 2026)
- sol-azy (latest) - harbor.blocksecops.local/blocksecops/scanner-sol-azy:0.2.0 ✅
- sec3-xray (0.0.6) - harbor.blocksecops.local/blocksecops/scanner-sec3-xray:0.2.0 ✅
- trident (0.12.0) - harbor.blocksecops.local/blocksecops/scanner-trident:0.3.0 ✅
- cargo-fuzz-solana (0.13.1) - harbor.blocksecops.local/blocksecops/scanner-cargo-fuzz-solana:0.2.0 ✅

**Cairo/StarkNet Scanners:** ⚠️ NOT integrated - patterns defined but no scanner integration
- caracal (0.2.3) - 0/14 detectors ❌ Unavailable (no Docker image)
- tayt (0.1.0) - fuzzer (deprecated) ❌ Removed
- starknet-foundry (0.50.0) - fuzzer ❌ Unavailable (no Docker image)

### Recent Updates Recorded

- **2026-02-05**: Semgrep Scanner Wrapper 0.3.2 Bug Fix
  - **Semgrep**: Image 0.3.1 → 0.3.2 (tool version remains 1.141.0)
  - Fixed JSON generation bug when findings are empty (invalid JSON at char 154)
  - Root cause: `jq 'length'` on empty string returns no output, creating `"total_findings": ,`
  - Added empty string guard + pre-computed TOTAL_FINDINGS with fallback to 0
  - See: `docs/changelogs/ADMIN-SYSTEM-FIXES-2026-02-05.md`

- **2026-01-31**: SolidityDefend Scanner Wrapper 0.5.0 Upgrade
  - **SolidityDefend**: Image 0.4.0 → 0.5.0 (tool version remains 1.10.3)
  - 333 detectors available, 22 triggered on test contract
  - Clean slate approach: 10,515 old findings deleted before upgrade
  - Created reusable playbook: `docs/playbooks/upgrade-scanner-image.md`
  - Test scan verified: 34 findings (12 critical, 15 high, 4 medium, 3 low)
  - See: `docs/changelogs/SOLIDITYDEFEND-0.5.0-UPGRADE-2026-01-31.md`

- **2026-01-19**: Scanner Version Updates (Slither, Aderyn, Solhint)
  - **Slither**: 0.11.3 → 0.11.5 (minor bug fixes)
  - **Aderyn**: 0.6.5 → 0.6.7 (new detectors)
  - **Solhint**: 5.1.0 → 6.0.2 (**CRITICAL FIX** - ConfigMap claimed 6.0.1 but Dockerfile had 5.1.0)
  - Created automation script: `scripts/check-scanner-versions.sh` to detect outdated scanners
  - Created update procedure documentation: `docs/SCANNER-UPDATE-PROCEDURE.md`
  - All images rebuilt and pushed to Harbor
  - ConfigMap and deployments updated

- **2026-01-19**: All Scanner Images Verified in Harbor
  - All 15 scanner images confirmed in Harbor registry with correct versions
  - ConfigMap (`scanner-versions`) updated with Harbor image references
  - Orchestration SCANNER_METADATA updated with missing scanner entries (moccasin, vyper, soliditydefend, sol-azy, sec3-xray, trident, cargo-fuzz-solana)
  - Vyper and Moccasin scans completing successfully (E2E verified)
  - See: `/home/pwner/Git/TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-01-19-SCANNER-HARBOR-IMAGES.md`

- **2025-12-20**: Scanner Pattern Coverage Audit Complete
  - Fixed 5 duplicate pattern IDs in vulnerability_patterns.json
  - Added MythrilExecutor to scanner registry (was missing registration)
  - Fixed Vyper scanner ID mismatch ("vyper" → "slither-vyper")
  - Pattern count: 398 → 397 (1 merged), 638 mappings, 17 scanners
  - Updated verification script with correct field names
  - See: `/docs/changelogs/SCANNER-PATTERN-AUDIT-2025-12-20.md`

- **2025-12-20**: Phase 3.5 Parsers Complete - All scanner output parsers implemented
  - Added MoccasinParser for Vyper fuzzing output
  - Added SolAzyParser, Sec3XRayParser, TridentParser, CargoFuzzSolanaParser for Solana
  - Added GenericJsonParser as fallback for unknown scanners
  - 27 unit tests passing in `blocksecops-tool-integration`
  - SlitherParser validated with real scanner output (12 vulnerabilities parsed)
  - See: `/docs/changelogs/PHASE-3.5-PARSERS-2025-12-20.md`

- **2025-12-15**: Full scanner integration - 16/16 scanners available
  - Vyper and Moccasin scanners available in orchestration pod (vyper 0.4.0, moccasin installed)
  - Solana scanners enabled via Docker-based execution (Sol-azy, Sec3-xray, Trident, Cargo-fuzz-solana)
  - Orchestration image 0.9.1 deployed with Docker-based Solana scanner execution
  - Cairo scanners not integrated (no Docker images)
- **2025-12-08**: Phase 3.5 Vyper/Rust scanner images built and tested
  - Vyper: scanner-vyper:0.2.0 with vyper 0.4.3, slither 0.11.3
  - Moccasin: scanner-moccasin:0.2.0 with vyper 0.4.3
  - Sol-azy: scanner-sol-azy:latest (146MB)
  - Sec3 X-Ray: scanner-sec3-xray:latest (238MB)
  - Trident: scanner-trident:latest with trident 0.12.0 (2.09GB)
  - cargo-fuzz-solana: scanner-cargo-fuzz-solana:latest (1.69GB)
  - All images use stable Rust (not nightly)
- **2025-12-05**: Scanner image updates - 8 images built with latest tool versions
  - Wake: eth-wake 4.13.1 → 4.21.0
  - Semgrep: 1.141.0 → 1.144.0
  - Solhint: 5.0.3 → 5.1.0
  - Halmos: 0.2.1 → 0.3.3
  - Medusa: pinned to v1.3.1
  - All: solc-select updated to 1.1.0
- **2025-10-31**: Slither Phase 5 & 6 Complete - 101/101 detectors (100%) ✅
- **2025-10-30**: Aderyn 0.6.4 → 0.6.5
- **2025-10-30**: Semgrep 1.122.0 → 1.141.0 (19-version jump)
- **2025-10-30**: Echidna 2.2.4 → 2.2.7

---

## Maintenance

### Regular Tasks

**Weekly:**
- Check `outdated_scanners` view
- Update `latest_version` fields based on upstream releases
- Review pending releases

**After Each Scanner Update:**
- Record update using `record_scanner_update()` function
- Update integration counts if detector mappings changed
- Add release notes to history

**Monthly:**
- Review integration progress
- Generate status report
- Archive old history (optional, currently no archival needed)

### Backup

Database backups are automatically created before each migration:
- Location: `/Users/pwner/Git/ABS/database/backups/`
- Format: PostgreSQL custom format (`*.dump`)
- Naming: `pre_scanner_tracking_YYYYMMDD_HHMMSS.dump`

To restore a backup:

```bash
pg_restore -d solidity_security -c backup_file.dump
```

---

## Queries vs. Markdown

### Before (Markdown)

```markdown
#### Slither
| **Total Detectors** | 99 |
| **Integration** | 18.2% |
```

**Problems:**
- Manual updates required
- No history tracking
- Difficult to query across scanners
- No automated comparisons
- Version info scattered across files

### After (Database)

```sql
SELECT * FROM scanner_versions WHERE scanner_name = 'slither';
```

**Benefits:**
- Automated queries
- Complete history in `scanner_version_history`
- Cross-scanner analytics
- Automated version comparison
- Single source of truth

---

## Future Enhancements

### Implemented

1. **GitHub Version Checking**: Tool-integration service checks GitHub API for latest versions (1-hour cache) - see `GITHUB_REPOS` in `blocksecops-tool-integration/src/main.py`
2. **Admin Dashboard Upgrade**: Admin System page shows version indicators and "Upgrade" button for one-click ConfigMap metadata updates - see [Scanner Upgrade Workflow](../workflows/scanner-upgrade-workflow.md)
3. **Audit Logging**: Scanner upgrades via admin dashboard are logged in the admin audit trail (`admin.scanner.upgrade` action)

### Potential Additions

1. **Alerting**: Trigger alerts when scanners become outdated
2. **CI/CD Integration**: Auto-update database from CI pipeline
3. **Full Pipeline Automation**: Integrate detector comparison, pattern seeding, and audit validation into the admin dashboard upgrade flow
4. **Automated Release Tracking**: Scrape GitHub releases periodically

### Schema Extensions

Future columns could include:
- `license` - Scanner license information
- `security_level` - Security classification
- `performance_metrics` - Scan time, memory usage
- `deprecation_date` - When scanner will be removed

---

## Files

### Schema & Data
- `schema.sql` - Database schema (tables, views, functions)
- `initial_data.sql` - Initial scanner data from ConfigMap
- `query_helpers.sql` - Common queries and helper functions

### Scripts
- `apply_migration.sh` - Apply schema and load data
- Auto-created backups in `../backups/`

### Documentation
- `SCANNER-VERSION-TRACKING.md` - This file

---

## Related Documentation

- **ConfigMap Source**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`
- **Database Schema**: `/Users/pwner/Git/ABS/database/SCHEMA.md`
- **Scanner Detector Tracking**: `/Users/pwner/Git/ABS/blocksecops-docs/SCANNER-DETECTOR-TRACKING.md`
- **Version Changelog**: `/Users/pwner/Git/ABS/blocksecops-docs/SCANNER-VERSION-CHANGELOG.md`

---

## Quick Reference

### Connect to Database

```bash
psql -d solidity_security
```

### Common Commands

```sql
-- View all scanners
\d scanner_versions

-- Run helper queries
\i /Users/pwner/Git/ABS/database/scanner-version-tracking/query_helpers.sql

-- Check specific scanner
SELECT * FROM scanner_version_status WHERE scanner_name = 'slither';

-- Update scanner
SELECT record_scanner_update('scanner_name', 'new_version', 'new_image_tag');
```

---

**Created**: 2025-10-30
**Last Updated**: 2026-02-05
**Maintained By**: BlockSecOps Platform Team
