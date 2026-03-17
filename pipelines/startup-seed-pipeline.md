# Startup Seed Pipeline

**Last Updated:** March 2026
**Service:** api-service
**Version:** 0.33.2+

---

## Overview

On every API service pod startup, three seed services run sequentially after database initialization. Each loads curated data from bundled files or ConfigMap, tracks versions to avoid redundant work, and is fully idempotent.

```
Pod Start → init_db() → Pattern Seed → Exploit/CVE Seed → Scanner Version Seed → WebSocket → Ready
```

## Pipeline Stages

| # | Stage | Source | Table(s) | Records | Version Tracking |
|---|-------|--------|----------|---------|-----------------|
| 1 | Vulnerability Patterns | `seeds/vulnerability_patterns.json` | `vulnerability_patterns`, `pattern_tool_mappings` | 397 patterns, 678 mappings | `ml_model_metadata` (model_name = `pattern_seed`) |
| 2 | Exploits & CVEs | `seeds/exploits_and_cves.json` | `exploits`, `cves` | 10 exploits, 10 CVEs | `ml_model_metadata` (model_name = `exploit_cve_seed`) |
| 3 | Scanner Versions | `SCANNER_METADATA` env var (ConfigMap) | `scanner_versions` | 16 scanners | `ml_model_metadata` (model_name = `scanner_version_seed`) |

## Behavior

- **First startup (empty DB)**: All three stages insert full datasets. Logs show counts.
- **Subsequent restarts (up to date)**: Each stage compares version/hash, skips if unchanged. No DB writes.
- **Updated seed file deployed**: Version mismatch detected, new/changed records upserted.
- **ConfigMap changed**: Scanner version content hash changes, triggering upsert of updated scanner metadata.
- **Failure in any stage**: Logged as warning, does not block service startup. Other stages still run.

## Version Tracking

All three stages store their version in the `ml_model_metadata` table:

```sql
SELECT model_name, current_version FROM ml_model_metadata
WHERE model_name IN ('pattern_seed', 'exploit_cve_seed', 'scanner_version_seed');
```

| model_name | version format |
|-----------|---------------|
| `pattern_seed` | `v3.13` (from seed file) |
| `exploit_cve_seed` | `v1.0` (from seed file) |
| `scanner_version_seed` | `configmap-{hash}` (content hash) |

## Manual Re-Seed Endpoints

All require `X-Internal-Service-Key` header (BSO-SEC-004):

| Endpoint | Purpose |
|----------|---------|
| `POST /api/v1/internal/patterns/seed` | Force re-seed vulnerability patterns |
| `POST /api/v1/internal/intelligence/seed` | Force re-seed exploits and CVEs |
| `POST /api/v1/internal/scanners/seed` | Force re-seed scanner versions |

## Key Files

| File | Purpose |
|------|---------|
| `src/main.py` (lifespan) | Startup hook that calls all three seed services |
| `src/application/services/pattern_seed_service.py` | Pattern seeding logic |
| `src/application/services/exploit_cve_seed_service.py` | Exploit/CVE seeding logic |
| `src/application/services/scanner_version_seed_service.py` | Scanner version seeding logic |
| `seeds/vulnerability_patterns.json` | Curated pattern data (737KB) |
| `seeds/exploits_and_cves.json` | Curated exploit/CVE data |

## Verification

```sql
-- Check all seed versions
SELECT model_name, current_version, updated_at
FROM ml_model_metadata
WHERE model_name LIKE '%seed%'
ORDER BY model_name;

-- Check record counts
SELECT 'patterns' AS table_name, COUNT(*) FROM vulnerability_patterns
UNION ALL SELECT 'mappings', COUNT(*) FROM pattern_tool_mappings
UNION ALL SELECT 'exploits', COUNT(*) FROM exploits
UNION ALL SELECT 'cves', COUNT(*) FROM cves
UNION ALL SELECT 'scanners', COUNT(*) FROM scanner_versions;
```
