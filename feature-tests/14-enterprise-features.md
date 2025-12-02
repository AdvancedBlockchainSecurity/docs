# Enterprise Features Tests (Phase 4.5)

**Priority**: P1 - High
**Last Tested**: _Not yet tested_
**Feature**: Webhooks, RBAC, SSO, API Keys, Audit Logging

---

## 1. Webhook System

### 1.1 Webhook CRUD Operations
- [ ] `POST /api/v1/webhooks` creates webhook successfully
- [ ] Webhook secret returned only on creation
- [ ] Secret format: `whsec_` prefix + random token
- [ ] `GET /api/v1/webhooks` lists all user webhooks
- [ ] `GET /api/v1/webhooks/{id}` returns webhook details (no secret)
- [ ] `PATCH /api/v1/webhooks/{id}` updates webhook
- [ ] `DELETE /api/v1/webhooks/{id}` removes webhook
- [ ] Cannot access other user's webhooks (403)

### 1.2 Event Types
- [ ] `GET /api/v1/webhooks/events` returns all event types
- [ ] Event types include descriptions
- [ ] `scan.started` event available
- [ ] `scan.completed` event available
- [ ] `scan.failed` event available
- [ ] `vulnerability.detected` event available
- [ ] `vulnerability.critical` event available
- [ ] `contract.added` event available
- [ ] `contract.deleted` event available

### 1.3 Event Subscription
- [ ] Subscribe to single event type
- [ ] Subscribe to multiple event types
- [ ] Invalid event type returns 400 error
- [ ] Events array cannot be empty
- [ ] Event filtering works correctly

### 1.4 Webhook Delivery
- [ ] Webhook triggered on subscribed event
- [ ] Payload includes event_type
- [ ] Payload includes event_id (unique)
- [ ] Payload includes timestamp
- [ ] Payload includes event-specific data
- [ ] X-BlockSecOps-Signature header present
- [ ] X-BlockSecOps-Event header present
- [ ] X-BlockSecOps-Delivery header present
- [ ] X-BlockSecOps-Timestamp header present

### 1.5 Signature Verification
- [ ] HMAC-SHA256 signature is correct
- [ ] Signature format: `sha256=<hex>`
- [ ] Signature verifiable with webhook secret
- [ ] Invalid signature detection works client-side

### 1.6 Retry Policy
- [ ] Failed delivery triggers retry
- [ ] Exponential backoff: 1s, 5s, 30s
- [ ] Maximum 3 retry attempts (configurable)
- [ ] Timeout after 30 seconds (configurable)
- [ ] Failed deliveries logged

### 1.7 Delivery History
- [ ] `GET /api/v1/webhooks/{id}/deliveries` returns history
- [ ] Delivery includes status_code
- [ ] Delivery includes success boolean
- [ ] Delivery includes attempt_number
- [ ] Delivery includes duration_ms
- [ ] Delivery includes error_message (if failed)
- [ ] Filter by success status works
- [ ] Pagination works

### 1.8 Secret Rotation
- [ ] `POST /api/v1/webhooks/{id}/rotate-secret` rotates secret
- [ ] New secret returned in response
- [ ] Old secret immediately invalidated
- [ ] New deliveries use new secret

### 1.9 Webhook Statistics
- [ ] total_deliveries count accurate
- [ ] successful_deliveries count accurate
- [ ] failed_deliveries count accurate
- [ ] last_triggered_at updated
- [ ] last_success_at updated on success
- [ ] last_failure_at updated on failure
- [ ] last_error contains failure message

### 1.10 Tier Restrictions
- [ ] Free tier cannot create webhooks
- [ ] Pro tier limited to 5 webhooks
- [ ] Enterprise tier unlimited webhooks
- [ ] Tier upgrade enables webhook creation

---

## 2. Role-Based Access Control (RBAC)

### 2.1 Organization CRUD
- [ ] `POST /api/v1/organizations` creates organization
- [ ] Creator becomes owner automatically
- [ ] Slug generated from name
- [ ] Slug must be unique
- [ ] `GET /api/v1/organizations` lists user's orgs
- [ ] `GET /api/v1/organizations/{id}` returns details
- [ ] `PATCH /api/v1/organizations/{id}` updates org
- [ ] `DELETE /api/v1/organizations/{id}` removes org
- [ ] Only owner can delete organization

### 2.2 System Roles
- [ ] Owner role exists with full permissions
- [ ] Admin role exists
- [ ] Developer role exists
- [ ] Viewer role exists
- [ ] Auditor role exists
- [ ] System roles cannot be deleted
- [ ] System roles cannot be modified

### 2.3 Permission Matrix
- [ ] Owner: all permissions
- [ ] Admin: all except billing/ownership
- [ ] Developer: create/read contracts, trigger scans
- [ ] Viewer: read-only access
- [ ] Auditor: read + audit log viewing

