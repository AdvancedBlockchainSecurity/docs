# Seed Data Automation & Platform Fixes Audit

**Date:** March 18, 2026
**Scope:** Comprehensive audit of seed data automation, scanner fixes, pattern ID convention, and API auth
**Auditor:** Platform Engineering
**Platform Version:** api-service 0.34.1, orchestration 0.11.2, dashboard 0.48.0, tool-integration 0.5.35

---

## Executive Summary

Automated 5 seed data mechanisms that previously required manual scripts, fixed Foundry project scanning across 7 scanner images, consolidated pattern ID generation with validation guards, and fixed API key authentication for 16 read-only endpoints. Total of **186 tests** (161 api-service + 25 scanner upgrade pipeline) across the affected code paths. All services deployed and verified on GKE production.

---

## 1. Seed Data Automation Audit

### 1.1 ML Model Training Automation

| Check | Result |
|-------|--------|
| Celery Beat `ml.check_model_freshness` at 02:00 UTC | PASS — registered in beat_schedule |
| Never-trained model detection | PASS — queries `ml_model_metadata` for null `last_trained_at` |
| Stale model detection (>7 days) | PASS — compares age against `MAX_MODEL_AGE_HOURS` |
| Training via internal endpoint | PASS — `POST /internal/ml/execute-training` with real sklearn |
| Label threshold trigger (100 labels) | PASS — `LabelCounter` increments and triggers at threshold |
| JSON-only Celery serialization | PASS — `serializer="json"`, `accept_content=["json"]` |
| Internal service key auth | PASS — `X-Internal-Service-Key` header required |
| Dashboard "Train Now" button | PASS — `ModelStatusWidget` calls `/admin/system/ml/retrain` |
| Scanner quality page untrained state | PASS — shows info card, not blank gauges |
| Tests | 15 regression + 20 Celery task tests passing |

### 1.2 Scanner Pattern Auto-Detection

| Check | Result |
|-------|--------|
| Post-scan hook in `scan_tasks_sync.py` | PASS — fires `autodetect_patterns_task.delay()` after commit |
| Daily sweep at 03:00 UTC | PASS — `pattern.check_unmapped` in beat_schedule |
| Category inference (14 categories) | PASS — keyword scoring across all categories |
| Pattern ID follows convention | PASS — uses canonical `pattern_id.py` module |
| Validation guard on insert | PASS — `validate_pattern_id()` + auto-correct |
| Backfill existing vulnerabilities | PASS — raw SQL joins on scanner_id + title-derived detector_id |
| `db.flush()` between patterns and mappings | PASS — prevents FK violation |
| Tests | 24 auto-detection + 14 Celery task tests passing |

### 1.3 Vulnerability Pattern Startup Seeding

| Check | Result |
|-------|--------|
| Runs on API service startup (lifespan hook) | PASS — after `init_db()` |
| Version tracking in `ml_model_metadata` | PASS — model_name = `pattern_seed` |
| Idempotent upsert | PASS — inserts new, updates changed, skips unchanged |
| Handles dict-type remediation (Solana) | PASS — JSON serialization |
| Handles reserved word `references` | PASS — quoted in UPDATE |
| Current seed version | v3.14 (Cairo removed) |
| Current pattern count | 594 (383 curated + auto-detected) |
| Tests | 16 seed validation tests passing |

### 1.4 Exploit & CVE Intelligence Startup Seeding

| Check | Result |
|-------|--------|
| Runs on startup after pattern seeding | PASS |
| Version tracking | PASS — model_name = `exploit_cve_seed`, version v1.0 |
| Idempotent (keyed by title/cve_id) | PASS |
| Exploit count | 10 |
| CVE count | 10 |
| CVE ID format (CVE-YYYY-NNNNN) | PASS — all 10 valid |
| Tests | 18 seed validation tests passing |

### 1.5 Scanner Version Tracking

