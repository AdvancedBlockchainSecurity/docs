# Admin Portal v0.4.0 - GCP Cost Estimator, Scanners Page, Dependencies

## Version 0.4.0 - February 7, 2026

**Date:** 2026-02-07
**Component:** blocksecops-admin-portal (0.3.1 -> 0.4.0)
**Type:** Feature / Enhancement
**Priority:** Medium
**Status:** Complete

### Summary

Added three new admin pages: GCP Cost Estimator (interactive calculator for estimating GCP migration costs), standalone Scanners page (extracted from System page), and Dependencies page (shows installed vs latest package versions). Also added defensive cluster metrics handling and migration considerations panel.

### Added

- **GCP Cost Estimator page** (`/gcp-costs`) — Interactive calculator for estimating GCP infrastructure costs:
  - Three environment tiers: Minimal (Autopilot ~$55-65/mo), Medium Scale (~$684/mo), Large Scale (~$2,078/mo)
  - Interactive sliders for daily scans, scan duration, concurrent scanners, database storage
  - Fetches current workload baseline from `getClusterMetrics()` API
  - Cost breakdown bar chart (recharts `BarChart`) by category: GKE Nodes, Cloud SQL, Redis, Networking, Other
  - Detailed cost table with per-service line items, subtotals, and grand total
  - GCP pricing constants for us-west1 region (e2-standard-2/4/8, on-demand and Spot)
  - Migration considerations panel showing upgrade path difficulty and notes per tier

- **Scanners page** (`/scanners`) — Standalone scanner management extracted from System page:
  - 14 scanners with health status, version, job counts
  - New "Detectors" column showing detector count per scanner
  - Scanner upgrade modal with pipeline results display
  - Standalone data fetching lifecycle with refresh button
  - Requires `platform_admin` role

- **Dependencies page** (`/dependencies`) — Shows installed Python package versions vs PyPI latest:
  - Calls `GET /admin/dependencies` backend endpoint
  - 26 key Python packages tracked (FastAPI, SQLAlchemy, Pydantic, etc.)
  - Platform service versions from health endpoints
  - Requires `support_admin` role

- **Migration Considerations panel** on GCP Cost Estimator:
  - Shows upgrade path from previous tier
  - Difficulty badges (easy/significant)
  - Bullet-point migration notes per tier

- **Sidebar navigation updates:**
  - "GCP Costs" nav item with `CurrencyDollarIcon` (platform_admin)
  - "Scanners" nav item with `ShieldCheckIcon` (platform_admin)

### Changed

- **System page** — Removed all scanner-related code (table, health fetching, upgrade modal):
  - Removed ~175 lines of Security Scanners JSX section
  - Removed ~130 lines of upgrade confirmation dialog
  - Removed scanner-related state, helpers, and imports
  - Scanners now have their own dedicated page at `/scanners`

- **Defensive cluster metrics** — System page no longer crashes on missing data:
  - Added `clusterMetrics.scanner_jobs` to guard condition
  - Added optional chaining (`?.`) and nullish coalescing (`?? 0`) on property accesses
  - Wrapped `resource_usage` section in conditional render

### Code Changes

**New Files:**
- `src/pages/AdminGcpCostEstimator.tsx` — GCP Cost Estimator page (~1100 lines)
- `src/pages/AdminScanners.tsx` — Scanners management page (~500 lines)

**Files Modified:**
- `src/App.tsx` — Added imports and routes for AdminGcpCostEstimator, AdminScanners
- `src/layouts/AdminLayout.tsx` — Added CurrencyDollarIcon, ShieldCheckIcon imports; added "GCP Costs" and "Scanners" nav items
- `src/pages/AdminSystem.tsx` — Removed scanner code, added defensive metrics handling
- `package.json` — Version `0.3.1` -> `0.4.0`
- `k8s/overlays/local/kustomization.yaml` — Updated newTag and version labels to `0.4.0`

### Testing

**Verification Results:**
- `npx tsc --noEmit` — No TypeScript errors
- Sidebar shows "GCP Costs" and "Scanners" links for platform_admin users
- GCP Cost Estimator loads, fetches cluster metrics, and renders cost breakdown
- Adjusting sliders recalculates Scanner Spot VM costs in real time
- Switching tiers updates base infrastructure costs and migration panel
- Scanners page loads health data and displays scanner table
- System page no longer crashes on missing `scanner_jobs` data

### Deployment

```bash
cd /home/pwner/Git/blocksecops-admin-portal

# Get Supabase credentials
SUPABASE_URL=$(kubectl get configmap -n admin-portal-local admin-portal-config -o jsonpath='{.data.VITE_ADMIN_SUPABASE_URL}')
SUPABASE_KEY=$(kubectl get configmap -n admin-portal-local admin-portal-config -o jsonpath='{.data.VITE_ADMIN_SUPABASE_ANON_KEY}')

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  -t harbor.0xapogee.local/blocksecops/admin-portal:0.4.0 .

docker push harbor.0xapogee.local/blocksecops/admin-portal:0.4.0
kubectl apply -k k8s/overlays/local/
kubectl rollout restart deploy/admin-portal -n admin-portal-local
```

### Impact

- **User Impact:** Three new admin pages for GCP migration planning, scanner management, and dependency tracking
- **Breaking Changes:** None — scanner functionality moved to dedicated page, System page still has all other system info
- **Dependencies:** GCP Cost Estimator uses recharts (already in package.json v2.15.0)
- **Backend Requirement:** Dependencies page requires API service v0.27.7 with `/admin/dependencies` endpoint

### Related Documentation

- [API Service v0.27.7 Changelog](API-SERVICE-V0.27.7-DEPENDENCIES-ENDPOINT-2026-02-07.md) - Dependencies endpoint
- [Scanner Upgrade Admin Tests](../feature-tests/57-scanner-upgrade-admin.md) - Scanner upgrade testing
- [Admin Portal v0.3.1 Changelog](ADMIN-PORTAL-V0.3.1-HTTPS-INGRESSROUTE-2026-02-06.md) - Previous version
- [GCP Cost Estimator Docs](../../blocksecops-docs/platform/admin/gcp-cost-estimator.md) - User documentation
- [Scanner Management Docs](../../blocksecops-docs/platform/admin/scanner-management.md) - User documentation

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.4.0 | 2026-02-07 | GCP Cost Estimator, Scanners page, Dependencies, defensive metrics |
| 0.3.1 | 2026-02-06 | HTTPS IngressRoute fix |
| 0.3.0 | 2026-02-06 | New pages, export, MFA, session tracking, UX overhaul |
| 0.2.0 | 2026-02-05 | ML Models page, retrain functionality |

---

**Maintained By:** Apogee Team
**Status:** Complete
