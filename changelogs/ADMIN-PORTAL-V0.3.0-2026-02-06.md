# Admin Portal Feature Expansion & UX Overhaul

## Version 0.3.0 - New Pages, Export, MFA, Session Tracking - February 6, 2026

**Date:** 2026-02-06
**Component:** blocksecops-admin-portal (0.2.0 -> 0.3.0)
**Type:** Feature + Enhancement + Bug Fix
**Priority:** High
**Status:** Complete

---

## Summary

18 changes across the admin portal covering five themes:
1. **UX fixes** (P1-P4, P7, P12-P13) — Renamed Customer Search to Customers, fixed Stripe pricing display, repositioned search results, removed scan activity from customer search, removed Quick Actions, TLS comment, audit log retention notice
2. **New dashboard features** (P5, P8) — Sign-up metrics cards, RadarChart scan activity with time range dropdown
3. **New pages** (P9, P17) — Vulnerability Data page and Dependencies page with sidebar navigation
4. **Reusable components & export** (P10) — AdminExportButton (CSV/JSON) added to 5 pages
5. **Security hardening** (P6, P11, P14-P16) — Impersonation fix, session activity tracking with inactivity timeout, Change Tier with MFA, Credit Management with MFA, users credit management link

~20 files modified, 3 new files created.

---

## Issues Resolved

- Page title said "Customer Search" instead of "Customers"
- Stripe prices displayed in cents ($79900) instead of dollars ($799.00)
- Search results appeared in a separate section instead of below the search input
- Customer search page included unrelated "Scan Activity (7 Days)" section
- Dashboard Quick Actions section was redundant with sidebar navigation
- Impersonation stored token incorrectly and did not redirect to dashboard
- No session inactivity timeout for admin users
- Tier changes had no MFA verification
- Credit adjustments had no MFA verification
- No data export capability from admin pages
- Vulnerability metrics were buried in the main dashboard
- No visibility into service dependencies
- Audit log retention period not communicated to users

---

## Added

### P5: Sign-Up Metrics Cards

**File:** `src/pages/AdminDashboard.tsx`
- 5 new metric cards: Today, 7 Days, 30 Days, 6 Months, 1 Year
- Each card shows sign-up count for the respective time period
- Fetched from `GET /admin/stats/signups` endpoint

### P8: Scan Activity RadarChart

**File:** `src/pages/AdminDashboard.tsx`
- Replaced static scan table with interactive RadarChart visualization
- Time range dropdown: 7 days, 30 days, 6 months, 1 year
- Chart displays scan distribution by scanner type

### P9: Vulnerability Data Page

**New file:** `src/pages/AdminVulnerabilityData.tsx`
- Dedicated page for platform-wide vulnerability metrics
- Severity breakdown, scanner distribution, trend data
- Route added at `/vulnerability-data`
- Sidebar navigation item with `ShieldExclamationIcon`

### P10: Reusable Export Button

**New file:** `src/components/AdminExportButton.tsx`
- Supports CSV and JSON export formats
- Dropdown toggle for format selection
- Generic component accepting data array and column definitions
- Added to 5 pages:

| Page | Export Data |
|------|-------------|
| `AdminDashboard.tsx` | Platform summary metrics |
| `AdminCustomers.tsx` | Customer list with tier/status |
| `AdminAuditLogs.tsx` | Audit log entries |
| `AdminVulnerabilityData.tsx` | Vulnerability statistics |
| `AdminDependencies.tsx` | Service dependency table |

### P11: Session Activity Tracking

**File:** `src/App.tsx` (or equivalent root component)
- 30-minute inactivity timeout
- Event listeners on `mousemove`, `keydown`, `scroll`
- Timer resets on any user activity
- On timeout: clears session, redirects to login
- Activity state stored in memory (not persisted)

### P13: Audit Log Retention Notice

**File:** `src/pages/AdminAuditLogs.tsx`
- Added banner: "Audit logs are retained for 14 days"
- Displayed above the audit log table

### P14: Change Tier with MFA

**New component within:** `src/pages/AdminCustomers.tsx` (or dedicated modal file)
- `ChangeTierModal` component with tier selection dropdown
- MFA verification input required before API call executes
- Validates MFA token via `POST /admin/auth/verify-mfa`
- On success, calls `PATCH /admin/organizations/{id}/tier`

