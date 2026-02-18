# Scanner Audit Fixes - 4 Production Issues

**Date:** February 17, 2026
**Components:** blocksecops-tool-integration, blocksecops-api-service
**Versions:** tool-integration 0.4.5 -> 0.4.6, api-service 0.28.37 -> 0.28.38, scanner-solhint 0.1.7 -> 0.1.8

---

## Summary

A full scanner audit revealed 4 issues affecting the platform: solhint producing 0 vulnerabilities across 43 scans, vyper scanner misattributing findings, 10 contracts stuck in "scanning" status, and the canary health check CronJob failing with 422 errors. All 4 issues have been resolved.

---

## Fix 1: Solhint JSON Extraction (scanner-solhint 0.1.7 -> 0.1.8)

**Problem:** 43 completed solhint scans, 0 findings stored. The `solhint-scan` wrapper script extracted JSON from stdout using `grep '^\['`, but solhint's `--formatter json` may output JSON on lines with leading whitespace, BOM, or mixed with debug text.

**Root Cause:** `grep '^\['` on line 85 of `solhint-scan` only matches lines starting exactly with `[`.

**Fix:** Replaced brittle grep with 3-tier extraction:
1. `jq -e 'type == "array"'` validates if raw output is valid JSON array
2. Python regex fallback finds `[...]` in mixed output via `re.search(r'\[.*\]', raw, re.DOTALL)`
3. Falls back to empty `[]` with warning log

**Files Changed:**
- `scanner-images/solhint/solhint-scan` - Robust JSON extraction + findings count logging
- `scanner-images/solhint/Dockerfile` - Version label 0.1.7 -> 0.1.8
- `src/scanners/kubernetes_job_manager.py` - KJM fallback 0.1.7 -> 0.1.8
- `k8s/base/scanner-versions-configmap.yaml` - Base image version
- `k8s/overlays/local/scanner-versions-patch.yaml` - Harbor tag
- `k8s/overlays/production/scanner-versions-patch.yaml` - GCP AR tag

---

## Fix 2: Vyper scanner_id Override (tool-integration 0.4.6)

**Problem:** 38 completed vyper scans, 0 findings attributed to "vyper". The vyper callback handler used `vuln.get("scanner_id", scanner_type)` which took the SlitherParser's detector-specific ID instead of "vyper".

**Root Cause:** `SlitherParser._parse_detector()` sets `scanner_id` to "slither" (line 196 of `slither_parser.py`). The vyper handler copied this value instead of overriding it.

**Fix:** Changed `vuln.get("scanner_id", scanner_type)` to `scanner_type` directly in the vyper callback handler. Added diagnostic logging for Slither detector count before parsing.

**Files Changed:**
- `src/main.py` - Force `scanner_id` to `scanner_type`, add detector count logging
- `scanner-images/vyper/run-vyper.sh` - Add detector count logging after Slither output

---

## Fix 3: Stale Scan Recovery (api-service 0.28.38)

**Problem:** 10 contracts stuck in "scanning" status. Contract status is set to "scanning" at scan creation but only reset when `store_scan_results` is called. If scanner jobs complete without posting results (crash, network error), contracts stay stuck forever.

**Fix:** Added `POST /maintenance/recover-stale-scans` endpoint (internal auth only). Finds scans stuck in `queued`/`running` for >1 hour, marks them `failed`, resets contract status from "scanning" to "scanned".

**Data Fix SQL for existing stuck contracts:**
```sql
UPDATE contracts SET status = 'scanned'
WHERE status = 'scanning'
AND id NOT IN (
    SELECT DISTINCT contract_id FROM scans
    WHERE status IN ('queued', 'running')
);
```

**Files Changed:**
- `src/presentation/api/v1/endpoints/scans.py` - New maintenance endpoint + code snippet extraction fallback

---

## Fix 4: Canary CronJob UUID (tool-integration 0.4.6)

**Problem:** The canary CronJob generates `canary-$(date +%s)` as scan ID (not UUID). FastAPI rejects it with 422 because `scan_id: UUID` is validated.

**Fix:** Replaced `CANARY_ID="canary-$(date +%s)"` with `CANARY_ID=$(cat /proc/sys/kernel/random/uuid)`.

**Files Changed:**
- `k8s/base/canary-cronjob.yaml` - UUID-based canary scan ID

---

## Bonus Fix: Code Snippet Extraction Fallback

**Problem:** Many vulnerabilities have `code_snippet = NULL`, which disables the "Generate AI Repair" button and hides the Code Location section on the vulnerability detail page.

**Fix:** Added server-side code snippet extraction in `store_scan_results`. When a vulnerability has a `line_number` but no `code_snippet`, the API service reads the contract's source code and extracts a 5-line context window (2 lines before + target line with arrow marker + 2 lines after). Supports both single-file contracts (`contract.source_code`) and multi-file contracts (`ContractFileModel.file_content`).

---

## Tests Added

| Test File | Tests | Description |
|-----------|-------|-------------|
| `tests/unit/scanners/test_solhint_json_extraction.py` | 15 | JSON extraction with various formats |
| `tests/unit/scanners/test_vyper_scanner_id.py` | 4 | scanner_id override verification |
| `tests/unit/test_stale_scan_recovery.py` | 10 | Recovery endpoint verification |

---

## Deployment

- Built and pushed to Harbor: api-service:0.28.38, tool-integration:0.4.6, scanner-solhint:0.1.8
- Deployed via `kubectl apply -k k8s/overlays/local/`
- Both services rolled out and verified healthy
- All 29 tests passing
