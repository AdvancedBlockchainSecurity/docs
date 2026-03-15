# Intelligence System Audit — 2026-03-15

## Scope

AI/ML, deduplication, and pattern matching system. Covers codebase, cluster, logs, errors, tests, database state, and documentation.

## Tests

| Suite | Tests | Result |
|-------|-------|--------|
| API service ML/dedup/intelligence | 609 | passed (1 skipped) |
| Intelligence Engine (unit+integration+real model) | 39 | passed |

## Documentation

All workflows, pipelines, playbooks current. No gaps.

## Database

| Metric | Count |
|--------|-------|
| Patterns | 415 |
| Pattern-tool mappings | 707 |
| Vulnerabilities | 20,310 |
| Code fingerprints | 12,980 (64%) |
| Semantic fingerprints | 9,601 (47%) |
| Pattern codes assigned | 16,008 (79%) |
| In dedup groups | 8,720 (43%) |
| FP scores | 763 (4%) |
| Dedup groups | 2,783 |
| FP classifier | v1.0.1, accuracy 96.1%, AUC 0.97 |

## Findings

### F1 — CRITICAL: Intelligence Engine port mismatch — FIXED

ConfigMap had `intelligence_engine_url` pointing to port 80. IE service exposes port 8000. Semantic deduplication (Level 5) was completely broken — Celery worker SIGKILL'd after 600s timeout retrying failed connections.

Fixed in: base configmap, local overlay, GCP overlay. Applied and verified.

### F2 — MEDIUM: Pattern naming inconsistency

20 patterns use long category names instead of 3-letter abbreviations. 13 patterns use `BVD-SOL-` instead of `BVD-SOLANA-`. 4 patterns use non-standard language prefixes (ERC, COL, COD, LOC). Requires database migration — tracked as follow-up.

### F3 — LOW: Low semantic fingerprint coverage (47%)

Expected due to F1 (IE unreachable). Will improve after CronJob backfill with fixed connectivity.

### F4 — LOW: Zero user classifications

System functional but unused. Active learning queue ready for user engagement.

### F5 — CRITICAL: FP prediction not wired into scan ingestion — FIXED

`FalsePositivePredictor.predict_false_positive_score()` was never called from `store_scan_results()`. Pipeline Stage 4 existed in code but was unreachable. 19,547 of 20,310 vulnerabilities had no FP score. The 763 existing scores were from a February 2026 backfill.

Fixed in: `src/presentation/api/v1/endpoints/scans.py` — added `FalsePositivePredictor` import, initialization, and inline call during vulnerability creation. Version bump 0.29.91 → 0.29.92. Built, pushed, deployed.