### 2.4 Member Management
- [ ] `POST /api/v1/organizations/{id}/members` invites member
- [ ] Invitation email sent (if configured)
- [ ] `GET /api/v1/organizations/{id}/members` lists members
- [ ] `PATCH /api/v1/organizations/{id}/members/{user_id}` changes role
- [ ] `DELETE /api/v1/organizations/{id}/members/{user_id}` removes member
- [ ] Owner cannot be removed
- [ ] Only owner/admin can manage members

### 2.5 Custom Roles (Enterprise)
- [ ] `POST /api/v1/organizations/{id}/roles` creates custom role
- [ ] Custom role requires display_name
- [ ] Custom role requires permissions array
- [ ] Invalid permission rejected
- [ ] `PATCH /api/v1/organizations/{id}/roles/{role_id}` updates role
- [ ] `DELETE /api/v1/organizations/{id}/roles/{role_id}` deletes role
- [ ] Cannot delete role with assigned members

### 2.6 Permission Enforcement
- [ ] Unauthorized action returns 403
- [ ] Permission checked on every request
- [ ] Cross-organization access blocked
- [ ] Resource ownership validated

---

## 3. Single Sign-On (SSO)

### 3.1 SSO Configuration
- [ ] `GET /api/v1/organizations/{id}/sso` returns config
- [ ] `POST /api/v1/organizations/{id}/sso/saml` configures SAML
- [ ] `POST /api/v1/organizations/{id}/sso/oidc` configures OIDC
- [ ] `PATCH /api/v1/organizations/{id}/sso` enables/disables SSO
- [ ] Only owner/admin can configure SSO

### 3.2 SAML Configuration
- [ ] IDP Entity ID required
- [ ] IDP SSO URL required
- [ ] IDP Certificate required (PEM format)
- [ ] SP Entity ID generated correctly
- [ ] ACS URL correct

### 3.3 OIDC Configuration
- [ ] Issuer URL required
- [ ] Client ID required
- [ ] Client Secret required
- [ ] Discovery endpoint used
- [ ] Redirect URI correct

### 3.4 Domain-Based SSO
- [ ] SSO domain configurable
- [ ] Users with domain email redirected to SSO
- [ ] Multiple domains supported (enterprise)
- [ ] SSO bypass for non-domain emails

### 3.5 SSO Testing
- [ ] `POST /api/v1/organizations/{id}/sso/test` validates config
- [ ] Test returns success/failure
- [ ] Error message helpful for debugging

### 3.6 Supported Providers
- [ ] Okta (SAML/OIDC)
- [ ] Azure AD (SAML/OIDC)
- [ ] Google Workspace (OIDC)
- [ ] OneLogin (SAML)
- [ ] Auth0 (OIDC)
- [ ] Custom SAML 2.0
- [ ] Custom OIDC 1.0

### 3.7 SSO Login Flow
- [ ] Email domain triggers SSO redirect
- [ ] SAML assertion validated
- [ ] OIDC tokens validated
- [ ] User created if not exists
- [ ] User linked to organization
- [ ] JWT issued after SSO success

---

## 4. API Keys

### 4.1 API Key CRUD
- [ ] `POST /api/v1/api-keys` creates key
- [ ] Full key shown only on creation
- [ ] Key format: `bso_live_` or `bso_test_` prefix
- [ ] `GET /api/v1/api-keys` lists keys (masked)
- [ ] `DELETE /api/v1/api-keys/{id}` revokes key
- [ ] Revoked key immediately invalid

### 4.2 Key Scopes
- [ ] `contracts:read` scope works
- [ ] `contracts:write` scope works
- [ ] `scans:read` scope works
- [ ] `scans:write` scope works
- [ ] `vulnerabilities:read` scope works
- [ ] `webhooks:manage` scope works
- [ ] Invalid scope rejected
- [ ] Scope enforcement on endpoints

### 4.3 Key Expiration
- [ ] Expiration date configurable
- [ ] Expired key returns 401
- [ ] No expiration option available
- [ ] Expiration warning (optional)

### 4.4 Rate Limiting
- [ ] Per-minute limit enforced
- [ ] Per-hour limit enforced
- [ ] Rate limit headers returned
- [ ] 429 returned when exceeded
- [ ] Limits vary by tier

### 4.5 API Key Usage
- [ ] `GET /api/v1/api-keys/{id}/usage` returns stats
- [ ] Total requests counted
- [ ] Last used timestamp updated
- [ ] Usage by endpoint available

### 4.6 Authentication with API Key
- [ ] Authorization: Bearer <key> works
- [ ] X-API-Key header works
- [ ] Invalid key returns 401
- [ ] Revoked key returns 401
- [ ] Scope mismatch returns 403

