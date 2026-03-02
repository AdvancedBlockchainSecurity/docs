# GDPR Request Processing Pipeline

Processes GDPR data requests through admin review, executing data operations (ML consent withdrawal, provenance exclusion) with full audit logging.

## Overview

```
Admin Portal              API Service                  Database
────────────              ───────────                  ────────
GET /requests       →     Query gdpr_data_requests     ← paginated results
                          JOIN users

GET /requests/{id}  →     Query request + user         ← detail + ML context
                          + consent + provenance count + export file status

POST /requests/{id} →     Validate request state
  /process                Route by action + type:
                          ├─ approve + deletion    →    Soft-delete vulnerabilities
                          │                             Clear contract source_code/bytecode
                          │                             Withdraw ML consent (if active)
                          │                             Delete sessions/preferences/favorites
                          │                             Anonymize user record
                          │                             UPDATE ml_training_data_provenance
                          │                             SET excluded_from_training = true
                          │
                          ├─ approve + export     →     Generate JSON export file
                          │                             Set export_file_path + expiration
                          │
                          ├─ approve + ml-withdrawal →  UPDATE tos_consent_records
                          │                             SET ml_consent = false, withdrawn_at
                          │                         →   UPDATE ml_training_data_provenance
                          │                             SET excluded_from_training = true
                          │
                          ├─ complete              →    (deprecated - use approve for export)
                          │                             UPDATE gdpr_data_requests
                          │                             SET status = completed
                          │
                          └─ reject                →    UPDATE gdpr_data_requests
                                                        SET status = failed, error_message

                          log_admin_action()        →   INSERT admin_actions
                          db.commit()               →   COMMIT

GET /export/{id}/  →      Validate request state
  download                Get export_file_path    →    Verify file exists
                          Return FileResponse      ←    File contents (expires in 7 days)

POST /users/{id}    →     Validate user + consent
  /withdraw-ml            UPDATE consent record     →   withdrawn_at = now()
                          UPDATE provenance          →   excluded_from_training = true
                          log_admin_action()         →   INSERT admin_actions
                          db.commit()                →   COMMIT
```

## Trigger

- **Admin Portal**: Admin navigates to `/data-requests` and clicks Process
- **API**: Direct `POST /api/v1/admin/gdpr/requests/{id}/process` call

## Pipeline Phases

### Phase 1: Request Retrieval

| Step | Description |
|------|-------------|
| Authenticate | Verify admin session + MFA via `require_admin_role()` |
| Load request | Fetch `gdpr_data_requests` by ID |
| Validate state | Request must be `pending` or `processing` (reject if already completed/failed) |
| Load context | For detail view: join user info, check ML consent status, count provenance records |

### Phase 2: Action Routing

| Action | Request Type | Operations |
|--------|-------------|------------|
| `approve` | `deletion` | Soft-delete vulnerabilities, clear contract source code/bytecode, withdraw ML consent (if active), delete sessions/preferences/favorites/activity logs, anonymize user record, exclude provenance records, set `deletion_confirmed_at` |
| `approve` | `export` | Generate JSON export file, set export file path and 7-day expiration, mark as completed |
| `approve` | `ml-withdrawal` | Withdraw ML consent on consent record, exclude provenance records |
| `complete` | any | (deprecated for export - use `approve` action instead) Mark request as completed |
| `reject` | any | Mark request as failed with reason (no data operations) |

### Phase 3: Data Operations (approve actions only)

#### Deletion Operations

| Step | Description |
|------|-------------|
| Soft-delete vulnerabilities | `UPDATE vulnerabilities SET deleted_at = now(), deleted_by = admin_id, deletion_reason = 'gdpr_deletion' WHERE contract_id IN (user's contracts)` |
| Clear contract data | `UPDATE contracts SET source_code = NULL, bytecode = NULL, archived_at = now() WHERE user_id = ?` |
| Withdraw ML consent | `UPDATE tos_consent_records SET ml_data_collection_consent = false, withdrawn_at = now() WHERE user_id = ? AND ml_data_collection_consent = true` |
| Delete related data | `DELETE FROM sessions`, `favorites`, `user_preferences`, `activity_logs` WHERE user_id = ? |
| Anonymize user | `UPDATE users SET email = 'deleted-{uuid}@deleted.local', display_name = 'Deleted User', is_active = false, wallet_address = NULL, ens_name = NULL, avatar_url = NULL WHERE user_id = ?` |
| Exclude provenance | `UPDATE ml_training_data_provenance SET excluded_from_training = true WHERE user_id = ? AND excluded_from_training = false` |
| Set exclusion reason | `gdpr_deletion_request` |

