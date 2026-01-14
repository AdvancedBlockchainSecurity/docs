# Enterprise Features Tests (Phase 4.5)

**Priority**: P1 - High
**Last Tested**: January 13, 2026
**Feature**: Webhooks, RBAC, SSO, API Keys, Audit Logging, TierGate, UpgradeBanner
**API Version**: 0.5.0
**Dashboard Version**: 0.30.1

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

## 7. Frontend Components (Dashboard v0.13.5)

### 7.1 Sidebar Navigation - ADMIN Section
- [ ] ADMIN section visible in sidebar
- [ ] Section is collapsible/expandable
- [ ] Contains 4 items: API Keys, Webhooks, Audit Logs, Organizations
- [ ] API Keys link navigates to `/api-keys`
- [ ] Webhooks link navigates to `/webhooks`
- [ ] Audit Logs link navigates to `/audit-logs`
- [ ] Organizations link navigates to `/organizations`
- [ ] Active page is highlighted in sidebar

### 7.2 TierGate Component Behavior
- [ ] Free tier user sees upgrade prompt on API Keys page
- [ ] Free tier user sees upgrade prompt on Webhooks page
- [ ] Free tier user sees upgrade prompt on Audit Logs page
- [ ] Free tier user sees upgrade prompt on Organizations page
- [ ] Pro tier user can access API Keys page
- [ ] Pro tier user can access Webhooks page
- [ ] Pro tier user sees upgrade prompt on Audit Logs page
- [ ] Pro tier user sees upgrade prompt on Organizations page
- [ ] Enterprise tier user can access all 4 pages
- [ ] Upgrade prompt shows correct feature name
- [ ] Upgrade prompt shows correct required tier
- [ ] Loading spinner shown while user profile is being fetched (v0.13.4+)
- [ ] No flash of upgrade prompt for enterprise users during page load (v0.13.4+)
- [ ] `isEnhancedProfileLoaded` state prevents premature tier evaluation

### 7.2.1 TierGate Preview Mode (v0.30.0)

**Preview Mode Behavior:**
- [ ] `mode="preview"` shows greyed content with overlay
- [ ] Content is visible but not interactive
- [ ] Purple "Upgrade to {tier}" badge displayed top-right
- [ ] Badge links to /pricing page
- [ ] Click on greyed content does not trigger actions

**ProjectDetail Page TierGate Usage:**
- [ ] QualityGatePanel wrapped in TierGate with `mode="preview"`
- [ ] Free tier users see greyed QualityGatePanel
- [ ] Developer+ users see fully functional QualityGatePanel
- [ ] ProjectAccessPanel wrapped in TierGate with `mode="preview"`
- [ ] Enterprise users see fully functional ProjectAccessPanel
- [ ] Non-enterprise users see greyed ProjectAccessPanel

### 7.2.2 UpgradeBanner Component (v0.30.1)

**Banner Display:**
- [ ] UpgradeBanner appears at top of dashboard (below TopBar)
- [ ] Shows on all authenticated pages (global placement)
- [ ] Gradient background (indigo to purple)
- [ ] Shows sparkles icon and upgrade message
- [ ] Shows up to 3 feature highlights (desktop only)
- [ ] Shows price badge and "View Plans" button

**Tier-Based Display:**
- [ ] Free user sees Developer promotion
- [ ] Developer user sees Startup promotion
- [ ] Startup user sees Professional promotion
- [ ] Professional user sees Enterprise promotion
- [ ] Enterprise user: Banner NOT displayed

**Dismissal Behavior:**
- [ ] X button dismisses banner
- [ ] Banner hidden for 7 days after dismissal
- [ ] Dismissal stored in localStorage (`upgrade-banner-dismissed`)
- [ ] After 7 days, banner reappears
- [ ] Clearing localStorage makes banner reappear immediately

### 7.3 API Keys Page (`/api-keys`)

#### 7.3.1 Page Layout
- [ ] Page title "API Keys" displayed
- [ ] Subtitle "Manage programmatic access to the BlockSecOps API" displayed
- [ ] "Create API Key" button visible in header
- [ ] Stats cards row displayed (4 cards)

