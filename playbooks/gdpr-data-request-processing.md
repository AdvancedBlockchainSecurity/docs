# Playbook: GDPR Data Request Processing

**Version**: 2.0.0
**Last Updated**: 2026-03-01
**Tested On**: api-service v0.29.52, admin-portal v0.7.9

---

## Overview

This playbook covers processing GDPR data requests (export, deletion, ML consent withdrawal) through the admin portal. Users cannot self-service withdraw ML consent — all data requests are processed by authorized admins with full audit logging.

## Prerequisites

- Admin account with appropriate role:
  - `support_admin` — view requests and details
  - `platform_admin` — process requests (approve/reject/complete)
- Access to `https://admin.0xapogee.com/data-requests` (local) or `https://admin.0xapogee.com/data-requests` (production)
- MFA verified session

---

## When to Use

Use this playbook when:
- A user submits a data export request
- A user submits a data deletion request
- A user requests ML consent withdrawal (via support ticket)
- Periodic review of pending GDPR requests

---

## Step 1: Review Pending Requests

Navigate to **Data Requests** in the admin portal sidebar.

1. Filter by **Status: Pending** to see unprocessed requests
2. Filter by **Type** to focus on a specific request category (Export, Deletion, ML Withdrawal)
3. Click **Details** on any request to view:
   - User email, tier, and display name
   - ML consent status (Active/Inactive)
   - Number of ML provenance records
   - Request metadata (IP, user agent, timestamps)

---

## Step 2: Process a Data Export Request

Export requests automatically generate a downloadable JSON file with the user's data.

1. Click **Process** on a pending export request
2. Select action **Generate Export**
3. Click **Confirm**