---

## 5. Audit Logging

### 5.1 Logged Events
- [ ] Login events logged
- [ ] Logout events logged
- [ ] Failed login attempts logged
- [ ] Contract creation logged
- [ ] Contract deletion logged
- [ ] Scan creation logged
- [ ] Webhook creation logged
- [ ] Member invitation logged
- [ ] Role changes logged
- [ ] API key creation logged
- [ ] SSO events logged

### 5.2 Log Entry Structure
- [ ] Unique ID generated
- [ ] Action type recorded
- [ ] User ID recorded
- [ ] Organization ID recorded (if applicable)
- [ ] Resource type recorded
- [ ] Resource ID recorded
- [ ] IP address captured
- [ ] User agent captured
- [ ] Request ID for correlation
- [ ] Old values recorded (for updates)
- [ ] New values recorded (for updates)
- [ ] Success/failure status
- [ ] Timestamp accurate

### 5.3 Log Querying
- [ ] `GET /api/v1/audit-logs` returns logs
- [ ] Filter by action type works
- [ ] Filter by user ID works
- [ ] Filter by date range works
- [ ] Filter by resource type works
- [ ] Pagination works
- [ ] Sorting by date works

### 5.4 Log Export
- [ ] `GET /api/v1/audit-logs/export?format=csv` exports CSV
- [ ] `GET /api/v1/audit-logs/export?format=json` exports JSON
- [ ] Date range filter in export
- [ ] Large exports handled (streaming)

### 5.5 Access Control
- [ ] Only admin/owner/auditor can view logs
- [ ] Cross-organization logs blocked
- [ ] Sensitive data redacted appropriately

### 5.6 Retention Policy
- [ ] Free tier: 7 days retention
- [ ] Pro tier: 30 days retention
- [ ] Enterprise tier: 1 year retention
- [ ] Old logs automatically purged
- [ ] Retention configurable (enterprise)

---

## 6. Database & Migration

### 6.1 Webhook Tables
- [ ] `webhooks` table created
- [ ] `webhook_deliveries` table created
- [ ] Foreign keys correct
- [ ] Indexes created

### 6.2 RBAC Tables
- [ ] `organizations` table created
- [ ] `roles` table created
- [ ] `organization_members` table created
- [ ] Unique constraints correct
- [ ] Cascade deletes work

### 6.3 API Key Tables
- [ ] `api_keys` table created
- [ ] Key hash stored (not plaintext)
- [ ] Indexes on key_prefix

### 6.4 Audit Log Tables
- [ ] `audit_logs` table created
- [ ] JSONB columns for values
- [ ] Indexes on action, user_id, created_at
- [ ] Partitioning for performance (optional)

---

## 7. Frontend Components

### 7.1 Webhook Settings UI
- [ ] Webhook list displayed
- [ ] Create webhook form works
- [ ] Edit webhook form works
- [ ] Delete webhook with confirmation
- [ ] Secret display on creation
- [ ] Secret rotation button
- [ ] Delivery history view
- [ ] Active/inactive toggle

### 7.2 Organization Switcher
- [ ] Organization dropdown visible
- [ ] Current org highlighted
- [ ] Switch organization works
- [ ] Create organization option

### 7.3 Member Management UI
- [ ] Member list displayed
- [ ] Invite member form
- [ ] Role selection dropdown
- [ ] Remove member with confirmation
- [ ] Role change dropdown

### 7.4 API Key Management UI
- [ ] API key list displayed
- [ ] Create key form with scope selection
- [ ] Key shown once on creation
- [ ] Copy button for key
- [ ] Revoke key with confirmation
- [ ] Usage statistics display

### 7.5 Audit Log Viewer
- [ ] Log table displayed
- [ ] Filters for action/user/date
- [ ] Pagination controls
- [ ] Export button
- [ ] Log detail modal

---

## 8. Tier Availability

### 8.1 Free Tier
- [ ] No webhooks
- [ ] No organizations
- [ ] 1 team member (self)
- [ ] 1 API key
- [ ] 7 days audit logs
- [ ] No audit export

### 8.2 Pro Tier
- [ ] 5 webhooks
- [ ] 1 organization
- [ ] 5 team members
- [ ] 5 API keys
- [ ] 30 days audit logs
- [ ] No audit export

### 8.3 Enterprise Tier
- [ ] Unlimited webhooks
- [ ] Unlimited organizations
- [ ] Unlimited team members
- [ ] Custom roles
- [ ] SSO (SAML/OIDC)
- [ ] Unlimited API keys
- [ ] 1 year audit logs
- [ ] Audit export

---

## Test Notes

_Record enterprise features test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
