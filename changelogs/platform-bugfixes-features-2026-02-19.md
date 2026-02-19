# Changelog: Platform Bug Fixes, Features & Security Hardening

**Date:** 2026-02-19

## Service Versions

| Service | Version |
|---------|---------|
| api-service | 0.28.54 |
| dashboard | 0.45.12 |
| orchestration | 0.9.16 |
| tool-integration | 0.4.8 |

## Bug Fixes

### Pattern Detail Shows Wrong Findings
- Pattern detail page "Recent Findings" now filters by `pattern_id` instead of showing global vulnerabilities
- Added "Related Contracts" section to pattern detail page
- **API:** Added `pattern_id` query parameter to `GET /vulnerabilities`

### Vulnerability Code Snippet Shows Pragma Line
- SolidityDefendParser now skips snippet extraction when `line_number == 1`
- Tool-integration parser rejects snippets starting with `pragma solidity`
- API lazy extraction rejects pragma-only snippets

### ML Classification "Failed to Save Label"
- Added ownership verification before allowing label save (security fix)
- Used `db.begin_nested()` savepoint for provenance insert (prevents session corruption on failure)
- Frontend now shows actual API error message instead of generic text
- Frontend passes `currentLabel` to labeling panel and invalidates queries on success

### Invariant Generation Errors
- Added proper error handling for missing/invalid Anthropic API key (returns 503 instead of 500)
- Fixed tier display name from `growth` to `team` in 403 handler
- Added distinct error messages for 429 (rate limit) and 503 (service unavailable)
- Added source code guard message for multi-file contracts without source

### 413 Error on Zip Upload
- Added `exempt_paths` to `RequestSizeLimitMiddleware` so upload endpoint can enforce its own per-tier limits
- Global 10MB limit no longer blocks legitimate enterprise-tier archives (up to 100MB)

### Contract Project Not Visible After Adding
- Fixed cache invalidation: page now re-fetches contract data after project assignment
- "Add to Project" dropdown now excludes already-assigned projects

### Address Not Showing After Upload
- Upload endpoint now accepts and validates `address` parameter (`^0x[0-9a-fA-F]{40}$`)
- Contract detail and vulnerability detail pages hide zero-address placeholder (`0x000...000`)

## New Features

### Pattern Sorting (Patterns List Page)
- Sortable by: severity, name, category, false positive rate, date created
- Ascending/descending toggle
- Pagination with prev/next controls
- Severity sort uses weighted ordering (critical=0, high=1, medium=2, low=3, info=4, optimization=5, varies=6)
- **Security:** Sort columns resolved via dict lookup (SQL injection safe)

### Patterns View in Scan Results
- New "Patterns" tab alongside "Vulnerabilities" on scan results page
- Groups findings by pattern code with severity breakdown and scanner badges
- Links to pattern detail page for each pattern

### Rust Scanner Dropdown
- Added 7 scanners to scan results filter: Sol-azy, Sec3 X-ray, Trident, Cargo Fuzz Solana, RustDefend, Moccasin, Vyper

### Generate Repair Without Code Snippet
- "Generate AI Repair" button now enabled when contract has source code, even if vulnerability has no `code_snippet`
- Backend extracts code from `ContractModel.source_code` or `ContractFileModel.file_content` as fallback

### SCM PR Creation
- New `SCMService` supporting GitHub REST v3 and GitLab REST v4
- New endpoint: `POST /organizations/{org_id}/integrations/{id}/repositories/{repo_id}/pull-requests`
- Creates branch, commits fix, opens PR in one operation
- Branch names sanitized (regex + 100-char cap)
- "Create Pull Request" button on vulnerability detail when repair exists with file_path

### Admin Pattern Management
- `GET /admin/patterns/mappings/audit` — finds unmapped (scanner_id, detector_id) pairs
- `POST /admin/patterns/{target_id}/merge` — merges source pattern into target (moves vulns + mappings, deactivates source)

## Security Hardening

- ML label endpoint: ownership verification before save
- DB savepoints for secondary operations (prevents session corruption)
- Address validation: strict hex regex
- Pattern sort: allowlist-validated column selection
- Error sanitization: `get_safe_error_detail()` on all new endpoints
- SCM service: branch name sanitization, tokens never logged
- Upload middleware: path-based exemption preserves tier enforcement

