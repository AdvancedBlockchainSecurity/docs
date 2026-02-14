# Admin Endpoints

> **Authentication:** All admin endpoints require an active admin session with MFA verification.

---

## Admin System

System-level health, configuration, and operational endpoints.

### GET /admin/system/health

Returns overall system health status.

```bash
curl -X GET https://api.blocksecops.com/admin/system/health \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "status": "healthy",
  "uptime_seconds": 864000,
  "version": "2.4.1",
  "components": {
    "database": "healthy",
    "cache": "healthy",
    "queue": "healthy",
    "storage": "healthy"
  }
}
```

### GET /admin/system/stats

Returns system-wide statistics.

```bash
curl -X GET https://api.blocksecops.com/admin/system/stats \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "total_users": 12450,
  "total_organizations": 3200,
  "total_scans": 98500,
  "active_scans": 42,
  "scans_today": 310,
  "average_scan_duration_seconds": 145
}
```

### GET /admin/system/config

Returns current system configuration.

```bash
curl -X GET https://api.blocksecops.com/admin/system/config \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "max_concurrent_scans": 100,
  "scan_timeout_seconds": 3600,
  "ml_model_version": "3.2.0",
  "feature_flags": {
    "solana_scanning": true,
    "ai_analysis": true,
    "monitoring_v2": false
  }
}
```

### GET /admin/system/cluster-metrics

Returns cluster-level resource metrics.

```bash
curl -X GET https://api.blocksecops.com/admin/system/cluster-metrics \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "nodes": 8,
  "cpu_utilization_percent": 62.4,
  "memory_utilization_percent": 71.2,
  "disk_utilization_percent": 45.8,
  "network_throughput_mbps": 320.5
}
```

### GET /admin/system/scanners/health

Returns health status of all scanner instances.

```bash
curl -X GET https://api.blocksecops.com/admin/system/scanners/health \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "scanners": [
    {
      "name": "mythril",
      "version": "0.24.7",
      "status": "healthy",
      "active_jobs": 5
    },
    {
      "name": "slither",
      "version": "0.10.0",
      "status": "healthy",
      "active_jobs": 12
    }
  ]
}
```

### POST /admin/system/ml/retrain

Triggers a retraining cycle for the ML vulnerability detection model.

```bash
curl -X POST https://api.blocksecops.com/admin/system/ml/retrain \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "vulnerability_classifier",
    "dataset_version": "latest"
  }'
```

**Response 202:**

```json
{
  "job_id": "ml-retrain-abc123",
  "status": "queued",
  "estimated_duration_minutes": 45
}
```

### POST /admin/system/scanners/{name}/upgrade

Triggers an upgrade for a specific scanner engine.

```bash
curl -X POST https://api.blocksecops.com/admin/system/scanners/mythril/upgrade \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "target_version": "0.24.8"
  }'
```

**Response 202:**

```json
{
  "job_id": "upgrade-mythril-def456",
  "scanner": "mythril",
  "from_version": "0.24.7",
  "to_version": "0.24.8",
  "status": "in_progress"
}
```

---

## Admin Users

User management endpoints for administrators.

### GET /admin/users

List all users with filtering and pagination.

```bash
curl -X GET "https://api.blocksecops.com/admin/users?page=1&limit=25&status=active" \
  -H "Cookie: admin_session=<session_token>"
```

**Query Parameters:**

| Parameter | Type   | Description                        |
|-----------|--------|------------------------------------|
| page      | int    | Page number (default: 1)           |
| limit     | int    | Items per page (default: 25)       |
| status    | string | Filter: active, disabled, pending  |
| search    | string | Search by email, name, or wallet   |

**Response 200:**

```json
{
  "users": [
    {
      "id": "usr_abc123",
      "email": "user@example.com",
      "name": "Jane Doe",
      "status": "active",
      "created_at": "2025-06-15T10:30:00Z",
      "last_login": "2026-02-13T08:00:00Z",
      "organization_id": "org_xyz789"
    }
  ],
  "total": 12450,
  "page": 1,
  "limit": 25
}
```

### GET /admin/users/{id}

Retrieve a specific user by ID.

```bash
curl -X GET https://api.blocksecops.com/admin/users/usr_abc123 \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "id": "usr_abc123",
  "email": "user@example.com",
  "name": "Jane Doe",
  "status": "active",
  "wallet_address": "0x1234...abcd",
  "mfa_enabled": true,
  "created_at": "2025-06-15T10:30:00Z",
  "last_login": "2026-02-13T08:00:00Z",
  "organization_id": "org_xyz789",
  "roles": ["member"],
  "scan_count": 42
}
```

