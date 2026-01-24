# Feature Test: Unified Integrations Hub

**Feature ID:** 45
**Feature Name:** Unified Integrations Hub
**Version:** 1.0.0
**Last Updated:** January 23, 2026
**Status:** Implemented

---

## Overview

The Unified Integrations Hub consolidates all platform integrations into a single organized page with tabbed navigation. It includes:
- **Source Control**: GitHub, GitLab, Bitbucket
- **CI/CD**: Jenkins
- **Issue Tracking**: JIRA
- **ChatOps**: Slack, Discord, Teams (migrated from NotificationChannels)
- **IDE**: VS Code, IntelliJ token management
- **Service Accounts**: Admin-only, Growth tier+ accounts for CI/CD automation

### URL Structure
- Main page: `/integrations`
- Deep-linking: `/integrations?tab=chatops`, `/integrations?tab=service-accounts`

---

## Test Sections

### 1. Hub Navigation

**Goal:** Verify tabbed navigation and URL deep-linking

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/integrations` | Page loads with Overview tab active |
| 2 | Click "Source Control" tab | Tab content changes, URL updates to `?tab=source-control` |
| 3 | Click "CI/CD" tab | Tab content changes, URL updates to `?tab=cicd` |
| 4 | Click "Issue Tracking" tab | Tab content changes, URL updates to `?tab=issue-tracking` |
| 5 | Click "ChatOps" tab | Tab content changes, URL updates to `?tab=chatops` |
| 6 | Click "IDE" tab | Tab content changes, URL updates to `?tab=ide` |
| 7 | Click "Service Accounts" tab | Tab content changes, URL updates to `?tab=service-accounts` |
| 8 | Directly navigate to `/integrations?tab=ide` | Page loads with IDE tab active |
| 9 | Refresh page | Tab state preserved from URL |

---

### 2. Overview Tab

**Goal:** Verify overview dashboard displays all integrations

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View Overview tab | Shows grouped integrations by category |
| 2 | Check Source Control section | Shows GitHub, GitLab, Bitbucket status |
| 3 | Check CI/CD section | Shows Jenkins status |
| 4 | Check ChatOps section | Shows Slack, Discord, Teams channel counts |
| 5 | Check IDE section | Shows active token count |
| 6 | Check Service Accounts section | Shows active service account count |
| 7 | Click category link | Navigates to appropriate tab |
| 8 | Verify quick stats | Shows "X connected", "Y available" counts |

---

### 3. Source Control Tab

**Goal:** Verify VCS integration management (existing functionality)

**Prerequisites:**
- Team+ tier account

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View Source Control tab | Shows GitHub, GitLab, Bitbucket cards |
| 2 | Click "Connect" on GitHub | OAuth flow initiates |
| 3 | Authorize on GitHub | Returns with `?success=true&provider=github` |
| 4 | Verify integration | Shows "Connected" status |
| 5 | Click disconnect | Confirmation modal appears |
| 6 | Confirm disconnect | Integration removed |

---

### 4. CI/CD Tab

**Goal:** Verify Jenkins integration

**Prerequisites:**
- Team+ tier account
- Jenkins OAuth configured in backend

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View CI/CD tab | Shows Jenkins integration card |
| 2 | Click "Connect" on Jenkins | OAuth flow initiates |
| 3 | Authorize on Jenkins | Returns with success |
| 4 | Verify integration status | Shows "Connected" with pipeline info |
| 5 | View connected pipelines | Lists available Jenkins pipelines |

---

### 5. Issue Tracking Tab

**Goal:** Verify JIRA integration (existing functionality)

**Prerequisites:**
- Enterprise tier account
- Atlassian OAuth configured

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View Issue Tracking tab | Shows JIRA card |
| 2 | Team tier user views tab | Shows "Enterprise" badge, upgrade button |
| 3 | Enterprise user clicks Connect | OAuth flow to auth.atlassian.com |
| 4 | Authorize application | Returns with success |
| 5 | Configure project mapping | Can map BlockSecOps project to JIRA project |

---

### 6. ChatOps Tab

**Goal:** Verify notification channels management (migrated from /notification-channels)

**Prerequisites:**
- Team+ tier account

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View ChatOps tab | Shows Slack, Discord, Teams sections |
| 2 | Click "Add Slack Channel" | Create modal opens |
| 3 | Enter webhook URL | Validates URL format |
| 4 | Save channel | Channel appears in list |
| 5 | Click "Test" on channel | Test notification sent |
| 6 | Check toast notification | Shows "Test notification sent!" |
| 7 | Edit channel | Edit modal opens with current values |
| 8 | Delete channel | Confirmation modal, then removed |

**Backwards Compatibility:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/notification-channels` | Page loads (not broken) |
| 2 | Check for redirect banner | Shows "Moved to Integrations Hub" with link |
| 3 | Click banner link | Navigates to `/integrations?tab=chatops` |

---

### 7. IDE Tab

**Goal:** Verify IDE token management