#### 7.3.2 Stats Cards
- [ ] "Total Keys" card shows correct count
- [ ] "Active Keys" card shows count of non-revoked keys
- [ ] "Total Requests" card shows sum of all key usage
- [ ] "Last Used" card shows most recent activity time

#### 7.3.3 Info Banner
- [ ] Blue info banner displayed with security message
- [ ] Warning about secret being shown only once
- [ ] HMAC-SHA256 signature info mentioned

#### 7.3.4 API Keys Table
- [ ] Table headers: Name, Key, Scopes, Last Used, Status, Actions
- [ ] Keys list is displayed (or empty state if none)
- [ ] Key shows name and description
- [ ] Key prefix displayed (masked, e.g., `bso_live_...abc123`)
- [ ] Scopes shown as tags (first 2 + overflow count)
- [ ] Last used shows relative time ("2 hours ago")
- [ ] Status badge shows Active (green) or Revoked (red)
- [ ] Actions column shows Regenerate and Revoke buttons

#### 7.3.5 Create API Key Modal
- [ ] Modal opens on "Create API Key" button click
- [ ] Name field required
- [ ] Scopes multi-select works (checkboxes)
- [ ] All 10 scopes available for selection (with descriptions)
- [ ] Loading state shown while scopes are fetched
- [ ] Expiration dropdown (Never, 30d, 90d, 6mo, 1yr)
- [ ] "Never expires" correctly sends no expiration to API (v0.13.5+)
- [ ] Rate limit fields shown (per minute: 1-1000, per hour: 1-10000)
- [ ] Cancel button closes modal
- [ ] Create button submits form
- [ ] Validation errors displayed
- [ ] NaN values not sent for optional numeric fields (v0.13.5+)

#### 7.3.6 API Key Secret Display
- [ ] After creation, secret shown in special component
- [ ] Warning message "This is the only time you'll see this key"
- [ ] Key displayed in monospace font
- [ ] Copy button works (copies to clipboard)
- [ ] "I've saved this key" checkbox required
- [ ] Done button disabled until checkbox checked
- [ ] Done button closes modal

#### 7.3.7 Revoke Confirmation
- [ ] Click Revoke shows inline confirmation
- [ ] "Revoke?" text with Yes/No buttons
- [ ] Yes revokes the key
- [ ] No cancels confirmation
- [ ] Revoked key shows "Revoked" status badge

#### 7.3.8 Empty State
- [ ] Empty state displayed when no keys
- [ ] Icon shown (key icon)
- [ ] "No API Keys" heading
- [ ] Helpful message about creating first key

### 7.4 Webhooks Page (`/webhooks`)

#### 7.4.1 Page Layout
- [ ] Page title "Webhooks" displayed
- [ ] Subtitle about receiving notifications displayed
- [ ] "Create Webhook" button (disabled with "Coming soon" tooltip)
- [ ] Stats cards row displayed (4 cards)

#### 7.4.2 Stats Cards
- [ ] "Total Webhooks" card shows correct count
- [ ] "Active" card shows count of active webhooks
- [ ] "Total Deliveries" card shows delivery count
- [ ] "Success Rate" card shows percentage

#### 7.4.3 Info Banner
- [ ] Blue info banner about webhook events
- [ ] Mentions scan.completed, vulnerability.detected events
- [ ] Mentions HMAC-SHA256 signing

#### 7.4.4 Webhooks Table
- [ ] Table headers: Webhook, Events, Deliveries, Status, Actions
- [ ] Webhook column shows name and URL
- [ ] URL shown in monospace, truncated
- [ ] Events shown as tags (first 2 + overflow)
- [ ] Deliveries shows successful/total count
- [ ] Last triggered time shown
- [ ] Status toggle button (Active/Paused)

#### 7.4.5 Status Toggle
- [ ] Click Active/Paused badge toggles status
- [ ] Active shows green badge
- [ ] Paused shows gray badge
- [ ] State persists after toggle