### PATCH /admin/users/{id}

Update user details.

```bash
curl -X PATCH https://api.blocksecops.com/admin/users/usr_abc123 \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jane Smith",
    "email": "jane.smith@example.com"
  }'
```

**Response 200:** Returns the updated user object.

### DELETE /admin/users/{id}

Delete a user account permanently.

```bash
curl -X DELETE https://api.blocksecops.com/admin/users/usr_abc123 \
  -H "Cookie: admin_session=<session_token>"
```

**Response 204:** No content.

### POST /admin/users/{id}/enable

Re-enable a disabled user account.

```bash
curl -X POST https://api.blocksecops.com/admin/users/usr_abc123/enable \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "id": "usr_abc123",
  "status": "active",
  "enabled_at": "2026-02-14T12:00:00Z",
  "enabled_by": "admin_usr_001"
}
```

### POST /admin/users/{id}/disable

Disable a user account.

```bash
curl -X POST https://api.blocksecops.com/admin/users/usr_abc123/disable \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Terms of service violation"
  }'
```

**Response 200:**

```json
{
  "id": "usr_abc123",
  "status": "disabled",
  "disabled_at": "2026-02-14T12:00:00Z",
  "disabled_by": "admin_usr_001",
  "reason": "Terms of service violation"
}
```

---

## Admin Organizations

Organization management for administrators.

### GET /admin/organizations

List all organizations.

```bash
curl -X GET "https://api.blocksecops.com/admin/organizations?page=1&limit=25" \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "organizations": [
    {
      "id": "org_xyz789",
      "name": "Acme Security",
      "plan_tier": "enterprise",
      "member_count": 25,
      "scan_count": 1200,
      "created_at": "2025-03-10T09:00:00Z"
    }
  ],
  "total": 3200,
  "page": 1,
  "limit": 25
}
```

### GET /admin/organizations/{org_id}

Retrieve a specific organization.

```bash
curl -X GET https://api.blocksecops.com/admin/organizations/org_xyz789 \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "id": "org_xyz789",
  "name": "Acme Security",
  "plan_tier": "enterprise",
  "member_count": 25,
  "owner_id": "usr_abc123",
  "settings": {
    "ai_opt_out": false,
    "default_scan_depth": "deep"
  },
  "billing": {
    "subscription_status": "active",
    "current_period_end": "2026-03-10T09:00:00Z"
  },
  "created_at": "2025-03-10T09:00:00Z"
}
```

### PATCH /admin/organizations/{org_id}

Update organization details.

```bash
curl -X PATCH https://api.blocksecops.com/admin/organizations/org_xyz789 \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Security Corp",
    "plan_tier": "enterprise"
  }'
```

**Response 200:** Returns the updated organization object.

### DELETE /admin/organizations/{org_id}

Delete an organization and all associated data.

```bash
curl -X DELETE https://api.blocksecops.com/admin/organizations/org_xyz789 \
  -H "Cookie: admin_session=<session_token>"
```

**Response 204:** No content.

---

## Admin Audit

Audit log and security event endpoints.

### GET /admin/audit/logs

Retrieve audit logs with filtering.

```bash
curl -X GET "https://api.blocksecops.com/admin/audit/logs?page=1&limit=50&action=user.login" \
  -H "Cookie: admin_session=<session_token>"
```

**Query Parameters:**

| Parameter  | Type   | Description                          |
|------------|--------|--------------------------------------|
| page       | int    | Page number                          |
| limit      | int    | Items per page                       |
| action     | string | Filter by action type                |
| user_id    | string | Filter by user                       |
| start_date | string | ISO 8601 start date                  |
| end_date   | string | ISO 8601 end date                    |

**Response 200:**

```json
{
  "logs": [
    {
      "id": "log_001",
      "action": "user.login",
      "user_id": "usr_abc123",
      "ip_address": "192.168.1.100",
      "user_agent": "Mozilla/5.0...",
      "metadata": {},
      "created_at": "2026-02-14T08:30:00Z"
    }
  ],
  "total": 50000,
  "page": 1,
  "limit": 50
}
```

### GET /admin/audit/admin-actions

Retrieve admin-specific action logs.

```bash
curl -X GET "https://api.blocksecops.com/admin/audit/admin-actions?page=1&limit=25" \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "actions": [
    {
      "id": "action_001",
      "admin_id": "admin_usr_001",
      "action": "user.disabled",
      "target_type": "user",
      "target_id": "usr_abc123",
      "reason": "Terms of service violation",
      "created_at": "2026-02-14T10:00:00Z"
    }
  ],
  "total": 850,
  "page": 1,
  "limit": 25
}
```