### P15: Credit Management with MFA

**New component within:** `src/pages/AdminCustomers.tsx` (or dedicated modal file)
- `ManageCreditsModal` with add/remove toggle
- Amount input with validation
- Reason/note text field (required)
- MFA verification required before API call
- Calls `POST /admin/organizations/{id}/credits`

### P16: Users Credit Management Link and Orgs Column

**File:** `src/pages/AdminUsers.tsx`
- Added "Manage Credits" link per user row (navigates to org credit management)
- Added "Organization" column to users table

### P17: Dependencies Page

**New file:** `src/pages/AdminDependencies.tsx`
- Service dependency table showing all platform services
- Columns: service name, version, status, dependencies, last updated
- Route added at `/dependencies`
- Sidebar navigation item with `CircleStackIcon`

---

## Changed

### P1: Rename "Customer Search" to "Customers"

| File | Change |
|------|--------|
| `src/pages/AdminCustomers.tsx` | Page title: "Customer Search" -> "Customers" |
| `src/layouts/AdminLayout.tsx` | Sidebar nav label: "Customer Search" -> "Customers" |

### P2: Fix Pricing Display (Cents to Dollars)

**File:** `src/pages/AdminCustomers.tsx` (or pricing display component)
- Applied `(price / 100).toFixed(2)` conversion to all Stripe price displays
- Example: `$79900` now renders as `$799.00`

### P3: Search Results Positioning

**File:** `src/pages/AdminCustomers.tsx`
- Search results panel positioned directly below search input
- Removed separate results section layout

### P4: Remove Scan Activity from Customer Search

**File:** `src/pages/AdminCustomers.tsx`
- Removed "Scan Activity (7 Days)" section entirely from customer search page

### P6: Fix Impersonation

**File:** `src/pages/AdminCustomers.tsx` (or impersonation handler)
- Token now stored in `sessionStorage` (not `localStorage`)
- After storing token, redirects to dashboard URL
- Session-scoped token automatically clears on browser tab close

### P7: Remove Quick Actions

**File:** `src/pages/AdminDashboard.tsx`
- Removed Quick Actions grid section from dashboard
- Functionality accessible via sidebar navigation

### P12: TLS Comment on IngressRoute

**File:** `k8s/overlays/local/ingressroute.yaml`
- Added comment noting TLS configuration for production deployment

### P18: Version Bump

| File | Change |
|------|--------|
| `package.json` | `"version": "0.2.0"` -> `"version": "0.3.0"` |
| `k8s/overlays/local/kustomization.yaml` | `newTag: "0.2.0"` -> `newTag: "0.3.0"` |

---

## Fixed

- **P1:** Page title now correctly shows "Customers" instead of "Customer Search"
- **P2:** Stripe prices display in dollars ($799.00) instead of raw cents ($79900)
- **P3:** Search results appear directly below search input for better UX flow
- **P6:** Impersonation correctly stores token and redirects to dashboard

---

## Code Changes

### New Files (3 files)

| File | Item | Description |
|------|------|-------------|
| `src/components/AdminExportButton.tsx` | P10 | Reusable CSV/JSON export button component |
| `src/pages/AdminVulnerabilityData.tsx` | P9 | Platform vulnerability data page |
| `src/pages/AdminDependencies.tsx` | P17 | Service dependencies page |

### Files Modified (~20 files)

| File | Item | Change |
|------|------|--------|
| `src/pages/AdminDashboard.tsx` | P5, P7, P8, P10 | Sign-up cards, remove Quick Actions, RadarChart, export button |
| `src/pages/AdminCustomers.tsx` | P1, P2, P3, P4, P6, P10, P14, P15 | Rename, pricing fix, search position, remove scan activity, impersonation fix, export, tier/credit modals |
| `src/pages/AdminAuditLogs.tsx` | P10, P13 | Export button, retention notice |
| `src/pages/AdminUsers.tsx` | P16 | Credit management link, orgs column |
| `src/layouts/AdminLayout.tsx` | P1, P9, P17 | Sidebar: rename Customers, add Vulnerability Data nav, add Dependencies nav |
| `src/App.tsx` | P9, P11, P17 | Routes for new pages, session activity tracking |
| `src/lib/api/admin.ts` | P14, P15 | MFA verification, tier change, credit management API functions |
| `k8s/overlays/local/ingressroute.yaml` | P12 | TLS production comment |
| `package.json` | P18 | Version 0.2.0 -> 0.3.0 |
| `k8s/overlays/local/kustomization.yaml` | P18 | newTag 0.2.0 -> 0.3.0 |

