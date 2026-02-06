# Dashboard UI Overhaul & Feature Parity

## Version 0.40.0 - Severity Cleanup, Dark Mode, UX Fixes - February 6, 2026

**Date:** 2026-02-06
**Component:** blocksecops-dashboard (0.39.1 -> 0.40.0)
**Type:** Enhancement + Bug Fix
**Priority:** High
**Status:** Complete

---

## Summary

17 changes across the dashboard covering five themes:
1. **Dark mode & theming** (D1-D2) — Global light/dark mode toggle, pricing page dark mode support
2. **Severity cleanup** (D7, D9-D10) — Removed "info" severity from all dashboard code, pending -> queued status
3. **UX improvements** (D3-D6, D8, D11-D12) — Billing fallback, search fixes, audit log errors, deduplication polish, vulnerabilities auto-apply, contract-to-project assignment, project dropdown styling
4. **Access control & error handling** (D13, D15-D16) — Users page RBAC, semantic search error handling, integrations OAuth messaging
5. **New features** (D14) — Rust ecosystem support in patterns filter

28 files modified, 344 insertions, 170 deletions.

---

## Issues Resolved

- No light/dark mode toggle available across the application
- Pricing page not styled for dark mode
- Billing page crashed with 500/error when subscription endpoint returned 404/400
- Search sent `contract_id` but API expected `contract_ids`; execution_count displayed but not available; export available to free-tier users
- Audit logs showed generic error message on API failure
- Deduplication had "Info" severity option and unnecessary Apply Filters button
- "Info" severity references scattered across types, patterns, charts, risk scoring, and environment utilities
- Vulnerabilities page required manual "Apply" button click to filter
- Recent Scans showed "pending" status instead of "queued"
- Scanner Effectiveness title and chart referenced "informational" severity
- No way to add a contract to a project from contract detail page
- Project access dropdown had no styling
- Non-admin users could edit roles on Users page
- No Rust ecosystem option in patterns filter
- Semantic search showed raw error on intelligence engine downtime
- Integrations showed generic error on OAuth misconfiguration

---

## Added

### D1: Light/Dark Mode Toggle

Global dark mode support with `bg-gray-50 dark:bg-dark-400` pattern:

| File | Changes |
|------|---------|
| `src/App.tsx` | Added dark mode `bg-gray-50 dark:bg-dark-400` wrapper |
| `src/components/navigation/Sidebar.tsx` | 10+ class changes for dark mode backgrounds, text, borders, hover states |
| `src/components/navigation/TopBar.tsx` | Dark mode classes for top bar background and text |

### D2: Pricing Page Dark Mode

| File | Changes |
|------|---------|
| `src/pages/Pricing.tsx` | Added LLM Analysis Credits row to feature table |
| `src/pages/Pricing.tsx` | Removed "Back to Dashboard" button |
| `src/pages/Pricing.tsx` | Dark mode classes for feature comparison table and FAQ accordion |

### D11: Contract Detail "Add to Project"

| File | Changes |
|------|---------|
| `src/pages/ContractDetail.tsx` | Project list query, dropdown UI, `addContractToProject` mutation |

### D14: Patterns Rust Ecosystem

| File | Changes |
|------|---------|
| `src/pages/PatternsList.tsx` | Added `RUST` option to ecosystem filter dropdown |

---

## Changed

### D3: Billing Subscription Fallback

**File:** `src/components/billing/SubscriptionCard.tsx`
- Handles 404 and 400 responses gracefully
- Shows free-tier card instead of error state when no subscription exists

### D4: Search Fixes

**File:** `src/lib/api/search.ts`
- Changed `contract_id` to `contract_ids` mapping to match API schema
- Removed `execution_count` display (field not available from API)
- Added tier-based export availability check (team tier required)

### D5: Audit Logs Error Display

**File:** `src/pages/AuditLogs.tsx`
- Status-specific error messages (500: server error, 403: permission denied)
- Added retry button for failed requests

### D6: Deduplication Polish

**File:** `src/pages/Deduplication.tsx`
- Added `keepPreviousData` to query for smoother filter transitions
- Removed "Info" severity option from filter dropdown
- Removed standalone "Apply Filters" button (filters now apply on change)

### D7: Remove "Info" Severity Platform-Wide

Removed all "info" and "informational" severity references from dashboard code:

| File | Changes |
|------|---------|
| `src/types/types.ts` | Removed "info" from `VulnerabilitySeverity` type, removed `informational_findings` field |
| `src/types/patterns.ts` | Removed "info" from `PatternSeverity` type |
| `src/components/charts/SeverityDistributionChart.tsx` | Removed info color and data series |
| `src/components/scanner/ScannerEffectiveness.tsx` | Removed info from `SEVERITY_COLORS`, chart data, tooltip, and bar components |
| `src/lib/risk.ts` | Removed info from `SEVERITY_WEIGHTS`, updated `calculateRiskScore` |
| `src/lib/env.ts` | Removed info from `getSeverityColors` |
| `src/lib/__tests__/env.test.ts` | Removed info severity test cases |
| `src/pages/PatternsList.tsx` | Removed "Info" from severity filter dropdown |
| `src/components/risk/RiskCategoryCard.tsx` | Removed info from `severityColors` map |

### D8: Vulnerabilities Auto-Apply Filters

**File:** `src/pages/Vulnerabilities.tsx`
- Merged `formState` and `filters` into single reactive state
- Added debounce for text input fields (search, contract name)
- Added `keepPreviousData` for smoother transitions

### D9: Recent Scans Status Update

**File:** `src/components/scans/RecentScans.tsx`
- Changed "pending" to "queued" in scan status type definition
- Updated case statement for status badge rendering
- Changed "Pending" to "Queued" in status filter dropdown

### D10: Scanner Effectiveness Title Update

**File:** `src/components/scanner/ScannerEffectiveness.tsx`
- Changed component title to remove "informational" reference
- Removed informational-related chart data series and references

### D12: Project Access Dropdown Styling

**File:** `src/pages/ContractDetail.tsx`
- Added proper `border`, `bg`, `rounded`, and `focus:ring` classes to project dropdown

### D13: Users Page RBAC

**File:** `src/pages/Users.tsx`
- Admin-only role editing: non-admin users see role as read-only text
- Self-demotion prevention: admin cannot change their own role
- Last-admin check: prevents demoting the last admin in the organization
- User count display with tier-based limit indicator
- Conditional "Edit" button visibility based on current user role

### D15: Semantic Search Error Handling

**File:** `src/pages/Search.tsx`
- 503 response: displays "Intelligence service temporarily unavailable" message
- 429 response: displays rate limit exceeded message
- Added retry button for transient errors

### D16: Integrations OAuth Messaging

**File:** `src/components/integrations/hub/SourceControlTab.tsx`
- Detects 400/422 responses and OAuth-specific error patterns
- Displays helpful admin configuration message instead of generic error
- Guides user to check OAuth provider settings

---

## Fixed

- **D3:** Billing page no longer crashes when subscription endpoint returns 404/400
- **D4:** Search correctly sends `contract_ids` array to API
- **D5:** Audit logs show meaningful error messages instead of generic text
- **D9:** Recent Scans displays "Queued" instead of "Pending" for waiting scans

---

## Code Changes

### Files Modified (28 files)

| File | Item | Change |
|------|------|--------|
| `src/App.tsx` | D1 | Dark mode wrapper classes |
| `src/components/navigation/Sidebar.tsx` | D1 | Dark mode navigation classes |
| `src/components/navigation/TopBar.tsx` | D1 | Dark mode top bar classes |
| `src/pages/Pricing.tsx` | D2 | LLM credits row, dark mode, remove back button |
| `src/components/billing/SubscriptionCard.tsx` | D3 | 404/400 fallback to free tier |
| `src/lib/api/search.ts` | D4 | contract_id -> contract_ids, remove execution_count, tier check |
| `src/pages/AuditLogs.tsx` | D5 | Status-specific error messages, retry button |
| `src/pages/Deduplication.tsx` | D6 | keepPreviousData, remove info severity, remove Apply button |
| `src/types/types.ts` | D7 | Remove info from VulnerabilitySeverity |
| `src/types/patterns.ts` | D7 | Remove info from PatternSeverity |
| `src/components/charts/SeverityDistributionChart.tsx` | D7 | Remove info chart series |
| `src/components/scanner/ScannerEffectiveness.tsx` | D7, D10 | Remove info colors/data/tooltip/bar, update title |
| `src/lib/risk.ts` | D7 | Remove info weight, update calculateRiskScore |
| `src/lib/env.ts` | D7 | Remove info from getSeverityColors |
| `src/lib/__tests__/env.test.ts` | D7 | Remove info test cases |
| `src/pages/PatternsList.tsx` | D7, D14 | Remove info severity, add RUST ecosystem |
| `src/components/risk/RiskCategoryCard.tsx` | D7 | Remove info from severityColors |
| `src/pages/Vulnerabilities.tsx` | D8 | Merge formState/filters, debounce, keepPreviousData |
| `src/components/scans/RecentScans.tsx` | D9 | pending -> queued status |
| `src/pages/ContractDetail.tsx` | D11, D12 | Add to project feature, dropdown styling |
| `src/pages/Users.tsx` | D13 | Admin-only role editing, RBAC checks |
| `src/pages/Search.tsx` | D15 | 503/429 error handling, retry button |
| `src/components/integrations/hub/SourceControlTab.tsx` | D16 | OAuth error detection and messaging |
| `package.json` | D17 | Version 0.39.1 -> 0.40.0 |
| `k8s/overlays/local/kustomization.yaml` | D17 | newTag 0.39.1 -> 0.40.0 |