## Post-Deployment Audit Fixes (API 0.28.53 → 0.28.54, Orchestration 0.9.16)

### API Service 0.28.53 → 0.28.54
- **Scan duration_seconds persistence:** Added `duration_seconds` calculation at all scan completion points (success, failure, stale recovery, admin force-fail). Pattern: `scan.duration_seconds = int((completed_at - started_at).total_seconds())`
- **Vulnerability pagination tie-breaker:** Added secondary sort by `id DESC` to offset-based pagination to prevent duplicate/missing rows across pages
- **VulnerabilityResponse schema:** Added `file_path` and `false_positive_score` fields to Pydantic response schema (columns existed in DB but were missing from API response)
- **ML model writable directory:** Made `MODEL_DIR` configurable via `ML_MODEL_DIR` env var (default: `/app/.cache/ml-models`) since container filesystem is read-only
- **Solana CWE seed fix:** Updated `seed_solana_direct.py` ON CONFLICT clause to include `cwe_id` in upsert

### Orchestration 0.9.16
- **Scan duration_seconds persistence:** Added `duration_seconds` calculation at 6 completion points in `scan_tasks_sync.py` (success, failure, stale, no-source, timeout, error)

### Data Backfills Applied
- **219 existing scans:** Backfilled `duration_seconds` from `started_at`/`completed_at` timestamps
- **32 Solana patterns:** Updated `cwe_id` from source JSON (e.g., CWE-20, CWE-664, CWE-682)
- **763 vulnerabilities:** Batch-predicted `false_positive_score` using trained ML model (97.4% accuracy, 0.995 AUC)

## Post-Deployment Fixes (API 0.28.47 → 0.28.52, Dashboard 0.45.9 → 0.45.12)

### API Service Fixes
- **0.28.47:** Case-insensitive pattern sort — added `func.lower()` for text columns (name, category)
- **0.28.48:** Invariant tier fix — `get_tier()` returns Tier object, not dict; changed `.get('quotas')` to `.quotas.monthly_ai_invariants_limit`
- **0.28.49:** Upload address parameter — changed bare `Optional[str] = None` to `Form(None)` for multipart form handling
- **0.28.50:** Admin pattern audit/merge fix — `log_admin_action()` calls used wrong parameters (`admin_id` instead of `admin`, missing `request`), causing TypeError on endpoint access; added `Request` dependency to both endpoints
- **0.28.51:** Severity sort completeness — added `optimization` and `varies` to severity ordering case statement (were falling to `else_=5`, appearing before `critical` in DESC)
- **0.28.52:** Severity sort direction fix — inverted `asc()`/`desc()` on case values so DESC returns `critical` first (case value 0 → ascending) and ASC returns `varies` first

### Dashboard Fixes
- **0.45.10:** React hooks ordering — moved `useMemo` for `patternAggregates` before early returns in `ScanResults.tsx` (was causing "Rendered more hooks than during the previous render" crash); Fixed `PatternDetail.tsx` to match actual API response shape (array `scanner_breakdown`, `severity_distribution` key, `scanners_detecting`/`most_common_scanner`/`active_findings` fields); Added project display badges to `ContractDetail.tsx`
- **0.45.11:** Rebuilt with correct Supabase credentials from ConfigMap (previous build used placeholders, breaking authentication)
- **0.45.12:** Fixed `RecentScans.tsx` link from `/scan-results/:id` to `/scans/:id` (route mismatch caused blank page)

## Infrastructure

- Contract table overflow: fixed with `table-fixed`, `truncate`, `overflow-x-auto`
- api-service kustomization: added full `app.kubernetes.io/*` label set (was missing)
- tool-integration: version bump 0.4.7 -> 0.4.8 for pragma snippet fix
- Dashboard builds: must source Supabase credentials from ConfigMap per `docs/standards/frontend-build-env.md`

## Database

No Alembic migrations required. All changes use existing columns and tables.

### Manual Data Operations (2026-02-19)
- Backfilled `scans.duration_seconds` for 219 existing scans
- Updated `vulnerability_patterns.cwe_id` for 32 Solana patterns
- ML model trained on 384 labeled samples, batch-predicted 763 vulnerabilities with `false_positive_score`
- Temporary `platform_admin` role granted/revoked for ML training (enterprise user)