#### Export Operations

| Step | Description |
|------|-------------|
| Generate export file | Create JSON file at `/tmp/gdpr-exports/{request_id}.json` containing account info, contracts (excluding source code), scans, vulnerabilities, ML provenance, consent records |
| Set file metadata | `UPDATE gdpr_data_requests SET export_file_path = '/tmp/gdpr-exports/{request_id}.json', export_expires_at = now() + interval '7 days'` |
| Mark completed | `UPDATE gdpr_data_requests SET status = 'completed'` |

#### ML Withdrawal Operations

| Step | Description |
|------|-------------|
| Withdraw consent | Set `ml_data_collection_consent = false` and `withdrawn_at` on latest consent record |
| Exclude provenance | `UPDATE ml_training_data_provenance SET excluded_from_training = true WHERE user_id = ? AND excluded_from_training = false` |
| Set exclusion reason | `gdpr_ml_withdrawal_request` |

### Phase 4: Audit and Commit

| Step | Description |
|------|-------------|
| Audit log | `log_admin_action()` records action BEFORE commit (ensures audit even if commit fails) |
| Commit | `db.commit()` persists all changes atomically |
| Log | Application log with admin ID, request ID, action, and status transition |
| Response | Return `ProcessRequestResponse` with request ID, new status, message, timestamp |

## Security Controls

| Control | Implementation |
|---------|---------------|
| Authentication | `require_admin_role("platform_admin")` for state-changing endpoints |
| Authorization | `support_admin` for read-only, `platform_admin` for processing |
| Rate limiting | `@limiter.limit("10/minute")` on all endpoints |
| Input validation | Pydantic `pattern` constraint on action field, `max_length` on reason |
| PII protection | No emails in log statements — uses admin/user UUIDs only |
| Path protection | `has_export_file: bool` instead of exposing `export_file_path` |
| Audit ordering | `log_admin_action()` called before `db.commit()` |

## Files

| File | Role |
|------|------|
| `blocksecops-api-service/src/presentation/api/v1/endpoints/admin/gdpr.py` | Admin GDPR endpoints (6 routes: process request, withdraw ML, download export) |
| `blocksecops-api-service/src/services/gdpr_service.py` | GDPR business logic (deletion, export, withdrawal operations) |
| `blocksecops-admin-portal/src/pages/AdminDataRequests.tsx` | Admin UI for data request management (export download, deletion confirmation) |
| `blocksecops-admin-portal/src/lib/api/admin.ts` | TypeScript API client (GDPR types and functions) |
| `blocksecops-api-service/tests/unit/presentation/test_admin_gdpr.py` | Compliance tests for all operations |

## Error Handling

| Error | HTTP Code | Cause |
|-------|-----------|-------|
| "GDPR request not found" | 404 | Invalid request ID |
| "Request is already completed" | 400 | Request already processed |
| "Reason is required when rejecting" | 400 | Reject action without reason |
| "No active consent record found" | 404 | User has no active consent (withdraw-ml endpoint) |
| "ML data collection consent was not previously granted" | 400 | User didn't opt in to ML (withdraw-ml endpoint) |
| Rate limit exceeded | 429 | More than 10 requests/minute |

## Related Pipelines

- [Scan Execution Pipeline](./scan-execution-pipeline.md) — generates ML training data that GDPR requests may exclude
- [Intelligence Pipeline](./intelligence-pipeline.md) — uses ML provenance data that respects `excluded_from_training` flag

## Related Documentation

- [GDPR Data Request Workflow](../workflows/gdpr-data-request-workflow.md)
- [GDPR Data Request Processing Playbook](../playbooks/gdpr-data-request-processing.md)
- [API Endpoint Authentication Standards](../standards/api-endpoint-auth.md)
