# Dashboard & API Service Fixes

## Version Changes - February 5, 2026

**Date:** 2026-02-06
**Components:** blocksecops-api-service (0.26.1), blocksecops-dashboard (0.39.1)
**Type:** Feature + Enhancement + Removal
**Priority:** Medium
**Status:** Complete

---

## Summary

5 issues addressed across dashboard and API service:
1. OAuth error messages now pass through descriptive details instead of generic text
2. CI/CD tab expanded from Jenkins-only to 4 providers (GitHub Actions, GitLab CI, BitBucket Pipelines, Jenkins)
3. Service Accounts tab hidden for non-admin users (was showing "Admin Access Required" message)
4. Standalone Notifications page removed (duplicate of ChatOps tab)
5. New Support Tickets page with list, detail view, and live JIRA ticket tracking

---

## Issue 1: OAuth Error Message Passthrough

### Changes
- **Backend:** `integrations.py` — Changed `detail="Failed to initiate OAuth connection"` to `detail=str(e)` in `create_integration` and `reconnect_integration`
- **Frontend:** `SourceControlTab.tsx`, `IssueTrackingTab.tsx` — Extract `err?.response?.data?.detail` and display in error toast
- **Config:** `.env.example` — Added OAuth env vars section with provider registration URLs

### Impact
Users now see specific error messages when OAuth fails (e.g., "GitHub OAuth not configured: missing GITHUB_CLIENT_ID") instead of generic "Failed to initiate OAuth connection".

---

## Issue 2: CI/CD Tab Expansion

### Changes
- **Frontend:** `CICDTab.tsx` — Full rewrite adding GitHub Actions, GitLab CI, BitBucket Pipelines alongside Jenkins
- Shared providers reuse Source Control OAuth connections
- Added tabbed pipeline configuration snippets for all 4 providers

### Impact
CI/CD tab now shows all supported providers. GitHub/GitLab/BitBucket redirect to Source Control tab if not yet connected.

---

## Issue 3: Service Accounts Tab Visibility

### Changes
- **Frontend:** `IntegrationsHub.tsx` — Added `useOrganization` hook to check `current_user_role`, filters out `service-accounts` tab for non-admin/non-owner users

### Impact
Non-admin users no longer see the Service Accounts tab at all (previously saw the tab but got an access denied message inside).

---

## Issue 4: Notifications Page Removal

### Changes
- **Frontend:** `App.tsx` — Removed `NotificationChannels` import and route
- **Frontend:** `Sidebar.tsx` — Removed "Notifications" nav item from ADMIN section

### Impact
`/notification-channels` route no longer exists. Notification management is exclusively in Integrations Hub > ChatOps tab.

---

## Issue 5: Support Tickets Page

### Backend Changes
| File | Change |
|------|--------|
| `schemas/support_tickets.py` | 5 new Pydantic schemas (list, detail, JIRA) |
| `jira_support_service.py` | `get_issue_details()` + `_adf_to_text()` methods |
| `endpoints/support_tickets.py` | `GET /support-tickets` (list) + `GET /support-tickets/{id}` (detail) |

### Frontend Changes
| File | Change |
|------|--------|
| `supportTickets.ts` | New types + API methods |
| `useSupportTickets.ts` | React Query hooks for list/detail |
| `SupportTickets.tsx` | Full page with stats, filters, table, JIRA detail |
| `App.tsx` | Route at `/support` |
| `Sidebar.tsx` | "Support Tickets" nav item in ADMIN section |

### New API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/support-tickets` | List user's tickets (paginated, filterable by status) |
| `GET` | `/support-tickets/{ticket_id}` | Get ticket detail with live JIRA data |

### JIRA Integration Configuration
JIRA credentials stored in Vault at `secret/local/api-service/jira` and exposed via ExternalSecret:

| Env Var | Source |
|---------|--------|
| `SUPPORT_JIRA_ENABLED` | Deployment patch (literal `"true"`) |
| `SUPPORT_JIRA_BASE_URL` | Vault → ExternalSecret → Secret |
| `SUPPORT_JIRA_API_EMAIL` | Vault → ExternalSecret → Secret |
| `SUPPORT_JIRA_API_TOKEN` | Vault → ExternalSecret → Secret |
| `SUPPORT_JIRA_PROJECT_KEY` | Vault → ExternalSecret → Secret |

### Impact
Users can now view their support ticket history, track status, and see live JIRA updates (assignee, comments, status) directly in the dashboard.

---

## Files Modified

### Backend (12 files)
- `src/presentation/api/v1/endpoints/integrations.py`
- `src/presentation/schemas/support_tickets.py`
- `src/application/services/jira_support_service.py`
- `src/presentation/api/v1/endpoints/support_tickets.py`
- `.env.example`
- `tests/unit/test_issue_fixes.py`
- `pyproject.toml` (version bump 0.26.0 → 0.26.1)
- `k8s/overlays/local/api-service/kustomization.yaml` (newTag 0.26.1)
- `k8s/overlays/local/api-service/deployment-patch.yaml` (JIRA env vars)
- `k8s/overlays/local/api-service/externalsecret.yaml` (JIRA Vault refs)

### Frontend (11 files)
- `src/components/integrations/hub/SourceControlTab.tsx`
- `src/components/integrations/hub/IssueTrackingTab.tsx`
- `src/components/integrations/hub/CICDTab.tsx`
- `src/pages/IntegrationsHub.tsx`
- `src/App.tsx`
- `src/components/navigation/Sidebar.tsx`
- `src/lib/api/supportTickets.ts`
- `src/hooks/useSupportTickets.ts` (new)
- `src/pages/SupportTickets.tsx` (new)
- `package.json` (version bump 0.39.0 → 0.39.1)
- `k8s/overlays/local/kustomization.yaml` (newTag 0.39.1, app version label)

---

## Related Documentation

- [Task Documentation](../../TaskDocs-Apogee/DOCUMENTATION-UPDATE-2026-02-05-DASHBOARD-API-FIXES.md)
- [Support Tickets Feature Test](../feature-tests/53-support-tickets.md)
- [Integrations Hub Feature Test](../feature-tests/45-integrations-hub.md)

---

**Maintained By:** Apogee Team
**Status:** Complete
