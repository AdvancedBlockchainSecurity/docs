# 48. ML Data Strategy & Legal Compliance Test Checklist

GDPR/LGPD compliance features for ML data collection with consent tracking, data provenance, and privacy controls.

**Implementation Date**: 2026-01-30
**API Service Version**: 0.16.0
**Dashboard Version**: 0.34.0

---

## Prerequisites

- [ ] API service v0.16.0 deployed with migrations 053-055 applied
- [ ] Dashboard v0.34.0 deployed
- [ ] Test user account available
- [ ] Enterprise tier organization (for AI opt-out testing)

---

## 1. Registration Consent Flow

### 1.1 New User Registration

**Path**: `/register`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1.1.1 | Navigate to registration page | Registration form displays with ToS and Privacy Policy checkboxes | [ ] |
| 1.1.2 | ToS checkbox links to actual document | Links to `/docs/resources/legal/terms-of-service` | [ ] |
| 1.1.3 | Privacy Policy checkbox links to actual document | Links to `/docs/resources/legal/privacy-policy` | [ ] |
| 1.1.4 | Submit registration with checkboxes checked | Registration succeeds, consent API called | [ ] |
| 1.1.5 | Verify consent record created | Database has `tos_consent_records` entry | [ ] |

### 1.2 Verify Consent Record

**Database Check**:
```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security \
  -c "SELECT user_id, tos_version, privacy_policy_version, ml_data_collection_consent, consented_at FROM tos_consent_records ORDER BY created_at DESC LIMIT 1;"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1.2.1 | Consent record has correct user_id | Matches registered user's ID | [ ] |
| 1.2.2 | ToS version recorded | Version string (e.g., "1.0.0") | [ ] |
| 1.2.3 | Privacy Policy version recorded | Version string (e.g., "1.0.0") | [ ] |
| 1.2.4 | ML consent default true | `ml_data_collection_consent = true` | [ ] |
| 1.2.5 | Timestamp recorded | `consented_at` has valid timestamp | [ ] |

---

## 2. Consent API Endpoints

### 2.1 Record ToS Consent

**Endpoint**: `POST /api/v1/consent/tos`

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/consent/tos" \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "tos_version": "1.0.0",
    "privacy_policy_version": "1.0.0",
    "ml_data_collection_consent": true
  }'
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.1.1 | Record new consent | 201 Created with consent record | [ ] |
| 2.1.2 | Consent captures IP address | `consent_ip_address` populated | [ ] |
| 2.1.3 | Consent captures user agent | `consent_user_agent` populated | [ ] |

### 2.2 Get Current Consent

**Endpoint**: `GET /api/v1/consent/current`

```bash
curl -X GET "http://127.0.0.1:3000/api/v1/consent/current" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.2.1 | Get current consent status | Returns latest consent record | [ ] |
| 2.2.2 | Response includes versions | `tos_version`, `privacy_policy_version` | [ ] |
| 2.2.3 | Response includes ML consent | `ml_data_collection_consent` boolean | [ ] |
| 2.2.4 | No consent returns null | Returns null/empty if no consent exists | [ ] |

### 2.3 Withdraw ML Consent

**Endpoint**: `POST /api/v1/consent/withdraw-ml`

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/consent/withdraw-ml" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.3.1 | Withdraw ML consent | 200 OK, consent updated | [ ] |
| 2.3.2 | ML consent set to false | `ml_data_collection_consent = false` | [ ] |
| 2.3.3 | Withdrawn timestamp set | `withdrawn_at` has timestamp | [ ] |
| 2.3.4 | Future labels excluded | New labels marked `excluded_from_training = true` | [ ] |

### 2.4 Get Document Versions (Public)

**Endpoint**: `GET /api/v1/consent/versions`