### GET /admin/audit/security-events

Retrieve security-related events (failed logins, suspicious activity, etc.).

```bash
curl -X GET "https://api.blocksecops.com/admin/audit/security-events?severity=high" \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "events": [
    {
      "id": "evt_001",
      "type": "brute_force_attempt",
      "severity": "high",
      "source_ip": "10.0.0.50",
      "target_user_id": "usr_abc123",
      "details": "15 failed login attempts in 5 minutes",
      "created_at": "2026-02-14T07:45:00Z"
    }
  ],
  "total": 120,
  "page": 1,
  "limit": 25
}
```

---

## Admin Auth

Admin authentication and session management.

### GET /admin/auth/session

Retrieve current admin session details.

```bash
curl -X GET https://api.blocksecops.com/admin/auth/session \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "admin_id": "admin_usr_001",
  "email": "admin@blocksecops.com",
  "mfa_verified": true,
  "session_expires_at": "2026-02-14T20:00:00Z",
  "permissions": ["users.manage", "orgs.manage", "system.configure"]
}
```

### POST /admin/auth/logout

Terminate the current admin session.

```bash
curl -X POST https://api.blocksecops.com/admin/auth/logout \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "message": "Admin session terminated"
}
```

### POST /admin/auth/mfa/setup

Initiate MFA setup for admin access.

```bash
curl -X POST https://api.blocksecops.com/admin/auth/mfa/setup \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "secret": "JBSWY3DPEHPK3PXP",
  "qr_code_url": "otpauth://totp/BlockSecOps:admin@blocksecops.com?secret=JBSWY3DPEHPK3PXP",
  "backup_codes": ["abc123", "def456", "ghi789"]
}
```

### POST /admin/auth/mfa/verify

Verify MFA token for admin session elevation.

```bash
curl -X POST https://api.blocksecops.com/admin/auth/mfa/verify \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "123456"
  }'
```

**Response 200:**

```json
{
  "mfa_verified": true,
  "session_expires_at": "2026-02-14T20:00:00Z"
}
```

---

## Admin Emergency

Emergency operations for incident response.

### POST /admin/emergency/disable-user

Immediately disable a user account (emergency use).

```bash
curl -X POST https://api.blocksecops.com/admin/emergency/disable-user \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "usr_abc123",
    "reason": "Compromised account detected"
  }'
```

**Response 200:**

```json
{
  "user_id": "usr_abc123",
  "status": "disabled",
  "sessions_revoked": 3,
  "api_keys_disabled": 2,
  "action_by": "admin_usr_001",
  "timestamp": "2026-02-14T12:00:00Z"
}
```

### POST /admin/emergency/revoke-admin

Revoke admin privileges from a user.

```bash
curl -X POST https://api.blocksecops.com/admin/emergency/revoke-admin \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "admin_id": "admin_usr_002",
    "reason": "Role change"
  }'
```

**Response 200:**

```json
{
  "admin_id": "admin_usr_002",
  "admin_revoked": true,
  "sessions_terminated": 1,
  "timestamp": "2026-02-14T12:00:00Z"
}
```

### POST /admin/emergency/revoke-sessions

Revoke all active sessions for a specific user.

```bash
curl -X POST https://api.blocksecops.com/admin/emergency/revoke-sessions \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "usr_abc123"
  }'
```

**Response 200:**

```json
{
  "user_id": "usr_abc123",
  "sessions_revoked": 5,
  "timestamp": "2026-02-14T12:00:00Z"
}
```

### POST /admin/emergency/unlock-mfa

Unlock/reset MFA for a locked-out user.

```bash
curl -X POST https://api.blocksecops.com/admin/emergency/unlock-mfa \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "usr_abc123",
    "reason": "User lost authenticator device"
  }'
```

**Response 200:**

```json
{
  "user_id": "usr_abc123",
  "mfa_reset": true,
  "temporary_bypass_expires_at": "2026-02-14T13:00:00Z",
  "timestamp": "2026-02-14T12:00:00Z"
}
```

---

## Admin Scan Monitoring

Monitor and manage ongoing and stale scans.

### GET /admin/scan-monitoring/stats

Retrieve scan monitoring statistics.

```bash
curl -X GET https://api.blocksecops.com/admin/scan-monitoring/stats \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "active_scans": 42,
  "queued_scans": 15,
  "completed_today": 310,
  "failed_today": 8,
  "average_duration_seconds": 145,
  "stale_scans": 3
}
```

