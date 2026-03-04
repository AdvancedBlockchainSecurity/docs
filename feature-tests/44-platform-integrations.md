# Feature Test: Platform Integrations

**Feature ID:** 44
**Feature Name:** Platform Integrations (VCS & Issue Tracking)
**Version:** 1.0.0
**Last Updated:** February 5, 2026
**Status:** Implemented

---

## Overview

Platform integrations enable connecting Apogee to external version control systems (VCS) and issue tracking platforms. This allows:
- Importing smart contracts directly from repositories
- Auto-scanning on push/PR events
- Syncing vulnerabilities to issue tracking systems

### Supported Integrations

| Provider | Type | Tier Required | Features |
|----------|------|---------------|----------|
| GitHub | VCS | Starter+ | Repository import, auto-scan on push/PR |
| GitLab | VCS | Starter+ | Repository import, auto-scan on push/PR |
| Bitbucket | VCS | Starter+ | Repository import, auto-scan on push/PR |
| Jira | Issue Tracking | Enterprise | Vulnerability-to-issue sync, project mapping |

**Note:** Jenkins integration is NOT implemented. CI/CD scanning is available via the CLI tool and webhooks instead.

---

## Test Sections

### 1. Integration Page Access

**Goal:** Verify tier-gated access to integrations page

**Prerequisites:**
- User accounts at different tiers (Developer, Team, Enterprise)

**Tier Enforcement (Two Levels):**
1. **Page-level gate**: Entire page requires Team+ tier (Developer blocked)
2. **Integration-level gate**: Each integration card checks user tier via `useTierAccess` hook

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as Developer tier user | Login successful |
| 2 | Navigate to `/integrations` | TierGate blocks access, shows upgrade prompt |
| 3 | Login as Starter tier user | Login successful |
| 4 | Navigate to `/integrations` | Page loads, all integrations show "Connect" button (GitHub, GitLab, Bitbucket, Jira, Jenkins) |
| 5 | Check Jira integration card | Shows "Connect" button (available to all paying tiers) |
| 6 | Login as Enterprise tier user | Login successful |
| 7 | Navigate to `/integrations` | All integrations show "Connect" button |

---

### 2. GitHub Integration OAuth Flow

**Goal:** Verify GitHub OAuth connection flow

**Prerequisites:**
- Starter+ tier account
- GitHub OAuth app configured in backend

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Integrations page | Page loads with GitHub card |
| 2 | Click "Connect" on GitHub card | Button shows "Connecting..." state |
| 3 | Observe redirect | Redirects to github.com OAuth consent page |
| 4 | Authorize application | Redirects back to `/integrations?success=true&provider=github` |
| 5 | Observe integration list | GitHub integration appears with "Connected" status |
| 6 | Check toast notification | Shows "Successfully connected GitHub!" |

**OAuth URL Validation:**
- Only HTTPS URLs allowed
- Only allowed hosts: github.com, gitlab.com, bitbucket.org, auth.atlassian.com

---

### 3. GitLab Integration OAuth Flow

**Goal:** Verify GitLab OAuth connection flow

**Prerequisites:**
- Starter+ tier account
- GitLab OAuth app configured in backend

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click "Connect" on GitLab card | Button shows "Connecting..." state |
| 2 | Observe redirect | Redirects to gitlab.com OAuth consent page |
| 3 | Authorize application | Redirects back to `/integrations?success=true&provider=gitlab` |
| 4 | Check integration list | GitLab integration appears with "Connected" status |

---

### 4. Bitbucket Integration OAuth Flow

**Goal:** Verify Bitbucket OAuth connection flow

**Prerequisites:**
- Starter+ tier account
- Bitbucket OAuth app configured in backend

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click "Connect" on Bitbucket card | Button shows "Connecting..." state |
| 2 | Observe redirect | Redirects to bitbucket.org OAuth consent page |
| 3 | Authorize application | Redirects back to `/integrations?success=true&provider=bitbucket` |
| 4 | Check integration list | Bitbucket integration appears with "Connected" status |

---

### 5. Jira Integration OAuth Flow

**Goal:** Verify Jira OAuth connection flow (Enterprise only)