---

## Testing

### Verification Checklist

**UX Fixes (P1-P4, P7):**
- [ ] Page title and sidebar show "Customers" (not "Customer Search")
- [ ] Stripe prices display as dollars with decimal (e.g., $799.00)
- [ ] Search results appear directly below the search input
- [ ] No "Scan Activity (7 Days)" section on customer page
- [ ] No Quick Actions grid on dashboard

**Dashboard Features (P5, P8):**
- [ ] 5 sign-up metric cards display with correct time ranges
- [ ] RadarChart renders scan activity data
- [ ] Time range dropdown changes chart data (7d, 30d, 6m, 1y)

**New Pages (P9, P17):**
- [ ] Navigate to `/vulnerability-data` — page loads with metrics
- [ ] Navigate to `/dependencies` — page loads with service table
- [ ] Both pages appear in sidebar navigation

**Export (P10):**
- [ ] Export button visible on Dashboard, Customers, Audit Logs, Vulnerability Data, Dependencies
- [ ] CSV export downloads valid CSV file
- [ ] JSON export downloads valid JSON file

**Security (P6, P11, P14-P15):**
- [ ] Impersonation stores token in `sessionStorage` and redirects to dashboard
- [ ] After 30 minutes of inactivity, user is redirected to login
- [ ] Mouse/keyboard/scroll activity resets the inactivity timer
- [ ] Change Tier modal requires MFA verification before executing
- [ ] Manage Credits modal requires MFA verification before executing
- [ ] Invalid MFA code shows error and does not execute the action

**Other (P12-P13, P16):**
- [ ] Audit logs page shows "Audit logs are retained for 14 days" banner
- [ ] Users page shows Organization column and Manage Credits link
- [ ] `ingressroute.yaml` contains TLS comment

---

## Impact

### User Impact
- Cleaner admin UX with consistent naming and proper pricing display
- Data export capability across all major admin pages
- MFA enforcement on sensitive operations (tier changes, credit adjustments)
- Automatic session timeout protects unattended admin sessions
- New dedicated pages for vulnerability data and service dependencies

### Breaking Changes
- Quick Actions grid removed from dashboard (all actions accessible via sidebar)
- "Scan Activity (7 Days)" removed from customer search page (moved to dashboard RadarChart)
- Impersonation tokens now stored in `sessionStorage` instead of `localStorage`

### Performance
- RadarChart uses time-range-specific API calls to limit data fetched
- Export generates files client-side to avoid server load
- Session tracking uses passive event listeners

---

## Deployment

### Build and Deploy

```bash
cd /home/pwner/Git/blocksecops-admin-portal

VERSION=0.3.0
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  --build-arg VITE_ENVIRONMENT=local \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.0xapogee.local/blocksecops/admin-portal:${VERSION} .

docker push harbor.0xapogee.local/blocksecops/admin-portal:${VERSION}
kubectl apply -k k8s/overlays/local/
```

---

## Related Documentation

- [Task Documentation](../../TaskDocs-Apogee/DOCUMENTATION-UPDATE-2026-02-06-ADMIN-PORTAL-V0.3.0.md)
- [Admin Portal Architecture](../../blocksecops-docs/architecture/admin-portal.md)
- [Admin Portal Dashboard (2026-02-04)](ADMIN-PORTAL-DASHBOARD-2026-02-04.md)
- [Admin System Fixes (2026-02-05)](ADMIN-SYSTEM-FIXES-2026-02-05.md)
- [Scanner Quality Rework (2026-02-05)](SCANNER-QUALITY-REWORK-2026-02-05.md)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.3.0 | 2026-02-06 | New pages, export component, MFA modals, session tracking, UX overhaul |
| 0.2.0 | 2026-02-05 | ML Models page, retrain functionality |
| 0.1.12 | 2026-02-05 | Fix API response time display |
| 0.1.5 | 2026-02-04 | Comprehensive metrics dashboard |

---

**Maintained By:** Apogee Team
**Status:** Complete