**Prerequisites:**
- Team+ tier account

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View IDE tab | Shows token management interface |
| 2 | Click "Generate VS Code Token" | Create modal opens |
| 3 | Enter token name | "My Laptop - VS Code" |
| 4 | Select permissions | Read scans, Create scans |
| 5 | Click Generate | Token displayed with warning |
| 6 | Verify token display | Full token shown ONCE with copy button |
| 7 | Click Copy | Token copied to clipboard |
| 8 | Close modal | Token no longer visible |
| 9 | View token in list | Shows only prefix `bso_ide_xxxx...` |
| 10 | Click "Setup Instructions" | Shows VS Code extension setup guide |
| 11 | Click Revoke on token | Confirmation modal appears |
| 12 | Confirm revoke | Token removed from list |

**IDE Token Permissions:**

| Permission | Description |
|------------|-------------|
| `scans:read` | View scan results |
| `scans:create` | Create new scans |
| `contracts:read` | View contracts |
| `vulnerabilities:read` | View vulnerabilities |

---

### 8. Service Accounts Tab - Tier Gating

**Goal:** Verify tier-based access control

**Test Steps (Developer/Team Tier):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as Developer tier user | Login successful |
| 2 | Navigate to `/integrations?tab=service-accounts` | Tab visible but greyed out |
| 3 | View tab content | Shows TierGate overlay with upsell |
| 4 | Click "Upgrade" in overlay | Navigates to `/pricing` |

**Test Steps (Growth+ Tier, Non-Admin):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as Growth tier non-admin | Login successful |
| 2 | Navigate to `/integrations?tab=service-accounts` | Tab content loads |
| 3 | View tab content | Shows "Admin Access Required" message |
| 4 | No create/manage buttons visible | Correct - non-admin cannot manage |

**Test Steps (Growth+ Tier, Admin):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as Growth tier admin | Login successful |
| 2 | Navigate to `/integrations?tab=service-accounts` | Tab content loads |
| 3 | View tab content | Shows full Service Accounts management UI |
| 4 | See "Create Service Account" button | Button visible and enabled |

---

### 9. Service Accounts Tab - CRUD Operations

**Goal:** Verify service account management for admins

**Prerequisites:**
- Growth+ tier admin account

**Test Steps (Create):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click "Create Service Account" | Create modal opens |
| 2 | Enter name: "CI Pipeline Bot" | Field accepts input |
| 3 | Enter description: "GitHub Actions runner" | Field accepts input |
| 4 | Select scopes: `scans:create`, `contracts:read` | Checkboxes selected |
| 5 | Set expiration (optional) | Date picker works |
| 6 | Click Create | Service account created |
| 7 | Verify key display | Full key shown: `bso_sa_xxxx...` |
| 8 | Verify warning | "This key will only be shown once" |
| 9 | Copy key | Key copied to clipboard |
| 10 | Close modal | Key no longer accessible |

**Test Steps (List):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View service accounts table | Lists all org service accounts |
| 2 | Check columns | Name, Key Prefix, Scopes, Last Used, Status |
| 3 | Key shows masked | Only shows `bso_sa_xxxx...` |
| 4 | Last used shows time | "Never" or relative time |

**Test Steps (Update):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click Edit on service account | Edit modal opens |
| 2 | Change name | Name updated |
| 3 | Add scope | Scope added |
| 4 | Save changes | Modal closes, list updates |

**Test Steps (Rotate Key):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click Rotate Key | Confirmation modal appears |
| 2 | Warning shown | "Old key will be immediately invalidated" |
| 3 | Confirm rotation | New key generated and displayed |
| 4 | Verify new key | Different from previous |
| 5 | Test old key | Returns 401 Unauthorized |

**Test Steps (Revoke):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click Revoke | Confirmation modal appears |
| 2 | Confirm revocation | Service account disabled |
| 3 | Check status | Shows "Revoked" badge |
| 4 | Test key | Returns 401 Unauthorized |

---

### 10. Service Accounts - API Authentication

**Goal:** Verify service accounts can authenticate to API

**Prerequisites:**
- Active service account with scopes

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call API without auth | Returns 401 |
| 2 | Call API with header: `X-Service-Account-Key: bso_sa_xxx` | Returns 200 (if scope allows) |
| 3 | Call endpoint outside scopes | Returns 403 Forbidden |
| 4 | Check last_used_at | Updated after API call |
| 5 | Check total_requests | Incremented after API call |
| 6 | Use expired key | Returns 401 "Key expired" |
| 7 | Use revoked key | Returns 401 "Invalid key" |

**API Request Example:**

```bash
curl -X GET https://app.blocksecops.local/api/v1/contracts \
  -H "X-Service-Account-Key: bso_sa_xxxxxxxxxxxxxxxx"
```

---

### 11. Service Accounts - Rate Limiting

**Goal:** Verify service account rate limits

**Default Rate Limits:**

| Tier | Per Minute | Per Hour |
|------|------------|----------|
| Growth | 120 | 2000 |
| Enterprise | 300 | 10000 |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Make 121 requests in 1 minute (Growth) | 121st request returns 429 |
| 2 | Wait 1 minute | Requests allowed again |
| 3 | Verify rate limit headers | `X-RateLimit-Remaining`, `X-RateLimit-Reset` |