```bash
curl -X GET "http://127.0.0.1:3000/api/v1/consent/versions"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.4.1 | Get current document versions | Returns ToS and PP versions | [ ] |
| 2.4.2 | No auth required | Works without Authorization header | [ ] |

---

## 3. Vulnerability Labeling with Provenance

### 3.1 Label Vulnerability (Creates Provenance)

**Endpoint**: `POST /api/v1/ml/label-vulnerability`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.1.1 | Label vulnerability as true positive | Label saved, provenance record created | [ ] |
| 3.1.2 | Label vulnerability as false positive | Label saved, provenance record created | [ ] |
| 3.1.3 | Provenance includes consent reference | `tos_consent_id` populated | [ ] |
| 3.1.4 | Provenance includes consent version | `consent_version` matches user's consent | [ ] |
| 3.1.5 | Features snapshot anonymized | `features_snapshot` has no PII | [ ] |

### 3.2 Verify Provenance Record

**Database Check**:
```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security \
  -c "SELECT vulnerability_id, label, consent_version, excluded_from_training, features_snapshot FROM ml_training_data_provenance ORDER BY created_at DESC LIMIT 1;"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.2.1 | Provenance has vulnerability_id | References labeled vulnerability | [ ] |
| 3.2.2 | Label recorded | `true_positive` or `false_positive` | [ ] |
| 3.2.3 | Consent version tracked | Version string from user's consent | [ ] |
| 3.2.4 | Not excluded by default | `excluded_from_training = false` | [ ] |
| 3.2.5 | Features snapshot present | JSONB with anonymized features | [ ] |

### 3.3 Labeling with Withdrawn Consent

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.3.1 | User with withdrawn ML consent labels | Label saved but excluded | [ ] |
| 3.3.2 | Provenance marked excluded | `excluded_from_training = true` | [ ] |
| 3.3.3 | Exclusion reason set | `exclusion_reason = 'user_consent_withdrawn'` | [ ] |

---

## 4. Organization AI Opt-Out (Enterprise Only)

### 4.1 Set AI Opt-Out (Admin API)

**Endpoint**: `PUT /api/v1/organizations/{org_id}/settings/ai-opt-out`

```bash
curl -X PUT "http://127.0.0.1:3000/api/v1/organizations/{ORG_ID}/settings/ai-opt-out" \
  -H "Authorization: Bearer {ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "ai_data_collection_disabled": true,
    "reason": "Enterprise contract requirement"
  }'
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.1.1 | Set AI opt-out on Enterprise org | 200 OK, opt-out saved | [ ] |
| 4.1.2 | Non-Enterprise tier rejected | 403 Forbidden | [ ] |
| 4.1.3 | Non-owner rejected | 403 Forbidden | [ ] |
| 4.1.4 | Opt-out timestamp set | `ai_opt_out_date` populated | [ ] |
| 4.1.5 | Reason recorded | `ai_opt_out_reason` saved | [ ] |

### 4.2 Get AI Status

**Endpoint**: `GET /api/v1/organizations/{org_id}/settings/ai-status`

```bash
curl -X GET "http://127.0.0.1:3000/api/v1/organizations/{ORG_ID}/settings/ai-status" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.2.1 | Get AI status for org | Returns opt-out status | [ ] |
| 4.2.2 | Response includes tier | `tier` field present | [ ] |
| 4.2.3 | Response includes opt-out flag | `ai_data_collection_disabled` boolean | [ ] |

### 4.3 Labeling in Opted-Out Organization

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.3.1 | Label vulnerability in opted-out org | Label saved but excluded | [ ] |
| 4.3.2 | Provenance marked excluded | `excluded_from_training = true` | [ ] |
| 4.3.3 | Exclusion reason set | `exclusion_reason = 'organization_opted_out'` | [ ] |

### 4.4 UI Notice for Opted-Out Org

**Path**: Vulnerability detail page with labeling panel

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.4.1 | Notice displayed | Yellow warning banner shows | [ ] |
| 4.4.2 | Notice text correct | "Your organization has opted out of AI data collection..." | [ ] |
| 4.4.3 | Labeling still works | Can label despite opt-out (just excluded) | [ ] |

