# Feature Test 84: Stuck Contract Fix & Upload Security Hardening (February 28, 2026)

## Overview

API service v0.29.43 fixes 10 contracts stuck in "scanning" status, adds source code validation on scan and contract creation, hardens upload endpoints against binary injection and null bytes, and deploys a CronJob for automated stale scan recovery every 15 minutes.

## Test Results

### Fix 1: Source Code Validation — Scan Creation

**Problem:** `create_scan()` accepted scan requests for contracts with no source code and `is_multi_file=false`. The scan would be dispatched but could never complete, eventually causing the contract to become stuck in "scanning" status.

**Fix:**
- Added validation in `create_scan()` — rejects scans for contracts without `source_code` where `is_multi_file` is false. Returns HTTP 400.
- Added same validation in `create_batch_scan()` — skips contracts without source code.

**Verification:**
```bash
# Attempt to scan a contract with no source code
curl -sk -X POST https://app.0xapogee.com/api/v1/scans \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"contract_id": "<no-source-contract-id>", "scanners": ["slither"]}' \
  | jq '.detail'
# Expected: HTTP 400, error message indicating contract has no source code
```

**Result:** PASS

---

### Fix 2: Contract Creation Validation

**Problem:** Contracts could be created via API with neither an Ethereum address nor source code. A GNosis contract was created this way and became permanently unscannable. Additionally, the upload path for source code did not enforce size limits or reject null bytes.

**Fix:**
- `src/presentation/schemas/contracts.py`: `model_validator(mode='after')` now enforces "either address or source_code required". Returns HTTP 422.
- `src/presentation/api/v1/endpoints/contracts.py`: `source_code` size capped at 10MB (HTTP 413). Null bytes in `source_code` rejected (HTTP 400).

**Verification:**
```bash
# Empty contract (no address, no source)
curl -sk -X POST https://app.0xapogee.com/api/v1/contracts \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"name": "EmptyContract"}' | jq '.status_code'
# Expected: 422

# Contract with null bytes in source code
curl -sk -X POST https://app.0xapogee.com/api/v1/contracts \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"BadContract\", \"source_code\": \"pragma solidity\x00^0.8.0;\"}" | jq '.status_code'
# Expected: 400
```

**Result:** PASS

---

### Fix 3: Enhanced Stale Scan Recovery (Phase 2)

**Problem:** The existing `recover_stale_scans()` endpoint recovered scans stuck in `queued`/`running` but did not correct the downstream contract status. Contracts whose associated scans had all completed or failed could still be left in `"scanning"` status indefinitely.

**Fix:** `recover_stale_scans()` now includes Phase 2 — finds contracts in `"scanning"` status with no active (`queued`/`running`) scans and resets them to `"scanned"` or `"uploaded"` as appropriate.

**Verification:**
```bash
# Manually trigger recovery (internal endpoint)
curl -sk -X POST https://app.0xapogee.com/api/v1/scans/maintenance/recover-stale-scans \
  -H "X-Internal-Service: true"
# Expected: 200 with recovery summary including contracts fixed

# Confirm no contracts are stuck
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  -c "SELECT count(*) FROM contracts WHERE status = 'scanning'
      AND id NOT IN (
        SELECT DISTINCT contract_id FROM scans
        WHERE status IN ('queued', 'running')
      );"
# Expected: 0
```

**Pre-fix database state:** 10 contracts stuck in `"scanning"` (9 fixed to `"scanned"`, 1 GNosis fixed to `"uploaded"`).

**Result:** PASS

---

### Fix 4: Stale Scan Recovery CronJob

**Problem:** Stale scan recovery required manual invocation or relied on an existing deduplication CronJob with a 6-hour interval — too infrequent to catch newly stuck contracts quickly.

**Fix:**
- New `stale_scan_recovery.py` standalone script in `src/infrastructure/tasks/`.
- New Kubernetes CronJob `cronjob-stale-scan-recovery.yaml` running every 15 minutes with `concurrencyPolicy: Forbid`.

**Verification:**
```bash
# Confirm CronJob is deployed and scheduled
kubectl get cronjob stale-scan-recovery -n api-service-local
# Expected: schedule "*/15 * * * *", ACTIVE 0/1, LAST SCHEDULE recent

# Check most recent job completed successfully
kubectl get jobs -n api-service-local -l app=stale-scan-recovery \
  --sort-by=.metadata.creationTimestamp
# Expected: at least one Completed job
```

**Result:** PASS

---

### Fix 5: Upload Security Hardening

**Problem:** The single-file upload endpoint did not check binary file signatures, allowing ELF, PE, Mach-O, WASM, OLE compound document, and PDF files to be uploaded. Null bytes were also accepted without rejection.

**Fix:** `src/presentation/api/v1/endpoints/upload.py` now:
- Reads the first 8 bytes of any non-archive upload and rejects files matching known binary magic bytes (ELF `\x7fELF`, PE `MZ`, Mach-O variants, WASM `\x00asm`, OLE `\xd0\xcf\x11\xe0`, PDF `%PDF`). Returns HTTP 400.
- Scans file content for null bytes before accepting. Returns HTTP 400.

**Verification:**
```bash
# Upload an ELF binary
curl -sk -X POST https://app.0xapogee.com/api/v1/upload \
  -H "Authorization: Bearer $JWT" \
  -F "file=@/bin/ls" | jq '.status_code'
# Expected: 400

# Upload a PDF
curl -sk -X POST https://app.0xapogee.com/api/v1/upload \
  -H "Authorization: Bearer $JWT" \
  -F "file=@/tmp/test.pdf" | jq '.status_code'
# Expected: 400

# Upload a valid Solidity file (should succeed)
curl -sk -X POST https://app.0xapogee.com/api/v1/upload \
  -H "Authorization: Bearer $JWT" \
  -F "file=@/tmp/Token.sol" | jq '.status_code'
# Expected: 200
```

**Result:** PASS

---

### End-to-End Scan Regression

**Test:** Full scan on a multi-scanner contract (scan 51276b83) to confirm all fixes do not break the existing scan pipeline.

| Scanner | Findings | Status |
|---------|----------|--------|
| slither | 24 | PASS |
| aderyn | 31 | PASS |
| soliditydefend | 1 | PASS |

**Result:** PASS

---

## Version Bump

| Service | Old | New |
|---------|-----|-----|
| api-service | 0.29.42 | 0.29.43 |

## Files Changed

- `src/presentation/api/v1/endpoints/scans.py` — source code validation; Phase 2 stale recovery
- `src/presentation/schemas/contracts.py` — model_validator (address or source_code required)
- `src/presentation/api/v1/endpoints/contracts.py` — source_code size limit and null byte check
- `src/presentation/api/v1/endpoints/upload.py` — binary signature and null byte detection
- `src/infrastructure/tasks/stale_scan_recovery.py` — new standalone maintenance script
- `k8s/base/api-service/cronjob-stale-scan-recovery.yaml` — new CronJob (every 15 min)
- `k8s/base/api-service/kustomization.yaml` — CronJob added to resources
- `pyproject.toml`, `k8s/overlays/local/api-service/kustomization.yaml` — version bump