---

### 12. Dark Mode Support

**Goal:** Verify all tabs render correctly in dark mode

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Toggle dark mode | Theme switches |
| 2 | Check Overview tab | Dark backgrounds, proper contrast |
| 3 | Check all integration cards | Dark variants of colors |
| 4 | Check modals | Dark backgrounds |
| 5 | Check tables | Proper row alternation |
| 6 | Check badges | Dark mode color variants |

---

### 13. Error Handling

**Goal:** Verify error states are handled gracefully

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | API returns 500 | Shows "Failed to load" with retry |
| 2 | Network disconnected | Shows offline indicator |
| 3 | Invalid tab in URL | Defaults to Overview tab |
| 4 | Service account limit reached | Shows "Maximum 20 service accounts" |

---

## API Endpoints

### Service Accounts

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/organizations/{orgId}/service-accounts` | List service accounts |
| POST | `/organizations/{orgId}/service-accounts` | Create (returns key once) |
| GET | `/organizations/{orgId}/service-accounts/{id}` | Get details |
| PATCH | `/organizations/{orgId}/service-accounts/{id}` | Update |
| POST | `/organizations/{orgId}/service-accounts/{id}/rotate` | Rotate key |
| DELETE | `/organizations/{orgId}/service-accounts/{id}` | Revoke |

### IDE Integrations

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/ide-integrations` | List user's IDE tokens |
| POST | `/ide-integrations` | Create token (returns once) |
| DELETE | `/ide-integrations/{id}` | Revoke token |
| GET | `/ide-integrations/setup/{ide_type}` | Get setup instructions |

---

## Database Tables

### service_accounts

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| organization_id | UUID | FK to organizations |
| name | String(255) | Display name |
| description | String(500) | Optional description |
| created_by | UUID | Admin who created |
| key_prefix | String(12) | First 12 chars for display |
| key_hash | String(64) | SHA-256 hash |
| scopes | JSONB | List of permissions |
| rate_limit_per_minute | Integer | Default 120 |
| rate_limit_per_hour | Integer | Default 2000 |
| last_used_at | DateTime | Last API call |
| total_requests | Integer | Total API calls |
| expires_at | DateTime | Optional expiration |
| is_active | Boolean | Active status |
| revoked_at | DateTime | When revoked |
| revoked_by | UUID | Admin who revoked |
| created_at | DateTime | Creation time |
| updated_at | DateTime | Last update |

### ide_tokens

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | UUID | FK to users |
| organization_id | UUID | FK to organizations (optional) |
| name | String | Token name |
| ide_type | String | 'vscode' or 'intellij' |
| token_prefix | String | First 12 chars |
| token_hash | String | SHA-256 hash |
| permissions | JSONB | List of permissions |
| last_used_at | DateTime | Last use |
| is_active | Boolean | Active status |
| created_at | DateTime | Creation time |

---

## Files Modified

| File | Changes |
|------|---------|
| `src/pages/IntegrationsHub.tsx` | New - main tabbed page |
| `src/components/integrations/hub/OverviewTab.tsx` | New - overview dashboard |
| `src/components/integrations/hub/SourceControlTab.tsx` | New - extracted from Integrations.tsx |
| `src/components/integrations/hub/CICDTab.tsx` | New - Jenkins integration |
| `src/components/integrations/hub/IssueTrackingTab.tsx` | New - JIRA integration |
| `src/components/integrations/hub/ChatOpsTab.tsx` | New - notification channels |
| `src/components/integrations/hub/IDETab.tsx` | New - IDE token management |
| `src/components/integrations/hub/ServiceAccountsTab.tsx` | New - service accounts |
| `src/lib/api/serviceAccounts.ts` | New - API client |
| `src/lib/api/ideIntegrations.ts` | New - API client |
| `src/hooks/useServiceAccounts.ts` | New - React Query hooks |
| `src/hooks/useIDEIntegrations.ts` | New - React Query hooks |
| `src/components/integrations/IntegrationTypeIcon.tsx` | Added Jenkins, VS Code, IntelliJ icons |
| `src/App.tsx` | Updated routing |

---

## Known Limitations

1. **Jenkins OAuth**: Requires self-hosted Jenkins with OAuth plugin configured
2. **Service Account Limit**: Maximum 20 active service accounts per organization
3. **IDE Token Limit**: Maximum 10 active tokens per user
4. **Key Display**: Keys are shown only once on creation/rotation

---

## Related Documentation

- [Platform Integrations (44)](./44-platform-integrations.md) - VCS & Issue Tracking
- [IDE Integration (42)](./42-ide-integration.md) - IDE extensions
- [Notification Channels (34)](./34-notification-channels.md) - ChatOps background
- [Enterprise Features (14)](./14-enterprise-features.md) - Tier requirements
- [CI/CD Integration (36)](./36-cicd-integration.md) - Pipeline integration