---

## 5. GDPR Data Requests

### 5.1 Request Data Export

**Endpoint**: `POST /api/v1/gdpr/export-request`

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/gdpr/export-request" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 5.1.1 | Create export request | 202 Accepted with request ID | [ ] |
| 5.1.2 | Request record created | `gdpr_data_requests` entry with `request_type = 'export'` | [ ] |
| 5.1.3 | Status is pending | `status = 'pending'` | [ ] |
| 5.1.4 | Duplicate request rejected | 409 Conflict if pending request exists | [ ] |

### 5.2 Check Export Status

**Endpoint**: `GET /api/v1/gdpr/export/{request_id}`

```bash
curl -X GET "http://127.0.0.1:3000/api/v1/gdpr/export/{REQUEST_ID}" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 5.2.1 | Get pending request status | Returns status with request details | [ ] |
| 5.2.2 | Completed request has download link | `export_file_path` populated | [ ] |
| 5.2.3 | Download link has expiry | `export_expires_at` set | [ ] |

### 5.3 Request Data Deletion

**Endpoint**: `POST /api/v1/gdpr/deletion-request`

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/gdpr/deletion-request" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 5.3.1 | Create deletion request | 202 Accepted with request ID | [ ] |
| 5.3.2 | Request record created | `request_type = 'deletion'` | [ ] |
| 5.3.3 | Confirmation required | Response indicates admin review needed | [ ] |

### 5.4 View My Data Summary

**Endpoint**: `GET /api/v1/gdpr/my-data`

```bash
curl -X GET "http://127.0.0.1:3000/api/v1/gdpr/my-data" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 5.4.1 | Get data summary | Returns summary of stored data | [ ] |
| 5.4.2 | Includes data categories | Profile, activity, scans, etc. | [ ] |
| 5.4.3 | Includes record counts | Number of items in each category | [ ] |

---

## 6. Database Tables Verification

### 6.1 Table Existence

```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security \
  -c "\dt *consent*" \
  -c "\dt *provenance*" \
  -c "\dt *gdpr*"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 6.1.1 | tos_consent_records exists | Table found | [ ] |
| 6.1.2 | ml_training_data_provenance exists | Table found | [ ] |
| 6.1.3 | gdpr_data_requests exists | Table found | [ ] |

### 6.2 Alembic Version

```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security \
  -c "SELECT * FROM alembic_version;"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 6.2.1 | Migration version is 055 | `055_add_gdpr_requests` | [ ] |

---

## 7. Legal Document Updates

### 7.1 Terms of Service

**Path**: `/docs/resources/legal/terms-of-service`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 7.1.1 | Section 7.4 exists | "Machine Learning and Data Use" section | [ ] |
| 7.1.2 | Describes anonymized data use | Explains how vulnerability data is used | [ ] |
| 7.1.3 | Describes opt-out | Explains Enterprise opt-out option | [ ] |

### 7.2 Privacy Policy

**Path**: `/docs/resources/legal/privacy-policy`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 7.2.1 | Section 2.5 exists | "Machine Learning and Model Training" section | [ ] |
| 7.2.2 | Describes data collection | What data is collected for ML | [ ] |
| 7.2.3 | Describes anonymization | How PII is removed | [ ] |
| 7.2.4 | GDPR rights mentioned | Right to access, erasure explained | [ ] |

---

## Notes

```
Testing Notes:
- Consent is recorded during registration via frontend API call
- Provenance is created automatically when labeling vulnerabilities
- Organization AI opt-out is admin-only (not user-facing)
- GDPR requests are processed manually by admin within 30 days
- All ML training data is anonymized (no PII in features_snapshot)
```

---

## Test Results

| Date | Tester | Result | Notes |
|------|--------|--------|-------|
| 2026-01-30 | Claude Code | PENDING | ML Data Strategy implemented, awaiting testing |
