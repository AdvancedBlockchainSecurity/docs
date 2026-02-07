# Admin Portal v0.4.0 - GCP Cost Estimator, Scanners, Dependencies

**Priority**: P2 - Normal
**Last Tested**: 2026-02-07
**Scope**: GCP Cost Estimator page, Scanners page, Dependencies endpoint, defensive metrics

---

## 1. GCP Cost Estimator Page

### 1.1 Page Access
- [ ] Navigate to `/gcp-costs` from sidebar — page loads
- [ ] Sidebar shows "GCP Costs" with dollar icon
- [ ] Only visible to `platform_admin` role
- [ ] "Estimates Only" warning badge displayed in header

### 1.2 Current Workload Summary
- [ ] Stat cards load from `getClusterMetrics()` API
- [ ] Shows: nodes, running pods, active scanner jobs, succeeded/failed 24h, total CPU/memory
- [ ] Refresh button re-fetches cluster metrics
- [ ] Graceful fallback if metrics API unavailable

### 1.3 Environment Tier Selector
- [ ] Three radio buttons: Minimal, Medium Scale, Large Scale
- [ ] Default selection is "Minimal"
- [ ] Switching tiers updates all base infrastructure costs
- [ ] Tier description text updates on selection
- [ ] Readme estimate shown for each tier

### 1.4 Migration Considerations Panel
- [ ] Panel displays below tier selector
- [ ] Minimal tier shows "entry-level" message with blue bullets
- [ ] Medium Scale shows "Upgrading from: Minimal" with green "Easy migration" badge
- [ ] Large Scale shows "Upgrading from: Medium Scale" with orange "Significant migration" badge
- [ ] Migration notes listed as bullet points per tier

### 1.5 Interactive Parameter Sliders
- [ ] Daily scans slider (0-500) — default from `scanner_jobs.succeeded_24h`
- [ ] Avg scan duration slider (1-15 min) — default from `avg_duration_seconds / 60`
- [ ] Concurrent scanners per Spot VM slider (1-4) — default 2
- [ ] Database storage slider (20-500 GB) — default varies by tier
- [ ] Adjusting any slider recalculates costs in real time

### 1.6 Cost Breakdown Bar Chart
- [ ] Recharts `BarChart` renders with stacked bars
- [ ] Categories: GKE Nodes, Scanner Spot VMs, Cloud SQL, Redis, Networking, Other
- [ ] Tooltip shows category and dollar amount on hover
- [ ] Chart updates when tier or sliders change
- [ ] Y-axis shows dollar amounts

### 1.7 Detailed Cost Table
- [ ] Table shows: Service, Spec, Quantity, Unit Price, Monthly Cost
- [ ] Category subtotals displayed (GKE, Database, Cache, Networking, Other)
- [ ] Grand total at bottom with larger font
- [ ] All amounts formatted as USD with 2 decimal places
- [ ] Tier switch updates all line items

### 1.8 Scanner Spot VM Calculation
- [ ] Spot VM cost = (daily_scans * avg_duration / 60) / concurrent * 30 * spot_rate
- [ ] Increasing daily scans increases Spot VM cost proportionally
- [ ] Increasing concurrent scanners decreases Spot VM cost
- [ ] Minimal tier uses e2-standard-4 Spot ($0.040/hr)
- [ ] Medium/Large Scale tiers use e2-standard-8 Spot ($0.080/hr)

---

## 2. Scanners Page

### 2.1 Page Access
- [ ] Navigate to `/scanners` from sidebar — page loads
- [ ] Sidebar shows "Scanners" with shield icon
- [ ] Only visible to `platform_admin` role

### 2.2 Scanner Table
- [ ] All 14 scanners listed in table
- [ ] Columns: Scanner, Language, Type, Detectors, Version, Status, Jobs, Actions
- [ ] Scanner names display correctly
- [ ] Language column shows associated language
- [ ] Type column shows scanner type (SAST, Fuzzer, etc.)
- [ ] Detectors column shows detector count per scanner

### 2.3 Health Status
- [ ] Refresh button fetches scanner health from API
- [ ] Status column shows Healthy/Degraded/Unknown
- [ ] Version column shows current deployed version
- [ ] Job counts (Total/Failed/Running) update on refresh

### 2.4 Scanner Upgrade
- [ ] "Upgrade" button shown when latest_version differs from current
- [ ] Clicking "Upgrade" opens confirmation modal
- [ ] Modal shows scanner name and version transition
- [ ] Optional reason field available
- [ ] "Cancel" closes dialog
- [ ] "Confirm Upgrade" initiates upgrade
- [ ] Success shows pipeline results (detector comparison, pattern seeding, health score)
- [ ] Error shows failure message

### 2.5 System Page Cleanup
- [ ] System page (`/system`) no longer shows Security Scanners section
- [ ] System page still shows all other sections (Platform Health, Cluster Metrics, etc.)
- [ ] System page does not crash on missing cluster metrics data

---

## 3. Dependencies Page

### 3.1 API Endpoint
- [ ] `GET /api/v1/admin/dependencies` returns 200 with valid admin session
- [ ] Returns `{ dependencies: [...] }` response structure
- [ ] Each dependency has: service, name, current_version, latest_version
- [ ] Returns 401 without authentication
- [ ] Returns 403 for non-admin users

### 3.2 Python Package Versions
- [ ] Shows installed version for key packages (fastapi, sqlalchemy, pydantic, etc.)
- [ ] Shows latest PyPI version for each package
- [ ] Packages with outdated versions visually indicated
- [ ] Missing packages handled gracefully (shows "not installed")

### 3.3 Platform Service Versions
- [ ] Shows versions for platform services (tool-integration, orchestration, etc.)
- [ ] Unreachable services show "unavailable" gracefully

### 3.4 Frontend Display
- [ ] Dependencies page loads at `/dependencies`
- [ ] Table shows all dependency information
- [ ] Refresh button re-fetches data
- [ ] Loading state shown while fetching

---

## 4. Defensive Cluster Metrics

### 4.1 System Page Guards
- [ ] System page loads even when `scanner_jobs` is undefined
- [ ] System page loads even when `resource_usage` is undefined
- [ ] No "cannot access property" errors in browser console
- [ ] Cluster metrics section renders with optional chaining fallbacks

### 4.2 GCP Cost Estimator Guards
- [ ] GCP Cost Estimator loads even when cluster metrics API fails
- [ ] Default values used when API data unavailable
- [ ] Error state shown if metrics completely unavailable

---

## 5. Navigation & Sidebar

### 5.1 New Nav Items
- [ ] "Scanners" appears between "Scan Monitoring" and "System"
- [ ] "GCP Costs" appears after "Dependencies"
- [ ] Both items require `platform_admin` role
- [ ] Active state highlights correctly when on page
- [ ] Sub-routes highlight parent nav item

### 5.2 Role Filtering
- [ ] `support_admin` sees: Dashboard, Customers, Subscriptions, Users, Audit, Vulnerability Data, Dependencies
- [ ] `platform_admin` sees all above plus: Emergency, ML Models, Scan Monitoring, Scanners, System, Dependencies, GCP Costs
- [ ] `super_admin` sees all items

---

## Related Tests

- [46-platform-admin-panel.md](./46-platform-admin-panel.md) - Admin panel core tests
- [57-scanner-upgrade-admin.md](./57-scanner-upgrade-admin.md) - Scanner upgrade tests
- [58-platform-v0.27-v0.40-v0.3-fixes.md](./58-platform-v0.27-v0.40-v0.3-fixes.md) - Previous platform fixes