**Prerequisites:**
- Enterprise tier account
- Atlassian/Jira OAuth app configured in backend

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click "Connect" on Jira card | Button shows "Connecting..." state |
| 2 | Observe redirect | Redirects to auth.atlassian.com OAuth consent page |
| 3 | Authorize application | Redirects back to `/integrations?success=true&provider=jira` |
| 4 | Check integration list | Jira integration appears with "Connected" status |
| 5 | Verify Jira-specific data | Shows `jira_cloud_id` and `jira_site_url` in integration details |

---

### 6. OAuth Error Handling

**Goal:** Verify OAuth error states are handled gracefully with descriptive messages

**Test Steps (User Cancellation):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Initiate OAuth flow | Redirects to provider |
| 2 | Cancel/deny authorization | Redirects back to `/integrations?error=access_denied` |
| 3 | Observe error toast | Shows "Failed to connect: access denied" |
| 4 | Check URL cleanup | URL params cleared, shows `/integrations` |

**Test Steps (Missing OAuth Configuration):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click "Connect" on GitHub (no `GITHUB_CLIENT_ID` configured) | Error toast appears |
| 2 | Check error toast title | Shows "Failed to initiate GitHub connection" |
| 3 | Check error toast message | Shows descriptive error from backend (e.g., "GitHub OAuth not configured: missing GITHUB_CLIENT_ID") |
| 4 | Same for GitLab, Bitbucket, JIRA | Each shows provider-specific error detail |

**Test Steps (Reconnection Error):**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click reconnect on expired integration (backend OAuth misconfigured) | Error toast appears |
| 2 | Check error toast message | Shows descriptive error from backend (not generic "Failed to initiate OAuth connection") |

**Note (February 5, 2026):** Backend now returns `detail=str(e)` from `OAuthServiceError` instead of hardcoded generic message. Frontend extracts `err.response.data.detail` and displays it in the toast notification.

---

### 7. Integration Status Display

**Goal:** Verify integration status badges display correctly

**Status Types:**

| Status | Badge Color | Description |
|--------|-------------|-------------|
| `pending` | Yellow | OAuth initiated but not completed |
| `connected` | Green | Active and working |
| `expired` | Orange | Token expired, needs reconnection |
| `error` | Red | Connection error |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View connected integration | Shows green "Connected" badge |
| 2 | Simulate token expiry (backend) | Shows orange "Expired" badge |
| 3 | Check health indicator | Page shows "Needs Attention" when any integration has error/expired |

---

### 8. Integration Reconnection

**Goal:** Verify reconnection flow for expired/errored integrations

**Prerequisites:**
- Integration with expired or error status

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Find integration with expired/error status | Reconnect button (refresh icon) visible |
| 2 | Click reconnect button | Redirects to OAuth provider |
| 3 | Re-authorize | Redirects back with success |
| 4 | Check status | Integration now shows "Connected" |

---

### 9. Integration Deletion

**Goal:** Verify integration disconnection flow

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click delete (trash) button on integration | Confirmation modal opens |
| 2 | Modal shows provider name | "Disconnect Integration" with provider name |
| 3 | Click "Cancel" | Modal closes, integration unchanged |
| 4 | Click delete button again | Modal opens |
| 5 | Click "Disconnect" | Button shows "Disconnecting..." |
| 6 | Wait for completion | Integration removed from list |
| 7 | Check toast | Shows "[Provider] integration disconnected" |

---

### 10. Repository Listing

**Goal:** Verify connected repositories display

**Prerequisites:**
- Connected VCS integration with synced repositories

**API Endpoint:** `GET /organizations/{orgId}/integrations/{integrationId}/repositories`

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Connect a VCS integration | Integration shows in list |
| 2 | View repository count | Shows "X repos" in table cell |
| 3 | View last sync time | Shows relative time "Last sync: X minutes ago" |

---

### 11. Repository Settings

**Goal:** Verify repository scan settings can be configured

**API Endpoint:** `PATCH /organizations/{orgId}/integrations/{integrationId}/repositories/{repoId}`

**Repository Settings:**

| Setting | Type | Description |
|---------|------|-------------|
| `auto_scan_enabled` | boolean | Enable automatic scanning |
| `scan_on_push` | boolean | Scan when commits pushed |
| `scan_on_pr` | boolean | Scan when PR opened |
| `project_id` | string | Link to Apogee project |

---

### 12. Jira Project Mapping

**Goal:** Verify Jira project mapping configuration

**Prerequisites:**
- Connected Jira integration (Starter+ tier)

**API Endpoint:** `POST /organizations/{orgId}/integrations/{integrationId}/jira/mappings`