| Check | Result |
|-------|--------|
| Alembic migration 085 | PASS — `scanner_versions` table created |
| Startup seeding from ConfigMap | PASS — reads `SCANNER_METADATA` env var |
| Content-hash version tracking | PASS — detects ConfigMap changes |
| Admin upgrade writes to table | PASS — `upsert_scanner_versions()` called in endpoint |
| Scanner count | 16 |
| `SCANNER_METADATA` env var in deployment | PASS — added to base manifest |
| Tests | 17 seed + 5 upgrade integration tests passing |

---

## 2. Scanner Solc/Forge-std Audit

### 2.1 Solc Pre-Installation

| Scanner | solc-select (/opt) | .svm (/opt) | Versions | Image |
|---------|-------------------|-------------|----------|-------|
| slither | PASS | N/A | 8 (0.8.13-0.8.28) | 0.3.9 |
| aderyn | PASS | PASS | 8 | 0.7.8 |
| soliditydefend | PASS | PASS | 8 | 0.9.5 |
| halmos | PASS | PASS | 8 | 0.3.7 |
| wake | PASS | PASS | 8 | 0.4.4 |
| medusa | PASS | N/A | 8 | 0.3.5 |
| echidna | PASS | N/A | 8 | 0.3.4 |
| orchestration base | PASS | PASS | 8 | 1.0.0-8324207c |

### 2.2 Forge-std Pre-Installation

| Scanner | forge-std v1.9.6 | Offline mode | Run script updated |
|---------|-----------------|-------------|-------------------|
| aderyn | PASS | PASS (`offline = true`) | PASS |
| slither | PASS | N/A | PASS (copies from /opt) |
| wake | PASS | PASS (`offline = true`) | PASS |
| soliditydefend | PASS | N/A | N/A (no Foundry project support) |
| halmos | PASS | N/A | N/A (no Foundry project support) |

### 2.3 No External Downloads at Runtime

| Check | Result |
|-------|--------|
| NetworkPolicy blocks outbound HTTPS | PASS — by design |
| No `forge install` in run scripts | PASS — copies from /opt/forge-std |
| No solc download in run scripts | PASS — pre-installed |
| Foundry project scan completes | PASS — 50 vulns found on VulnerableVault |

---

## 3. Pattern ID Convention Audit

### 3.1 Naming Convention

| Check | Result |
|-------|--------|
| Canonical format regex | `^BVD-(SOLIDITY\|SOLANA\|VYPER\|MOVE)-[A-Z][A-Z0-9\-]{1,19}-\d{3}$` |
| Single source of truth | PASS — `src/domain/services/pattern_id.py` |
| Old `BVD-SOL-*` format rejected | PASS — 0 remaining in DB |
| Sequential numbering | PASS — queries MAX existing number |
| Ecosystem from scanner/language | PASS — `SCANNER_ECOSYSTEM_MAP` |
| Duplicate `generate_pattern_code` removed from `scanner_upgrade_service.py` | PASS |
| Validation guard in `apply_seeds()` | PASS — auto-corrects invalid IDs |
| 159 bad patterns renamed | PASS — copy-remap-delete (FK-safe) |
| Tests | 34 pattern ID validation tests passing |

### 3.2 Pattern Distribution

| Ecosystem | Count |
|-----------|-------|
| SOLIDITY | 461 |
| VYPER | 99 |
| SOLANA | 34 |
| CAIRO | 0 (removed) |
| **Total** | **594** |

---

## 4. API Key Authentication Audit

### 4.1 Fixed Endpoints (JWT-only → get_current_user_or_api_key)

| File | Endpoints Fixed |
|------|----------------|
| `intelligence.py` | 8 GET endpoints (exploits, CVEs, stats, NVD, SWC) |
| `ml.py` | 7 GET endpoints (model-stats, scanner-quality, training-data, etc.) |
| `patterns.py` | 3 GET endpoints (list, detail, statistics) |
| **Total** | **18 GET endpoints** |

### 4.2 Verification

