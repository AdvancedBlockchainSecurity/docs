# API Service v0.29.43 - Stuck Contract Fix & Upload Security Hardening

**Date:** February 28, 2026
**Version:** 0.29.42 → 0.29.43
**Type:** Bug fix / Security hardening (PATCH)

## Summary

Fixed 10 contracts stuck in "scanning" status due to a race condition in `create_scan()`, added source code validation to prevent scans on contracts without source, hardened upload endpoints against binary file injection and null bytes, added contract creation schema validation, and deployed a CronJob for automated stale scan recovery every 15 minutes.

## Root Cause Analysis

### Race Condition: Stuck Contract Status (High)

`create_scan()` unconditionally sets `contract.status = "scanning"` before dispatching the scan job. If the scanner job completes without posting results (container crash, network error, callback failure), the contract status is never reset. The existing maintenance endpoint recovered scans stuck in `queued`/`running`, but did not handle the second-order problem: contracts whose status remained `scanning` even after all associated scans had completed or failed.

### Missing Schema Enforcement: GNosis Contract (Medium)

A GNosis contract was created via API with an Ethereum address only and no source code. The contract schema documented that either an address or source code was required but did not enforce this constraint, allowing a contract to exist in a state that could never be scanned.

### Missing Binary Signature Checks on Upload (Medium)

The single-file upload endpoint validated MIME type and file extension but did not check binary file signatures. This allowed ELF, PE, Mach-O, WASM, OLE, and PDF binaries to be uploaded, and did not reject files containing null bytes.

## Changes

### Fix 1: Source Code Validation in Scan Creation (`src/presentation/api/v1/endpoints/scans.py`)

- `create_scan()`: Added validation that rejects scan creation for contracts without `source_code` and where `is_multi_file` is false. Returns HTTP 400.
- `create_batch_scan()`: Added same validation — contracts without source code are skipped in batch operations.

### Fix 2: Contract Creation Validation

- `src/presentation/schemas/contracts.py`: Added `model_validator(mode='after')` enforcing "either address or source_code required". Returns HTTP 422 on violation.
- `src/presentation/api/v1/endpoints/contracts.py`: Added `source_code` size limit (10MB, HTTP 413) and null byte check (HTTP 400).

### Fix 3: Enhanced Stale Scan Recovery (`src/presentation/api/v1/endpoints/scans.py`)

Enhanced `recover_stale_scans()` with Phase 2 recovery: finds contracts stuck in `"scanning"` status with no active (`queued`/`running`) scans and resets their status to `"scanned"` or `"uploaded"` as appropriate. This closes the gap where the maintenance endpoint previously only acted on scans, not the downstream contract status.

### Fix 4: Stale Scan Recovery CronJob

- `src/infrastructure/tasks/stale_scan_recovery.py` (new): Standalone maintenance script that calls the stale scan recovery endpoint and exits. Designed to run as a Kubernetes Job/CronJob.
- `k8s/base/api-service/cronjob-stale-scan-recovery.yaml` (new): CronJob running every 15 minutes with `concurrencyPolicy: Forbid` to prevent overlapping recovery runs.
- `k8s/base/api-service/kustomization.yaml`: Added CronJob to resources list.

### Fix 5: Upload Security Hardening (`src/presentation/api/v1/endpoints/upload.py`)

- Added binary signature detection for non-archive uploads. Rejected magic bytes: ELF (`\x7fELF`), PE (`MZ`), Mach-O (`\xfe\xed\xfa`/`\xce\xfa\xed\xfe`/`\xcf\xfa\xed\xfe`), WASM (`\x00asm`), OLE compound documents (`\xd0\xcf\x11\xe0`), and PDF (`%PDF`). Returns HTTP 400.
- Added null byte injection prevention. Returns HTTP 400.

### Database Cleanup (Manual — February 28, 2026)

Pre-fix backup taken at `docs/databases/backups/solidity_security_20260228_224442.dump` (9.4MB).

| Action | Count |
|--------|-------|
| Contracts fixed: `scanning` → `scanned` | 9 |
| Contracts fixed: `scanning` → `uploaded` (GNosis, no source) | 1 |
| Orphaned failed scans fixed (set `completed_at`, added error message) | 45 |

## Files Modified

| File | Change |
|------|--------|
| `src/presentation/api/v1/endpoints/scans.py` | Source code validation in create/batch scan; Phase 2 stale recovery |
| `src/presentation/schemas/contracts.py` | model_validator enforcing address or source_code required |
| `src/presentation/api/v1/endpoints/contracts.py` | source_code size limit (10MB) and null byte check |
| `src/presentation/api/v1/endpoints/upload.py` | Binary signature detection and null byte prevention |
| `src/infrastructure/tasks/stale_scan_recovery.py` | New standalone maintenance script |
| `k8s/base/api-service/cronjob-stale-scan-recovery.yaml` | New CronJob, every 15 min, concurrencyPolicy Forbid |
| `k8s/base/api-service/kustomization.yaml` | Added CronJob to resources |
| `pyproject.toml` | Version bump 0.29.42 → 0.29.43 |
| `k8s/overlays/local/api-service/kustomization.yaml` | newTag 0.29.42 → 0.29.43 |
| `docs/standards/docker-image-versioning.md` | Version table updated |

## Regression Testing

| Test | Result |
|------|--------|
| Full scan (scan 51276b83): slither 24 findings, aderyn 31 findings, soliditydefend 1 finding | PASS |
| Fix 1: POST scan on contract with no source code → HTTP 400 | PASS |
| Fix 2: POST contract with no address and no source code → HTTP 422 | PASS |
| Fix 2: POST contract source_code with null bytes → HTTP 400 | PASS |
| CronJob `stale-scan-recovery` active and running every 15 min | PASS |

## Verification

- [ ] `kubectl get cronjob stale-scan-recovery -n api-service-local` shows `ACTIVE` and correct schedule
- [ ] `kubectl get deployment api-service -n api-service-local -o jsonpath='{.spec.template.spec.containers[0].image}'` shows `0.29.43`
- [ ] `POST /api/v1/scans` on a no-source contract returns HTTP 400
- [ ] `POST /api/v1/contracts` with no address and no source returns HTTP 422
- [ ] Upload of ELF/PE binary returns HTTP 400
- [ ] No contracts in `scanning` status with zero active scans

## Related

- [Playbook: scan-stale-recovery.md](../playbooks/scan-stale-recovery.md) — Updated with Phase 2 recovery and CronJob details
- [Database: MANUAL-FIXES-2026-02-17-STALE-SCANS.md](../database/MANUAL-FIXES-2026-02-17-STALE-SCANS.md) — Original stale contract analysis
- [Database: BACKUPS.md](../database/BACKUPS.md) — Backup taken before manual data fix
- [Feature Test 84](../feature-tests/84-stuck-contract-upload-hardening-2026-02-28.md)
