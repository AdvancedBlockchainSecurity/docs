# Feature Test: GDPR Admin Data Request Processing

**Date:** 2026-03-02
**Version:** API Service v0.29.52 (initial), v0.29.54 (security hardening), v0.29.55 (scan error_message fix)
**Admin Portal:** v0.7.10

## Test Objective

Verify the GDPR admin data request processing workflow: deletion (user anonymization, ML exclusion), data export (file generation, permissions, expiry), and ML-withdrawal (consent withdrawal, provenance exclusion). All operations are admin-initiated via the admin portal.

---

## TC-89-001: GDPR Deletion — User Anonymization

**Priority:** Critical
**Endpoint:** `POST /api/v1/admin/gdpr/requests/{id}/process`
**Auth:** Admin JWT + MFA session + IP binding

### Steps

1. Create a GDPR deletion request for a test user via seed script
2. Open admin portal → GDPR Requests
3. Find the deletion request (status: pending)
4. Click Process → select **Approve Deletion** → Submit
5. Verify database state after processing

### Expected

- [x] Request status changes to `completed`
- [x] User email changed to `deleted-{uuid}@deleted.local`
- [x] User `display_name` set to `Deleted User`
- [x] User `hashed_password` set to `DELETED` (NOT NULL safe)
- [x] User `is_active` set to `false`
- [x] ML provenance records: `excluded_from_training = true`, reason = `gdpr_user_deletion`
- [x] `deletion_confirmed_at` timestamp set on user record
- [x] Audit log created with enriched `new_values` (operation counts)

### Notes

- Initial implementation set `hashed_password = None` which violated NOT NULL constraint — fixed in v0.29.54
- Tested with user `test-gdpr@blocksecops.local` (request `bd058987`)

---

## TC-89-002: GDPR Export — File Generation

**Priority:** Critical
**Endpoint:** `POST /api/v1/admin/gdpr/requests/{id}/process`
**Auth:** Admin JWT + MFA session + IP binding

### Steps

1. Create a GDPR export request for test-enterprise user via seed script
2. Open admin portal → GDPR Requests
3. Find the export request (status: pending)
4. Click Process → select **Approve** → Submit
5. Verify export file and database state

### Expected

- [x] Request status changes to `completed`
- [x] Export file generated at `/tmp/gdpr-exports/{id}.json`
- [x] Export file permissions are `0600` (owner read/write only)
- [x] `export_expires_at` set to 7 days from processing
- [x] Export data includes: account info, contracts, scans, vulnerabilities, ML provenance, consent records
- [x] Path traversal protection: `os.path.realpath()` validates path is within `GDPR_EXPORT_DIR`
- [x] Audit log includes record counts in `new_values`

### Notes

- Tested with user `test-enterprise@blocksecops.local` (request `77777777-...-01`)
- Second export attempt used "Complete" instead of "Approve" — no file generated (correct behavior, "Complete" is for manual completion without data operations)

---

## TC-89-003: GDPR ML-Withdrawal — Consent and Provenance

**Priority:** High
**Endpoint:** `POST /api/v1/admin/gdpr/requests/{id}/process`
**Auth:** Admin JWT + MFA session + IP binding

### Steps

1. Verify test-enterprise user has ML provenance records with `excluded_from_training = false`
2. Verify user has active ToS consent with `ml_data_collection_consent = true`
3. Open admin portal → GDPR Requests
4. Find the ml-withdrawal request (status: pending)
5. Click Process → select **Approve** → Submit
6. Verify ML provenance and consent records after processing

### Expected

- [x] Request status changes to `completed`
- [x] All 10 ML provenance records: `excluded_from_training = true`
- [x] All 10 records: `exclusion_reason = 'gdpr_ml_withdrawal_request'`
- [x] ToS consent: `ml_data_collection_consent = false`
- [x] ToS consent: `withdrawn_at` timestamp set (matches `processed_at`)
- [x] User account remains active (ML-withdrawal does not disable user)

### Notes

- Tested with user `test-enterprise@blocksecops.local` (request `77777777-...-02`)
- 10 ML training data provenance records existed prior to test, all flipped correctly

---

## TC-89-004: GDPR Request Listing and Filtering

**Priority:** Medium
**Endpoint:** `GET /api/v1/admin/gdpr/requests`
**Auth:** Admin JWT + MFA session + IP binding

### Steps

1. Open admin portal → GDPR Requests
2. Verify all request types visible (deletion, export, ml-withdrawal)
3. Verify request details include user email, request type, status, timestamps

### Expected

- [x] Paginated list of GDPR requests
- [x] Filter by type (export, deletion, ml-withdrawal)
- [x] Filter by status (pending, completed)
- [x] Request detail shows ML provenance info for ml-withdrawal requests
- [x] Request detail shows export file info for export requests

---

## TC-89-005: Security — Path Traversal Protection

**Priority:** Critical
**Endpoint:** `GET /api/v1/gdpr/export/{id}/download`
**Auth:** User JWT

### Steps

1. Verify `os.path.realpath()` is used in the download endpoint
2. Verify path is validated against `GDPR_EXPORT_DIR` prefix
3. Verify structural test exists in `tests/unit/presentation/test_admin_gdpr.py`

### Expected

- [x] `realpath` used to resolve symlinks and `..` traversal
- [x] Path must start with `GDPR_EXPORT_DIR + os.sep`
- [x] Structural regression test validates this pattern exists

---

## TC-89-006: Security — Export File Permissions

**Priority:** High

### Steps

1. Verify export files are created with `os.open()` using `O_WRONLY | O_CREAT | O_TRUNC`
2. Verify mode is `0o600`
3. Verify structural test exists

### Expected

- [x] Files created with `0o600` permissions (owner read/write only)
- [x] Structural regression test validates `0o600` or `0o` pattern exists

---

## TC-89-007: Scan Error Message Persistence (v0.29.55)

**Priority:** Medium
**Related:** Smoke test failure — 43 failed scans had NULL `error_message`

### Steps

1. Verify all 5 scan failure paths in `scans.py` now set `scan.error_message` before `db.commit()`
2. Verify backfill script updated 43 historical records
3. Verify smoke test passes with 0 NULL error_messages

### Expected

- [x] Path 1 (no scanners provided): `scan.error_message = "No scanners provided"`
- [x] Path 2 (project scanners on single file): error message set before commit
- [x] Path 3 (consecutive trigger failures): error message set before commit
- [x] Path 4 (no scanners triggered): error message set before commit
- [x] Path 5 (callback reports failure): `scan.error_message = results.error or fallback`
- [x] Backfill: 43 records updated, 0 remaining NULL
- [x] Smoke test: "Failed scans have error_message" → PASS

---

## Summary

| Test Case | Result | Notes |
|-----------|--------|-------|
| TC-89-001: Deletion | PASS | User anonymized, ML excluded, audit enriched |
| TC-89-002: Export | PASS | File generated, 0600 perms, 7-day expiry |
| TC-89-003: ML-Withdrawal | PASS | 10/10 records excluded, consent withdrawn |
| TC-89-004: Request Listing | PASS | Filtering and details working |
| TC-89-005: Path Traversal | PASS | Structural test validates protection |
| TC-89-006: File Permissions | PASS | Structural test validates 0600 |
| TC-89-007: Scan Error Message | PASS | 5 paths fixed, 43 backfilled, smoke test green |

**Overall: 7/7 PASS**