---

## Testing

### Verification Checklist

**Dark Mode (D1-D2):**
- [ ] Toggle dark mode in app, verify background/text/border transitions across all pages
- [ ] Pricing page renders correctly in both light and dark mode
- [ ] LLM Analysis Credits row visible in pricing feature comparison

**Billing & Search (D3-D4):**
- [ ] New user with no subscription sees free-tier card (not error)
- [ ] Search with `contract_id` parameter returns results
- [ ] Search export button hidden for free-tier users

**Error Handling (D5, D15-D16):**
- [ ] Trigger 500 on audit logs, verify specific error message with retry button
- [ ] Stop intelligence engine, perform semantic search, verify 503 message with retry
- [ ] Trigger OAuth error in integrations, verify admin configuration guidance message

**Severity Cleanup (D7, D9-D10):**
- [ ] No "Info" or "Informational" text in severity dropdowns across all pages
- [ ] Severity distribution chart shows 4 levels (critical/high/medium/low)
- [ ] Risk score calculation excludes info weight
- [ ] Recent Scans shows "Queued" (not "Pending") for waiting scans

**UX (D6, D8, D11-D14):**
- [ ] Deduplication filters apply on change without Apply button
- [ ] Vulnerabilities page filters apply automatically with debounce
- [ ] Contract detail page shows "Add to Project" dropdown with project list
- [ ] Project dropdown has proper border, background, and focus ring
- [ ] Users page: non-admin cannot see Edit button for roles
- [ ] Patterns filter includes RUST in ecosystem dropdown

---

## Impact

### User Impact
- Consistent dark mode experience across entire dashboard
- Four-level severity model (critical/high/medium/low) eliminates confusion
- Better error messages guide users to solutions instead of showing raw errors
- Filters apply immediately for faster workflow
- RBAC prevents accidental role changes

### Breaking Changes
- "Info" and "Informational" severity no longer appear in any UI component
- Deduplication no longer accepts "info" severity filter
- Search export requires team tier

### Performance
- `keepPreviousData` on deduplication and vulnerabilities prevents layout shift during filter changes
- Debounced text inputs reduce unnecessary API calls

---

## Deployment

### Build and Deploy

```bash
cd /home/pwner/Git

VERSION=0.40.0
REGISTRY="harbor.blocksecops.local"

SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')
WALLETCONNECT_ID=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.VITE_WALLETCONNECT_PROJECT_ID}')

docker build \
  -f blocksecops-dashboard/Dockerfile \
  --build-arg VITE_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  --build-arg VITE_WALLETCONNECT_PROJECT_ID=${WALLETCONNECT_ID} \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(cd blocksecops-dashboard && git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/dashboard:${VERSION} .

docker push ${REGISTRY}/blocksecops/dashboard:${VERSION}
kubectl apply -k blocksecops-dashboard/k8s/overlays/local/
```

---

## Related Documentation

- [Task Documentation](../../TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-02-06-DASHBOARD-V0.40.0.md)
- [Frontend Development Standards](../standards/frontend-development.md)
- [Frontend Build-Time Environment Variables](../standards/frontend-build-env.md)
- [Tier Standards](../standards/tier-standards.md)
- [Dashboard Dark Mode (2025-12-26)](DARK-MODE-GLOBAL-SEARCH-2025-12-26.md)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.40.0 | 2026-02-06 | Dark mode toggle, remove info severity, UX fixes, RBAC, error handling |
| 0.39.1 | 2026-02-05 | OAuth error passthrough, CI/CD tab, support tickets page |
| 0.39.0 | 2026-02-05 | Scanner quality UX, retrain moved to admin |

---

**Maintained By:** BlockSecOps Team
**Status:** Complete