### GET /admin/scan-monitoring/stale

List scans that appear stale or stuck.

```bash
curl -X GET https://api.blocksecops.com/admin/scan-monitoring/stale \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "stale_scans": [
    {
      "id": "scan_abc123",
      "user_id": "usr_def456",
      "status": "in_progress",
      "started_at": "2026-02-13T10:00:00Z",
      "last_heartbeat": "2026-02-13T10:30:00Z",
      "duration_seconds": 93600
    }
  ],
  "total": 3
}
```

### POST /admin/scan-monitoring/scans/{id}/fail

Force-fail a stuck scan.

```bash
curl -X POST https://api.blocksecops.com/admin/scan-monitoring/scans/scan_abc123/fail \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Scan exceeded maximum duration"
  }'
```

**Response 200:**

```json
{
  "id": "scan_abc123",
  "status": "failed",
  "failure_reason": "Scan exceeded maximum duration",
  "failed_by": "admin_usr_001",
  "failed_at": "2026-02-14T12:00:00Z"
}
```

### POST /admin/scan-monitoring/scans/{id}/retry

Retry a failed scan.

```bash
curl -X POST https://api.blocksecops.com/admin/scan-monitoring/scans/scan_abc123/retry \
  -H "Cookie: admin_session=<session_token>"
```

**Response 202:**

```json
{
  "original_scan_id": "scan_abc123",
  "new_scan_id": "scan_ghi789",
  "status": "queued",
  "retried_by": "admin_usr_001"
}
```

---

## Admin Purchases

Purchase and subscription analytics.

### GET /admin/purchases/stats

Retrieve overall purchase statistics.

```bash
curl -X GET https://api.blocksecops.com/admin/purchases/stats \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "total_revenue_usd": 245000.00,
  "revenue_this_month": 32000.00,
  "total_subscriptions": 890,
  "active_subscriptions": 720,
  "total_credit_purchases": 4500,
  "mrr_usd": 28500.00
}
```

### GET /admin/purchases/subscriptions

List all subscriptions.

```bash
curl -X GET "https://api.blocksecops.com/admin/purchases/subscriptions?status=active&page=1&limit=25" \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "subscriptions": [
    {
      "id": "sub_abc123",
      "user_id": "usr_def456",
      "organization_id": "org_xyz789",
      "plan_tier": "professional",
      "status": "active",
      "amount_usd": 99.00,
      "current_period_end": "2026-03-14T00:00:00Z"
    }
  ],
  "total": 720,
  "page": 1,
  "limit": 25
}
```

### GET /admin/purchases/transactions

List all transactions.

```bash
curl -X GET "https://api.blocksecops.com/admin/purchases/transactions?page=1&limit=25" \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "transactions": [
    {
      "id": "txn_abc123",
      "user_id": "usr_def456",
      "type": "credit_purchase",
      "amount_usd": 125.00,
      "payment_method": "stripe",
      "status": "completed",
      "created_at": "2026-02-13T15:00:00Z"
    }
  ],
  "total": 4500,
  "page": 1,
  "limit": 25
}
```

### GET /admin/purchases/details

Retrieve detailed purchase analytics.

```bash
curl -X GET "https://api.blocksecops.com/admin/purchases/details?start_date=2026-01-01&end_date=2026-02-14" \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "period": {
    "start": "2026-01-01T00:00:00Z",
    "end": "2026-02-14T23:59:59Z"
  },
  "revenue_by_type": {
    "subscriptions": 57000.00,
    "credit_purchases": 18500.00,
    "per_scan_payments": 3200.00
  },
  "top_plans": [
    { "tier": "professional", "count": 350, "revenue": 34650.00 },
    { "tier": "enterprise", "count": 85, "revenue": 21250.00 }
  ]
}
```

---

## Admin Support

Customer support and impersonation endpoints.

### GET /admin/support/customers/search

Search for customers by email, name, or wallet address.

```bash
curl -X GET "https://api.blocksecops.com/admin/support/customers/search?q=jane@example.com" \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "customers": [
    {
      "id": "usr_abc123",
      "email": "jane@example.com",
      "name": "Jane Doe",
      "organization": "Acme Security",
      "plan_tier": "professional",
      "status": "active"
    }
  ],
  "total": 1
}
```

### GET /admin/support/customers/{id}

Retrieve full customer profile for support purposes.

