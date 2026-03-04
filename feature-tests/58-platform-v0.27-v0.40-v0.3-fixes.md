# Platform-Wide Bug Fixes (API v0.27.0, Dashboard v0.40.0, Admin Portal v0.3.0)

**Priority**: P0 - Critical
**Last Tested**: 2026-02-06
**Scope**: Info severity removal, pending-to-queued mapping, auto-apply filters, dark mode fixes, admin portal enhancements

---

## 1. API Service (v0.27.0)

### 1.1 Severity Validation
- [ ] GET /deduplication/groups?severity=info returns 422 (not 500)
- [ ] GET /deduplication/groups?severity=critical returns 200 with valid data

### 1.2 Scan Status Mapping
- [ ] GET /scans?status=pending is mapped to queued, returns results
- [ ] GET /scans?status=invalid returns 422

### 1.3 Audit Logs
- [ ] GET /audit-logs as enterprise user returns 200
- [ ] GET /audit-logs handles DB errors gracefully (returns empty, not 500)

### 1.4 Search
- [ ] POST /search with contract_id (singular) works correctly
- [ ] GET /search/export requires team tier or higher

### 1.5 Organization User Management
- [ ] PATCH /organizations/current/users/:id role change requires admin role
- [ ] Cannot demote the last admin in organization
- [ ] Cannot lower your own admin role

### 1.6 Analytics & Intelligence
- [ ] GET /analytics/scanner-effectiveness returns populated data
- [ ] GET /intelligence/search handles engine unavailability with 503

### 1.7 Data Migration
- [ ] Vulnerability patterns with severity 'info' migrated to 'low'

---

## 2. Dashboard (v0.40.0)

### 2.1 Dark/Light Mode
- [ ] Toggle dark/light mode — light mode shows white backgrounds
- [ ] Sidebar renders correctly in light mode (white bg, gray text)
- [ ] TopBar renders correctly in light mode

### 2.2 Pricing Page
- [ ] Pricing page — feature comparison table readable in both modes
- [ ] Pricing page — no "Back to Dashboard" button
- [ ] Pricing page — LLM Analysis Credits row present

### 2.3 Billing Page
- [ ] Billing page — shows "Developer (Free)" for users without subscription

### 2.4 Search Page
- [ ] Search page — keyword search returns results
- [ ] Search page — no "used X times" on saved searches
- [ ] Search page — export buttons require Starter tier

### 2.5 Deduplication
- [ ] Deduplication — no "Info" severity option
- [ ] Deduplication — filters auto-apply on change (no Apply button)

### 2.6 Vulnerabilities
- [ ] Vulnerabilities — filters auto-apply on change (no Apply button)
- [ ] Vulnerabilities — text inputs debounced (400ms)

### 2.7 Recent Scans
- [ ] Recent Scans — filter shows "Queued" not "Pending"

### 2.8 Scanner Effectiveness
- [ ] Scanner Effectiveness — title is "Scanner Effectiveness" (not "Dashboard")
- [ ] Scanner Effectiveness — no informational bar in chart

### 2.9 Patterns
- [ ] Patterns — no "Info" severity option in filter
- [ ] Patterns — "Rust (General)" ecosystem option present

### 2.10 Contract Detail
- [ ] Contract Detail — "Add to Project" dropdown works

### 2.11 Users
- [ ] Users — role editing restricted to admin/owner
- [ ] Users — shows "X of Y users" tier limit

### 2.12 Error Handling
- [ ] Semantic search — shows 503 message when engine unavailable
- [ ] Audit logs — shows helpful error messages for 500/403

---

## 3. Admin Portal (v0.3.0)

### 3.1 Navigation & Layout
- [ ] Sidebar shows "Customers" (not "Customer Search")
- [ ] No Quick Actions on dashboard

### 3.2 Pricing & Display
- [ ] Pricing shows $799.00 (not $79900)
- [ ] Search results appear below search input

### 3.3 Sign-Up Metrics
- [ ] Sign-up metrics cards present (Today, 7d, 30d, 6m, 1y)

### 3.4 Scan Activity
- [ ] Scan Activity uses radar chart with time range dropdown

### 3.5 Pages & Navigation
- [ ] Vulnerability Data page accessible from sidebar
- [ ] Export button works on all admin pages (CSV and JSON)

### 3.6 Audit & Retention
- [ ] Audit logs show 14-day retention banner

### 3.7 MFA Verification
- [ ] Change Tier modal requires MFA verification
- [ ] Manage Credits modal requires MFA verification

### 3.8 Session Security
- [ ] Session expires after 30 minutes of inactivity

### 3.9 Dependencies
- [ ] Dependencies page loads
- [ ] Shows Python package versions (current vs latest)
- [ ] Shows platform service versions

> **Note**: Dependencies page now fully functional with API v0.27.7 backend endpoint. See [59-admin-portal-v0.4.0.md](./59-admin-portal-v0.4.0.md) for comprehensive tests.