#### 7.4.6 Test Webhook
- [ ] Play button icon in Actions column
- [ ] Click triggers test webhook
- [ ] Success shows alert "Webhook test successful!"
- [ ] Failure shows alert with error message
- [ ] Button disabled while test in progress

#### 7.4.7 Delete Webhook
- [ ] Trash icon in Actions column
- [ ] Click shows inline confirmation
- [ ] Yes deletes webhook
- [ ] No cancels deletion
- [ ] Webhook removed from list

#### 7.4.8 Empty State
- [ ] Bell icon displayed
- [ ] "No Webhooks" heading
- [ ] Message about creating webhook

### 7.5 Audit Logs Page (`/audit-logs`)

#### 7.5.1 Page Layout
- [ ] Page title "Audit Logs" displayed
- [ ] Subtitle about tracking actions displayed
- [ ] "Filters" button in header
- [ ] "Export CSV" button in header
- [ ] "Export JSON" button in header
- [ ] Stats cards row (4 cards)

#### 7.5.2 Stats Cards
- [ ] "Total Events (30d)" shows event count
- [ ] "Successful" shows success count (green)
- [ ] "Failed" shows failure count (red)
- [ ] "Unique Users" shows user count

#### 7.5.3 Filters Panel
- [ ] Click "Filters" toggles filter panel
- [ ] Category dropdown (All, auth, contracts, scans, etc.)
- [ ] Status dropdown (All, Success, Failed)
- [ ] Start Date picker
- [ ] End Date picker
- [ ] Search input for actions
- [ ] IP Address filter input
- [ ] "Clear Filters" button resets all

#### 7.5.4 Audit Logs Table
- [ ] Table headers: Timestamp, Action, Resource, IP Address, Status, Details
- [ ] Timestamp shows date and time separately
- [ ] Action shows colored badge by category
- [ ] Resource shows type and truncated ID
- [ ] IP shows in monospace (or dash if none)
- [ ] Status shows Success (green) or Failed (red) badge
- [ ] Expand button (chevron) in Details column

#### 7.5.5 Expandable Details
- [ ] Click chevron expands row
- [ ] Shows Request ID
- [ ] Shows User Agent (truncated)
- [ ] Shows Error message (if failed)
- [ ] Shows Changes section (if applicable)
- [ ] Before/After values in colored boxes
- [ ] Click again collapses row

#### 7.5.6 Pagination
- [ ] Pagination controls at bottom
- [ ] Shows "Showing X-Y of Z results"
- [ ] Previous button disabled on first page
- [ ] Next button disabled on last page
- [ ] Page number displayed

#### 7.5.7 Export Functions
- [ ] "Export CSV" downloads CSV file
- [ ] "Export JSON" downloads JSON file
- [ ] Filename includes timestamp
- [ ] Export respects current filters
- [ ] Button shows loading state during export

#### 7.5.8 Empty State
- [ ] Clipboard icon displayed
- [ ] "No Audit Logs" heading
- [ ] Message differs based on filters applied

### 7.6 Organizations Page (`/organizations`)

#### 7.6.1 Page Layout
- [ ] Page title "Organizations" displayed
- [ ] Subtitle about managing organizations displayed
- [ ] "Create Organization" button in header
- [ ] Two-column layout (list + detail)

#### 7.6.2 Info Banner
- [ ] Blue info banner about team management
- [ ] Mentions adding users, assigning roles, permissions

#### 7.6.3 Organization List (Left Column)
- [ ] "Your Organizations" header
- [ ] List of organization cards
- [ ] Each card shows name and member count
- [ ] Chevron icon for selection
- [ ] Selected org highlighted with indigo background
- [ ] Loading spinner while fetching

#### 7.6.4 Empty Organization List
- [ ] Building icon displayed
- [ ] "No organizations yet" message
- [ ] "Create one to get started" helper text

#### 7.6.5 Organization Detail (Right Column)
- [ ] Header shows org name and description
- [ ] Tier badge (purple, e.g., "enterprise")
- [ ] Member count displayed
- [ ] Tab navigation: Members, Roles