```bash
curl -X GET https://api.blocksecops.com/admin/support/customers/usr_abc123 \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "id": "usr_abc123",
  "email": "jane@example.com",
  "name": "Jane Doe",
  "status": "active",
  "organization_id": "org_xyz789",
  "plan_tier": "professional",
  "credit_balance": 35,
  "total_scans": 142,
  "created_at": "2025-06-15T10:30:00Z",
  "last_login": "2026-02-13T08:00:00Z"
}
```

### GET /admin/support/customers/{id}/billing

Retrieve customer billing information.

```bash
curl -X GET https://api.blocksecops.com/admin/support/customers/usr_abc123/billing \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "customer_id": "usr_abc123",
  "subscription": {
    "plan_tier": "professional",
    "status": "active",
    "amount_usd": 99.00,
    "current_period_end": "2026-03-15T00:00:00Z"
  },
  "payment_method": "card_ending_4242",
  "total_spent_usd": 1485.00,
  "recent_invoices": []
}
```

### GET /admin/support/customers/{id}/contracts

Retrieve customer contracts.

```bash
curl -X GET https://api.blocksecops.com/admin/support/customers/usr_abc123/contracts \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "contracts": [
    {
      "id": "contract_001",
      "address": "0xdead...beef",
      "chain": "ethereum",
      "name": "MyToken",
      "added_at": "2025-08-20T14:00:00Z"
    }
  ],
  "total": 8
}
```

### GET /admin/support/customers/{id}/scans

Retrieve customer scan history.

```bash
curl -X GET "https://api.blocksecops.com/admin/support/customers/usr_abc123/scans?page=1&limit=10" \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "scans": [
    {
      "id": "scan_abc123",
      "contract_address": "0xdead...beef",
      "status": "completed",
      "vulnerability_count": 3,
      "created_at": "2026-02-10T09:00:00Z",
      "completed_at": "2026-02-10T09:02:30Z"
    }
  ],
  "total": 142,
  "page": 1,
  "limit": 10
}
```

### POST /admin/support/customers/{id}/impersonate

Start an impersonation session for a customer (for support debugging).

```bash
curl -X POST https://api.blocksecops.com/admin/support/customers/usr_abc123/impersonate \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Investigating scan failure reported in ticket #1234"
  }'
```

**Response 200:**

```json
{
  "impersonation_token": "imp_token_xyz",
  "target_user_id": "usr_abc123",
  "expires_at": "2026-02-14T13:00:00Z",
  "admin_id": "admin_usr_001"
}
```

### POST /admin/support/impersonate/end

End the current impersonation session.

```bash
curl -X POST https://api.blocksecops.com/admin/support/impersonate/end \
  -H "Cookie: admin_session=<session_token>" \
  -H "X-Impersonation-Token: imp_token_xyz"
```

**Response 200:**

```json
{
  "message": "Impersonation session ended",
  "duration_seconds": 300
}
```

### POST /admin/support/customers/{id}/scans/{scan_id}/rerun

Rerun a specific scan for a customer.

```bash
curl -X POST https://api.blocksecops.com/admin/support/customers/usr_abc123/scans/scan_abc123/rerun \
  -H "Cookie: admin_session=<session_token>"
```

**Response 202:**

```json
{
  "original_scan_id": "scan_abc123",
  "new_scan_id": "scan_new456",
  "status": "queued",
  "initiated_by": "admin_usr_001"
}
```

### GET /admin/support/customers/{id}/scans/{scan_id}/results

Retrieve detailed scan results for support review.

```bash
curl -X GET https://api.blocksecops.com/admin/support/customers/usr_abc123/scans/scan_abc123/results \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "scan_id": "scan_abc123",
  "status": "completed",
  "contract_address": "0xdead...beef",
  "vulnerabilities": [
    {
      "id": "vuln_001",
      "severity": "high",
      "type": "reentrancy",
      "location": "withdraw():L45",
      "description": "Potential reentrancy vulnerability in withdraw function"
    }
  ],
  "summary": {
    "critical": 0,
    "high": 1,
    "medium": 2,
    "low": 0,
    "informational": 3
  }
}
```

---

## Admin Dependencies

Dependency analysis endpoints.

### GET /admin/dependencies

Retrieve system dependency information and vulnerability status.

```bash
curl -X GET https://api.blocksecops.com/admin/dependencies \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "dependencies": [
    {
      "name": "solc",
      "version": "0.8.24",
      "latest_version": "0.8.25",
      "update_available": true,
      "known_vulnerabilities": 0
    },
    {
      "name": "mythril",
      "version": "0.24.7",
      "latest_version": "0.24.7",
      "update_available": false,
      "known_vulnerabilities": 0
    }
  ],
  "total": 24,
  "outdated": 5,
  "vulnerable": 0
}
```