**Mapping Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `blocksecops_project_id` | string | Apogee project to sync from |
| `jira_project_id` | string | Jira project ID |
| `jira_project_key` | string | Jira project key (e.g., "SEC") |
| `issue_type` | string | Jira issue type (default: "Bug") |
| `auto_create_issues` | boolean | Auto-create issues for new vulns |
| `min_severity_to_sync` | string | Minimum severity (critical/high/medium/low) |

---

### 13. Stats Dashboard

**Goal:** Verify integration stats display correctly

**Stats Cards:**

| Card | Metric | Description |
|------|--------|-------------|
| Connected | Count | Number of active integrations |
| Repositories | Sum | Total synced repositories across all integrations |
| Status | Health | "Healthy" or "Needs Attention" |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View integrations with no connections | Shows 0 connected, 0 repos, Healthy |
| 2 | Connect one integration with 5 repos | Shows 1 connected, 5 repos, Healthy |
| 3 | Simulate error on integration | Shows "Needs Attention" status |

---

### 14. Dark Mode Support

**Goal:** Verify integrations page works in dark mode

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Toggle dark mode | Page switches to dark theme |
| 2 | Check stats cards | Dark background (gray-800), white text |
| 3 | Check integration table | Dark rows, proper contrast |
| 4 | Check status badges | Dark variants of colors |
| 5 | Check delete modal | Dark background, proper contrast |

---

### 15. Security: OAuth URL Validation

**Goal:** Verify OAuth URLs are validated to prevent open redirect attacks

**Allowed OAuth Hosts:**
- `github.com` and subdomains
- `gitlab.com` and subdomains
- `bitbucket.org` and subdomains
- `auth.atlassian.com` and subdomains

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Backend returns valid github.com URL | Redirect proceeds |
| 2 | Backend returns HTTP (not HTTPS) | Redirect blocked, error shown |
| 3 | Backend returns unknown host | Redirect blocked, error shown |

---

## API Endpoints

### Integration Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/organizations/{orgId}/integrations` | List integrations |
| POST | `/organizations/{orgId}/integrations` | Create integration (returns OAuth URL) |
| GET | `/organizations/{orgId}/integrations/{id}` | Get integration |
| PATCH | `/organizations/{orgId}/integrations/{id}` | Update integration |
| DELETE | `/organizations/{orgId}/integrations/{id}` | Delete integration |
| POST | `/organizations/{orgId}/integrations/{id}/reconnect` | Reconnect expired integration |

### Repository Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/organizations/{orgId}/integrations/{id}/repositories` | List repositories |
| POST | `/organizations/{orgId}/integrations/{id}/repositories` | Connect repositories |
| PATCH | `/organizations/{orgId}/integrations/{id}/repositories/{repoId}` | Update repository settings |
| DELETE | `/organizations/{orgId}/integrations/{id}/repositories/{repoId}` | Disconnect repository |
| POST | `/organizations/{orgId}/integrations/{id}/repositories/{repoId}/sync` | Trigger sync |

### Jira Mappings

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/organizations/{orgId}/integrations/{id}/jira/mappings` | List mappings |
| POST | `/organizations/{orgId}/integrations/{id}/jira/mappings` | Create mapping |
| PATCH | `/organizations/{orgId}/integrations/{id}/jira/mappings/{mappingId}` | Update mapping |
| DELETE | `/organizations/{orgId}/integrations/{id}/jira/mappings/{mappingId}` | Delete mapping |

---

## Files Modified

| File | Changes |
|------|---------|
| `src/pages/Integrations.tsx` | New page component |
| `src/lib/api/integrations.ts` | API client methods |
| `src/hooks/useIntegrations.ts` | React Query hooks |
| `src/components/integrations/IntegrationTypeIcon.tsx` | Provider icons |
| `src/App.tsx` | Route `/integrations` |

---

## Known Limitations

1. **No Jenkins Support:** CI/CD integration via webhooks and CLI instead
2. **Repository Browser:** Cannot browse repository contents in UI (planned)
3. **Bulk Operations:** No bulk enable/disable for repositories
4. **Webhook Events:** UI doesn't show incoming webhook history (logs only)

---

## Related Documentation

- [Integrations User Guide](../../blocksecops-docs/platform/integrations/README.md)
- [CI/CD Integration](./36-cicd-integration.md)
- [Webhooks](./34-notification-channels.md)
- [Enterprise Features](./14-enterprise-features.md)
