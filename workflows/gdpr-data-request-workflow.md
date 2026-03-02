# GDPR Data Request Workflow

**Version:** 2.0.0
**Last Updated:** March 1, 2026
**Status:** Active

## Overview

Documents the end-to-end flow for GDPR data requests from user submission through admin processing. ML consent is collected at signup; withdrawal and data deletion are handled through a formal admin-managed workflow, not self-service.

## Architecture

```
User                    Dashboard              API Service           Admin Portal
────                    ─────────              ───────────           ────────────
Signup consent    →     ConsentModal      →    POST /consent         (stored in DB)
                        (ToS + Privacy +
                         ML opt-in)

Data request      →     Support ticket    →    Creates GDPR          Admin reviews
                        or contact form        request (pending)     at /data-requests

                                                                     Process request:
                                                                     - Approve (deletion/ml-withdrawal)
                                                                     - Complete (export)
                                                                     - Reject (with reason)

                                               ← Audit logged  ←    POST /admin/gdpr/
                                                                     requests/{id}/process
```

## Services Involved

| Service | Role |
|---------|------|
| Dashboard | Displays consent status (read-only) on Settings page |
| API Service | GDPR admin endpoints, consent storage, audit logging |
| Admin Portal | Data Requests page for admin processing |
| PostgreSQL | `gdpr_data_requests`, `tos_consent_records`, `ml_training_data_provenance` tables |

## Consent Collection Phase

### At Signup

1. User creates account via Supabase auth
2. Dashboard presents `ConsentModal` with:
   - Terms of Service acceptance
   - Privacy Policy acceptance
   - ML data collection consent (opt-in)
3. User accepts → `POST /api/v1/consent` creates `tos_consent_records` entry
4. ML consent status is stored as `ml_data_collection_consent: boolean`

### On Settings Page

- Consent status displayed as read-only (version numbers, acceptance date)
- Links to current ToS and Privacy Policy documents
- No self-service withdrawal button — directed to support for changes

## Request Types

| Type | Description | Admin Action | Data Impact |
|------|-------------|--------------|-------------|
| `export` | User requests copy of their data | `approve` (generates JSON file) | No data changes; creates downloadable export with 7-day expiration |
| `deletion` | User requests data removal | `approve` | Soft-deletes vulnerabilities, clears contract source code/bytecode, anonymizes user, deletes sessions/preferences/activity logs, excludes ML provenance |
| `ml-withdrawal` | User withdraws ML consent | `approve` | Consent withdrawn + provenance excluded |

## Processing Flow

### Export Request

```
1. User submits export request
2. GDPR request created (status: pending)
3. Admin reviews request at /data-requests
4. Admin clicks "Generate Export" (approve action)
5. API generates JSON export file containing:
   - Account info (email, display_name, tier, created_at)
   - Contracts (metadata only, no source code)
   - Scans (scan configurations, metadata)
   - Vulnerabilities (all findings, no deleted ones)
   - ML provenance (training data lineage)
   - Consent records (ToS, privacy, ML consent history)
6. Export file stored at /tmp/gdpr-exports/{request_id}.json
7. export_file_path and export_expires_at (7 days) set in database
8. Request status = completed
9. User can download via GET /gdpr/export/{id}/download endpoint
10. File expires in 7 days (can be extended if requested again)
11. Audit log: gdpr_request_approve
```

### Deletion Request

```
1. User submits deletion request
2. GDPR request created (status: pending)
3. Admin reviews request at /data-requests
4. Admin clicks "Approve Deletion (deletes user data)"
5. API updates:
   a. vulnerabilities: soft-deleted for user's contracts
      (deleted_at, deleted_by, deletion_reason = "gdpr_deletion")
   b. contracts: source_code and bytecode set to NULL, archived_at = now()
   c. tos_consent_records: ml_data_collection_consent = false,
      withdrawn_at = now() (if active)
   d. sessions: all deleted
   e. user_preferences: all deleted
   f. favorites: all deleted
   g. activity_logs: all deleted
   h. users: anonymized
      - email = "deleted-{uuid}@deleted.local"
      - display_name = "Deleted User"
      - is_active = false
      - wallet_address, ens_name, avatar_url = NULL
   i. ml_training_data_provenance: excluded_from_training = true
      (exclusion_reason = "gdpr_deletion_request")
   j. gdpr_data_requests: status = "completed",
      deletion_confirmed_at = now()
6. User account effectively deleted (anonymized, deactivated)
7. All user data deleted except ML provenance (excluded from future training)
8. Audit log: gdpr_request_approve
```

### ML Consent Withdrawal

```
1. User submits ml-withdrawal request (via support)
2. GDPR request created (status: pending)
3. Admin reviews request at /data-requests
4. Admin clicks "Approve ML Withdrawal"
5. API updates:
   a. tos_consent_records: ml_data_collection_consent = false,
      withdrawn_at = now()
   b. ml_training_data_provenance: excluded_from_training = true
      (exclusion_reason = "gdpr_ml_withdrawal_request")
   c. gdpr_data_requests: status = "completed"
6. Audit log: gdpr_request_approve
```

### Admin-Initiated Withdrawal (No Request)

```
1. Admin navigates to /data-requests
2. Enters user UUID in "Withdraw ML Consent" section
3. POST /admin/gdpr/users/{user_id}/withdraw-ml
4. API updates:
   a. tos_consent_records: ml_data_collection_consent = false,
      withdrawn_at = now()
   b. ml_training_data_provenance: excluded_from_training = true
      (exclusion_reason = "admin_withdrawn")
5. Audit log: gdpr_withdraw_ml_consent
```

## API Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/admin/gdpr/requests` | `support_admin` | List requests (paginated, filterable) |
| GET | `/admin/gdpr/requests/{id}` | `support_admin` | Request detail with user context |
| POST | `/admin/gdpr/requests/{id}/process` | `platform_admin` | Process request (approve/complete/reject) |
| POST | `/admin/gdpr/users/{id}/withdraw-ml` | `platform_admin` | Admin-initiated ML withdrawal |

**Security:**
- All endpoints require admin role authentication
- Rate limited at 10 requests/minute
- No PII (emails) in application logs — uses admin/user IDs only
- No internal filesystem paths in API responses (`has_export_file: bool`)
- Audit logging occurs before database commit

## Database Tables

| Table | Role |
|-------|------|
| `tos_consent_records` | Stores user consent (ToS version, privacy version, ML consent, withdrawn_at) |
| `ml_training_data_provenance` | Tracks ML training data lineage (excluded_from_training, exclusion_reason) |
| `gdpr_data_requests` | GDPR request tracking (type, status, processed_by, timestamps) |

## Request Status Transitions

```
pending → completed    (approve or complete action)
pending → failed       (reject action)
processing → completed (approve or complete action)
processing → failed    (reject action)
```

## Related Documentation

- [GDPR Data Request Processing Playbook](../playbooks/gdpr-data-request-processing.md)
- [GDPR Request Processing Pipeline](../pipelines/gdpr-request-processing-pipeline.md)
- [Admin Session Management](../playbooks/admin-session-management.md)
- [API Endpoint Authentication Standards](../standards/api-endpoint-auth.md)
- [Secure Coding Standards](../standards/secure-coding.md)