#### 7.6.6 Members Tab
- [ ] "Team Members" heading
- [ ] "Add Member" button
- [ ] Table: Member, Role, Joined, Actions
- [ ] Member shows avatar (initial), email, active status
- [ ] Role dropdown for changing roles
- [ ] Joined date formatted
- [ ] Remove button (trash icon)

#### 7.6.7 Add Member Modal
- [ ] Modal opens on "Add Member" click
- [ ] Email field required
- [ ] Role dropdown with all org roles
- [ ] Cancel button closes modal
- [ ] "Add Member" submits form
- [ ] Error displayed for existing member

#### 7.6.8 Remove Member Confirmation
- [ ] Click trash shows inline "Remove?" confirmation
- [ ] Yes removes member
- [ ] No cancels removal
- [ ] Cannot remove org owner

#### 7.6.9 Roles Tab
- [ ] "Roles & Permissions" heading
- [ ] List of role cards
- [ ] Each card shows display name and system badge
- [ ] Role name shown in monospace
- [ ] Description displayed
- [ ] Permissions shown as tags

#### 7.6.10 System Roles Display
- [ ] Owner role shows all permissions
- [ ] Admin role shows permissions list
- [ ] Developer role shows permissions
- [ ] Auditor role shows permissions
- [ ] Guest role shows limited permissions
- [ ] "System" badge on system roles

#### 7.6.11 Create Organization Modal
- [ ] Modal opens on "Create Organization" click
- [ ] Name field required
- [ ] Description field optional
- [ ] Cancel button closes modal
- [ ] "Create" button submits
- [ ] New org appears in list

#### 7.6.12 Select Organization Placeholder
- [ ] When no org selected, placeholder shown
- [ ] Users icon displayed
- [ ] "Select an Organization" heading
- [ ] Helper text about choosing from list

### 7.7 Error States

#### 7.7.1 API Error Display
- [ ] Red error banner on API failure
- [ ] Error icon (exclamation)
- [ ] "Failed to load [resource]" heading
- [ ] Error message from API displayed

#### 7.7.2 Loading States
- [ ] Spinner shown while loading
- [ ] "Loading [resource]..." text
- [ ] Spinner centered in content area

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

### December 23, 2025 - API Endpoint Testing