| Endpoint | API Key Auth |
|----------|-------------|
| `GET /intelligence/exploits` | PASS — returns 10 |
| `GET /intelligence/cves` | PASS — returns 10 |
| `GET /ml/model-stats` | PASS — returns training data |
| `GET /ml/scanner-quality` | PASS — returns 5 scanners |
| `GET /intelligence/patterns` | PASS — returns 594 |

---

## 5. Cairo Cleanup Audit

| Check | Result |
|-------|--------|
| Cairo patterns removed from seed file | PASS — 0 in v3.14 |
| Cairo patterns removed from database | PASS — 0 remaining |
| Cairo mappings removed | PASS — 0 remaining |
| Vulnerabilities referencing Cairo | 0 (none existed) |
| Pattern ID validator rejects CAIRO | PASS — not in ecosystem regex |
| `test_no_cairo_patterns` test | PASS |

---

## 6. E2E Scan Test Results

| Test | Scanners | Status | Vulns | Pattern Coverage |
|------|----------|--------|-------|-----------------|
| Single Solidity (SimpleToken) | slither, aderyn, soliditydefend | completed | 23 | 100% |
| Foundry VulnerableVault | slither, aderyn, soliditydefend | completed | 50 | 100% |
| Hardhat VulnerableVault | slither, soliditydefend, semgrep | completed | 56 | 100% |
| WETH9 from Etherscan | slither, aderyn, soliditydefend, wake | completed | 47 | 100% |

---

## 7. Test Summary

| Suite | Tests | Status |
|-------|-------|--------|
| ML training regression | 15 | PASS |
| ML Celery tasks | 20 | PASS |
| Pattern auto-detection | 22 | PASS |
| Pattern Celery tasks | 14 | PASS |
| Pattern seed service | 16 | PASS |
| Exploit/CVE seed service | 18 | PASS |
| Scanner version seed service | 17 | PASS |
| Pattern ID validation | 34 | PASS |
| Scanner upgrade integration | 5 | PASS |
| Scanner upgrade pipeline | 25 | PASS |
| **Total** | **186** | **All passing** |

---

## 8. Deployment Summary

| Service | Version | Image | GKE Status |
|---------|---------|-------|------------|
| api-service | 0.34.1 | `apogee/api-service:0.34.1` | Running, healthy |
| orchestration | 0.11.2 | `apogee/orchestration:0.11.2` | Running, healthy |
| dashboard | 0.48.0 | `apogee/dashboard:0.48.0` | Running, healthy |
| tool-integration | 0.5.35 | `apogee/tool-integration:0.5.35` | Running, healthy |

### Scanner Image Versions

| Scanner | Image Version |
|---------|--------------|
| aderyn | 0.7.8 |
| slither | 0.3.9 |
| soliditydefend | 0.9.5 |
| halmos | 0.3.7 |
| wake | 0.4.4 |
| medusa | 0.3.5 |
| echidna | 0.3.4 |

---

## 9. Database Backups

| Backup | Size | Location |
|--------|------|----------|
| Pre-pattern-ID-fix | 13MB | `docs/database/backups/pre-pattern-id-fix_20260317_213909.dump` |
| Pre-Cairo-cleanup | 13MB | `docs/database/backups/pre-cairo-cleanup_20260318_170833.dump` |

---

## 10. PRs Merged During This Session

| Repo | PRs | Key Changes |
|------|-----|-------------|
| blocksecops-api-service | #329-#338 | Seed automation, pattern ID, API key auth, Cairo cleanup |
| blocksecops-orchestration | #103-#105 | ML tasks, pattern tasks, solc base image |
| blocksecops-dashboard | #206-#207 | ModelStatusWidget, ScannerQualityPage |
| blocksecops-tool-integration | #142 | Solc/forge-std pre-install, 7 scanner images |
| blocksecops-shared | #48 | Cairo removal from schemas |
| docs | #398-#406 | Workflows, pipelines, playbooks, backups |
| TaskDocs-BlockSecOps | #248-#252 | Implementation summaries |