**What happens on approval:**
- JSON export file is generated containing:
  - Account information (email, display_name, tier, signup date)
  - Contracts (metadata, excluding source code and bytecode)
  - Scans (scan configurations and results)
  - Vulnerabilities (all findings for user's contracts)
  - ML provenance (training data lineage)
  - Consent records (ToS, privacy policy, ML consent history)
- File stored at `/tmp/gdpr-exports/{request_id}.json`
- Export expires in 7 days (can be regenerated if requested again)
- Request status changes to `completed`
- `export_file_path` and `export_expires_at` timestamp recorded

**Download the Export:**
1. In the Data Requests detail modal, look for "Export File" section
2. Click **Download Export** button (active only if file exists and not expired)
3. JSON file downloads to your computer
4. File contains no source code or sensitive contract details

**API equivalent:**
```bash
curl -X POST https://app.0xapogee.com/api/v1/admin/gdpr/requests/{request_id}/process \
  -H "Cookie: admin_session=..." \
  -H "Content-Type: application/json" \
  -d '{"action": "approve"}'

# Download export
curl -X GET https://app.0xapogee.com/api/v1/gdpr/export/{request_id}/download \
  -H "Cookie: admin_session=..." \
  -o export.json
```

---

## Step 3: Process a Data Deletion Request

Deletion requests permanently remove the user's data from the platform.

**WARNING: This action is irreversible. The user account will be anonymized and deactivated.**

1. Click **Process** on a pending deletion request
2. Select action **Approve Deletion (deletes user data)**
3. Add a reason (recommended for audit trail)
4. Click **Confirm**

**What happens on approval:**
- **Vulnerabilities:** Soft-deleted for all user's contracts
  - `deleted_at` = now, `deleted_by` = admin ID, `deletion_reason` = "gdpr_deletion"
  - Vulnerabilities still exist in DB but marked as deleted
- **Contracts:** Source code and bytecode cleared
  - `source_code = NULL`, `bytecode = NULL`, `archived_at = now()`
  - Contract metadata preserved for audit trail
- **ML Consent:** Withdrawn if active
  - `ml_data_collection_consent = false`, `withdrawn_at = now()`
- **User Data Deleted:**
  - All `sessions` deleted (user logged out everywhere)
  - All `user_preferences` deleted
  - All `favorites` deleted
  - All `activity_logs` deleted
- **User Record Anonymized:**
  - `email = "deleted-{uuid}@deleted.local"` (user cannot login)
  - `display_name = "Deleted User"`
  - `is_active = false` (account deactivated)
  - `wallet_address`, `ens_name`, `avatar_url` = NULL
- **ML Provenance:** Excluded from future training
  - All provenance records marked `excluded_from_training = true`
  - `exclusion_reason = "gdpr_deletion_request"`
- Request status changes to `completed`
- `deletion_confirmed_at` timestamp recorded

**Result:** User account is effectively deleted. Data cannot be recovered. Account cannot be reactivated.

**API equivalent:**
```bash
curl -X POST https://app.0xapogee.com/api/v1/admin/gdpr/requests/{request_id}/process \
  -H "Cookie: admin_session=..." \
  -H "Content-Type: application/json" \
  -d '{"action": "approve"}'
```

---

## Step 4: Process an ML Consent Withdrawal Request

ML withdrawal requests withdraw the user's ML data collection consent and exclude all their training data.

1. Click **Process** on a pending ml-withdrawal request
2. Select action **Approve ML Withdrawal**
3. Add a reason (recommended for audit trail)
4. Click **Confirm**

**What happens on approval:**
- User's latest consent record: `ml_data_collection_consent` set to `false`, `withdrawn_at` timestamp set
- All ML provenance records: `excluded_from_training = true`, exclusion reason `gdpr_ml_withdrawal_request`
- Request status changes to `completed`

**API equivalent:**
```bash
curl -X POST https://app.0xapogee.com/api/v1/admin/gdpr/requests/{request_id}/process \
  -H "Cookie: admin_session=..." \
  -H "Content-Type: application/json" \
  -d '{"action": "approve"}'
```

---

## Step 5: Admin-Initiated ML Consent Withdrawal (Without Request)

For cases where an admin needs to withdraw ML consent directly (e.g., legal request, compliance action):

1. In the **Withdraw ML Consent** section at the top of the Data Requests page
2. Enter the user's UUID
3. Click **Withdraw ML Consent**

**API equivalent:**
```bash
curl -X POST https://app.0xapogee.com/api/v1/admin/gdpr/users/{user_id}/withdraw-ml \
  -H "Cookie: admin_session=..."
```

**What happens:**
- Same as Step 4 approval, but without an associated GDPR request
- Action is audit-logged with `gdpr_withdraw_ml_consent` action type

---

## Step 6: Reject a Request

To reject any GDPR request:

1. Click **Process** on a pending request
2. Select action **Reject**
3. Enter a **reason** (required for rejections)
4. Click **Reject**

**What happens:**
- Request status changes to `failed`
- Error message is set to the rejection reason
- No data changes are made

---

## Verification

After processing a request:

- [ ] Request status updated in the Data Requests table (refresh the page)
- [ ] Click **Details** to verify `processed_at` and `processed_by` fields
- [ ] **For export:** Verify "Export File" section shows file status and expiration
  - File exists and is not expired: **Download Export** button should be active
  - Click button and verify JSON file downloads and opens correctly
- [ ] **For deletion:** Verify user record is anonymized
  - Query database: `SELECT email, display_name, is_active FROM users WHERE id = '{user_id}'`
  - Should see: `email = "deleted-{uuid}@deleted.local"`, `display_name = "Deleted User"`, `is_active = false`
- [ ] **For deletion:** Verify contract data cleared
  - Query database: `SELECT source_code, bytecode FROM contracts WHERE user_id = '{user_id}'`
  - Should see: Both fields are NULL
- [ ] **For deletion/ml-withdrawal:** verify ML consent and provenance status in request details
- [ ] Check API service logs for audit entries:
  ```bash
  kubectl logs -n api-service-local deployment/api-service --since=5m | grep gdpr
  ```

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "Request is already completed" | Request already processed | Check request details — already done |
| "Reason is required" | Rejecting without a reason | Add a reason in the text field |
| Export file shows "expired" | File older than 7 days | Regenerate export by processing request again |
| "Download Export" button disabled | File not generated or expired | Click "Generate Export" again to recreate file |
| 401 Unauthorized | Session expired | Re-login and verify MFA |
| 404 Not Found | Standard user attempting access | Only superusers can access admin endpoints |
| Modal appears transparent | CSS rendering issue | Hard refresh the page (Ctrl+Shift+R) |
| Export file won't download | Browser blocked download | Check browser download settings or firewall |

---

## Related

- [Admin Session Management](./admin-session-management.md)
- [Admin Account Setup](./admin-account-setup.md)
- [GDPR Data Request Workflow](../workflows/gdpr-data-request-workflow.md)
- [GDPR Request Processing Pipeline](../pipelines/gdpr-request-processing-pipeline.md)