**Environment**: Minikube local cluster via Traefik (http://127.0.0.1:3000)
**API Service Version**: 0.5.0
**Tester**: Automated via curl

#### Endpoints Tested

| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/api/v1/organizations` | GET | ✅ Pass | Returns empty list for user with no orgs |
| `/api/v1/organizations` | POST | ✅ Pass | Tier-gated (enterprise required) |
| `/api/v1/api-keys/scopes` | GET | ✅ Pass | Returns 10 available scopes |
| `/api/v1/api-keys` | GET | ✅ Pass | Returns user's API keys |
| `/api/v1/api-keys` | POST | ✅ Pass | Tier-gated (pro required) |
| `/api/v1/audit-logs/actions` | GET | ✅ Pass | Returns all action categories |
| `/api/v1/audit-logs` | GET | ✅ Pass | Tier-gated (enterprise required) |
| `/api/v1/audit-logs/summary` | GET | ✅ Pass | Tier-gated (enterprise required) |
| `/api/v1/webhooks` | GET | ✅ Pass | Returns user's webhooks |

#### Database Schema Updates Applied

| Table | Columns Added |
|-------|---------------|
| `api_keys` | `rate_limit_per_minute`, `rate_limit_per_hour`, `revoked_at` |
| `organizations` | `stripe_subscription_id`, `sso_enabled`, `sso_provider`, `sso_config`, `sso_domain` |
| `organization_members` | `is_active` |

#### Tier Gating Verification

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| View API Keys | ✅ | ✅ | ✅ |
| Create API Keys | ❌ | ✅ | ✅ |
| View Organizations | ✅ | ✅ | ✅ |
| Create Organizations | ❌ | ❌ | ✅ |
| View Audit Logs | ❌ | ❌ | ✅ |
| Export Audit Logs | ❌ | ❌ | ✅ |

#### API Key Scopes Available
```
contracts:read, contracts:write, scans:read, scans:create,
vulnerabilities:read, vulnerabilities:write, patterns:read,
analytics:read, webhooks:read, webhooks:write
```

#### Audit Log Action Categories
- `auth`: login, logout, password_change, mfa_enable/disable, api_key operations
- `contracts`: create, update, delete, upload
- `scans`: create, complete, fail, delete
- `vulnerabilities`: update, acknowledge, dismiss, reopen
- `organizations`: org/member/role CRUD operations
- `webhooks`: create, update, delete, test
- `admin`: settings, billing, sso, export

---

## 8. Tier Upgrade and Quota Management

### 8.1 Tier Upgrade Flow

#### Manual Tier Upgrade (Admin/DB)
- [ ] Upgrade user tier from `free` to `pro` in `users` table
- [ ] Verify `user_quotas` table is automatically updated
- [ ] Quota limits should match new tier
- [ ] `webhooks_enabled` should be `true` for pro+
- [ ] `api_access_enabled` should be `true` for pro+
- [ ] `scans_used_this_month` should reset to 0
- [ ] User session reflects new tier immediately (or after re-login)

#### Upgrade from Free to Pro
- [ ] `monthly_scan_limit` increases from 10 to 100
- [ ] `max_files_per_scan` increases from 25 to 100
- [ ] `scan_priority` increases from 25 to 50
- [ ] `webhooks_enabled` changes from `false` to `true`
- [ ] `api_access_enabled` changes from `false` to `true`
- [ ] `result_retention_days` increases from 30 to 90

#### Upgrade from Pro to Enterprise
- [ ] `monthly_scan_limit` increases to 10000 (or unlimited)
- [ ] `max_files_per_scan` increases to 500
- [ ] `scan_priority` increases to 100
- [ ] `result_retention_days` increases to 365

### 8.2 Automatic Quota Sync

**CRITICAL BUG FOUND (December 23, 2025):**
When upgrading user tier in `users` table, the `user_quotas` table was NOT automatically synced.

#### Expected Behavior (To Be Implemented)
- [ ] Tier change in `users` table triggers quota update
- [ ] Database trigger or application service handles sync
- [ ] Quota reset on tier upgrade (fresh start with new limits)
- [ ] Existing scans are preserved (only limits change)

#### Required SQL for Manual Sync
```sql
-- Sync quota to enterprise tier
UPDATE user_quotas
SET
  tier = 'enterprise',
  monthly_scan_limit = 10000,
  monthly_scans_used = 0,
  max_files_per_scan = 500,
  scan_priority = 100,
  webhooks_enabled = true,
  api_access_enabled = true,
  result_retention_days = 365,
  updated_at = NOW()
WHERE user_id = '<user_uuid>';
```

### 8.3 Tier Downgrade Handling
- [ ] Downgrade preserves existing data
- [ ] New limits apply to future operations
- [ ] Warning shown if over new limits
- [ ] Existing API keys remain active (but creation blocked)
- [ ] Existing webhooks remain active (but creation blocked)

### 8.4 Payment Integration (Stripe)
- [ ] Successful payment triggers tier upgrade
- [ ] `stripe_customer_id` set on user
- [ ] `stripe_subscription_id` set on user
- [ ] Subscription cancellation triggers downgrade
- [ ] Grace period before feature access removed

### 8.5 Frontend Tier Gating
- [ ] `TierGate` component blocks access for insufficient tier
- [ ] Upgrade prompt shown with link to pricing
- [ ] ADMIN section in sidebar respects tier
- [ ] API Keys visible to pro+ only
- [ ] Webhooks visible to pro+ only
- [ ] Audit Logs visible to enterprise only
- [ ] Organizations visible to enterprise only

### 8.6 Tier-Specific Limits Table

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| Monthly Scan Limit | 10 | 100 | 10,000 |
| Max Files Per Scan | 25 | 100 | 500 |
| Scan Priority | 25 | 50 | 100 |
| Webhooks | ❌ | ✅ | ✅ |
| API Access | ❌ | ✅ | ✅ |
| Result Retention | 30 days | 90 days | 365 days |
| Organizations | ❌ | ❌ | ✅ |
| Audit Logs | ❌ | ❌ | ✅ |
| Custom Roles | ❌ | ❌ | ✅ |
| SSO Integration | ❌ | ❌ | ✅ |

### 8.7 Quota Reset Timing
- [ ] Monthly reset occurs on 1st of month (UTC)
- [ ] `quota_reset_at` field tracks next reset date
- [ ] Reset sets `monthly_scans_used` to 0
- [ ] Reset does not affect tier or limits
- [ ] Manual reset available for admin

---

## Test Environment Setup

### Creating Test Users for Each Tier

```sql
-- Create free tier test user
INSERT INTO users (email, hashed_password, tier)
VALUES ('test-free@example.com', '<hash>', 'free');

-- Create pro tier test user
INSERT INTO users (email, hashed_password, tier)
VALUES ('test-pro@example.com', '<hash>', 'pro');

-- Create enterprise tier test user
INSERT INTO users (email, hashed_password, tier)
VALUES ('test-enterprise@example.com', '<hash>', 'enterprise');

-- Remember to also create user_quotas entries!
```

### Verifying Quota Configuration

```sql
SELECT
  u.email,
  u.tier as user_tier,
  q.tier as quota_tier,
  q.monthly_scan_limit,
  q.monthly_scans_used,
  q.webhooks_enabled,
  q.api_access_enabled
FROM users u
JOIN user_quotas q ON u.id = q.user_id
WHERE u.email LIKE 'test-%@example.com';
```

---

## 9. Known Issues and Fixes (December 2025)

### 9.1 IngressRoute Routing Fix (v0.13.5)

**Issue:** Dashboard pages like `/api-keys`, `/audit-logs`, `/webhooks` returned 404 errors.

**Root Cause:** The API service IngressRoute used `PathPrefix('/api')` which incorrectly matched dashboard routes starting with `/api-*`.

**Fix Applied:**
- Changed API IngressRoute from `PathPrefix('/api')` to `PathPrefix('/api/v1')`
- Changed Dashboard IngressRoute from `!PathPrefix('/api')` to `!PathPrefix('/api/v1')`

**Files Modified:**
- `blocksecops-api-service/k8s/overlays/local/api-service/ingressroute.yaml`
- `blocksecops-dashboard/k8s/overlays/local/ingressroute.yaml`
- `docs/standards/port-forwarding.md` (documentation updated)

### 9.2 TierGate Loading Flash Fix (v0.13.4)

**Issue:** Enterprise users briefly saw "Upgrade to Pro" prompt during page load.

**Root Cause:** `TierGate` component defaulted to `tier: 'free'` while enhanced user profile was loading.

**Fix Applied:**
- Added `isEnhancedProfileLoaded` state to `AuthContext`
- `TierGate` now shows loading spinner until enhanced profile loaded
- Prevents premature tier evaluation

**Files Modified:**
- `blocksecops-dashboard/src/contexts/AuthContext.tsx`
- `blocksecops-dashboard/src/components/common/TierGate.tsx`

### 9.3 API Key Creation NaN Fix (v0.13.5)

**Issue:** API key creation failed with 422 when "Never expires" selected.

**Root Cause:** Form used `valueAsNumber: true` which converted empty string to `NaN`, then sent to API.

**Fix Applied:**
- Changed from `!== undefined` check to `Number.isFinite()` check
- Ensures only valid numbers are included in API request

**Files Modified:**
- `blocksecops-dashboard/src/components/api-keys/CreateApiKeyModal.tsx`

### 9.4 Database key_prefix Column Size Fix

**Issue:** API key creation failed with 500 Internal Server Error.

**Root Cause:** `api_keys.key_prefix` column was `VARCHAR(10)` but generated prefixes are 12 characters (`bso_XXXX_XXX` format).

**Fix Applied:**
```sql
ALTER TABLE api_keys ALTER COLUMN key_prefix TYPE VARCHAR(20);
```

**Documentation Updated:**
- `docs/database/SCHEMA.md`
- `docs/database/MANUAL-FIXES.md`
