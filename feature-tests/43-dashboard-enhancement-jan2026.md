# Dashboard Enhancement Tests (January 2026)

Manual testing checklist for dashboard enhancements implemented in January 2026.

## Status Legend

| Status | Meaning |
|--------|---------|
| [ ] | Not tested |
| [x] | Passed |
| [!] | Failed |

---

## Test Categories

1. [Dashboard Layout Changes](#1-dashboard-layout-changes)
2. [Sidebar Navigation Updates](#2-sidebar-navigation-updates)
3. [Theme Toggle](#3-theme-toggle)
4. [API Keys Tier-Based Limits](#4-api-keys-tier-based-limits)
5. [Vulnerability Status Dropdown](#5-vulnerability-status-dropdown)
6. [New Pages (Users, Roles, RecentScans)](#6-new-pages)
7. [PDF Export Branding](#7-pdf-export-branding)
8. [Pattern ID to BVD-ID Rename](#8-pattern-id-to-bvd-id-rename)
9. [Organizations Role-Based Permissions](#organizations-role-based-permissions)
10. [Webhooks UI](#10-webhooks-ui)
11. [Webhook Test Feature](#11-webhook-test-feature)
12. [Vulnerability Modal "View Full Details" Button](#12-vulnerability-modal-view-full-details-button-v0381)

---

## 1. Dashboard Layout Changes

### Test 1.1: Intelligence Layer Positioning

**Precondition:** User is logged in with vulnerabilities in the system

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Dashboard | Dashboard loads | [ ] |
| 2 | Observe section order | Quota Bar -> Quick Filters -> Intelligence Layer | [ ] |
| 3 | Verify Intelligence Layer shows | Stats visible (total, deduplicated, multi-scanner) | [ ] |

### Test 1.2: Favorites Section Removed

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Dashboard | Dashboard loads | [ ] |
| 2 | Look for Favorites section | No Favorites section visible | [ ] |

### Test 1.3: Dynamic Quick Filter

**Precondition:** User has scanned contracts with various vulnerability categories

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Dashboard | Dashboard loads | [ ] |
| 2 | Observe Quick Filters | 5th filter shows top vulnerability category | [ ] |
| 3 | Click dynamic filter | Navigates to advanced search with category filter | [ ] |

---

## 2. Sidebar Navigation Updates

### Test 2.1: Renamed Navigation Items

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View sidebar | "Contracts" label (not "All Contracts") | [ ] |
| 2 | View sidebar | "Projects" label (not "All Projects") | [ ] |

### Test 2.2: Management Section

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View sidebar | "Management" section visible | [ ] |
| 2 | Expand Management | Shows Organizations, Teams, Projects, Users, Roles | [ ] |
| 3 | Click Users | Navigates to /users | [ ] |
| 4 | Click Roles | Navigates to /roles | [ ] |

### Test 2.3: Recent Scans Route

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Scans section | Recent Scans option visible | [ ] |
| 2 | Click Recent Scans | Navigates to /recent-scans | [ ] |
| 3 | Verify page loads | Recent scans list displayed | [ ] |

---

## 3. Theme Toggle

### Test 3.1: Theme Toggle in TopBar

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View TopBar | Sun/Moon icon visible | [ ] |
| 2 | Click toggle (in dark mode) | Switches to light mode | [ ] |
| 3 | Click toggle (in light mode) | Switches to dark mode | [ ] |
| 4 | Refresh page | Theme preference persists | [ ] |

### Test 3.2: Theme Affects All Components

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Switch to light mode | All components use light theme | [ ] |
| 2 | Navigate to different pages | Theme consistent across pages | [ ] |
| 3 | Open modals | Modals use correct theme | [ ] |

---

## 4. API Keys Tier-Based Limits

### Test 4.1: Rate Limit Display

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Go to Settings > API Keys | API Keys page loads | [ ] |
| 2 | Click Create API Key | Modal opens | [ ] |
| 3 | Observe Rate Limits section | Shows tier name and max limits | [ ] |

### Test 4.2: Tier-Based Maximum Validation

**Test for Developer tier:**

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open Create API Key modal | Modal displays | [ ] |
| 2 | Enter rate limit > 60/min | Validation error shown | [ ] |
| 3 | Enter rate limit > 1000/hr | Validation error shown | [ ] |
| 4 | Enter valid limits (≤60, ≤1000) | No validation error | [ ] |

### Test 4.3: Expiration Required

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open Create API Key modal | Modal displays | [ ] |
| 2 | Check expiration options | No "Never expires" option | [ ] |
| 3 | Verify available options | 30 days, 90 days, 6 months, 1 year | [ ] |

---

## 5. Vulnerability Status Dropdown

### Test 5.1: Status Options Available

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to vulnerability detail | Detail page loads | [ ] |
| 2 | View status dropdown | Dropdown visible in right panel | [ ] |
| 3 | Click dropdown | Shows all 6 status options | [ ] |

### Test 5.2: Status Change Functionality

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Select "In Progress" | Status updates, styling changes to blue | [ ] |
| 2 | Select "Fixed" | Rescan dialog appears | [ ] |
| 3 | Select "Won't Fix" | Status updates to gray styling | [ ] |
| 4 | Select "False Positive" | Status updates to gray styling | [ ] |

### Test 5.3: ANSI Stripping (Sol-azy Output)

**Precondition:** Have a vulnerability found by Sol-azy scanner

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View Sol-azy vulnerability | Detail page loads | [ ] |
| 2 | Check output/description | No ANSI escape codes visible | [ ] |
| 3 | Verify readable text | Clean, formatted text displayed | [ ] |

---

## 6. New Pages

### Test 6.1: Users Page

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to /users | Users page loads | [ ] |
| 2 | Verify user list displayed | Shows organization users | [ ] |
| 3 | Test search functionality | Filters users by name/email | [ ] |

### Test 6.2: Roles Page

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to /roles | Roles page loads | [ ] |
| 2 | Verify system roles listed | Owner, Admin, Member shown | [ ] |
| 3 | Click role to view permissions | Permission list displayed | [ ] |

### Test 6.3: Recent Scans Page

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to /recent-scans | Recent Scans page loads | [ ] |
| 2 | Verify scan list displayed | Shows recent scan activity | [ ] |
| 3 | Click scan row | Navigates to scan results | [ ] |

---

## 7. PDF Export Branding

### Test 7.1: Purple Header

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Go to Analytics | Analytics page loads | [ ] |
| 2 | Click Export PDF | PDF generation starts | [ ] |
| 3 | Open generated PDF | Header uses purple (#8B5CF6) | [ ] |

### Test 7.2: Domain Headers

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open generated PDF | PDF displays | [ ] |
| 2 | Check header | Shows "BlockSecOps.com" | [ ] |
| 3 | Check header | Shows "AdvancedBlockchainSecurity.com" | [ ] |

### Test 7.3: Watermark

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open generated PDF | PDF displays | [ ] |
| 2 | Check page background | "BlockSecOps" watermark visible | [ ] |

---

## 8. Pattern ID to BVD-ID Rename

### Test 8.1: UI Label Updated

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to vulnerability with pattern | Detail page loads | [ ] |
| 2 | Look for pattern identifier | Shows "BVD-ID" not "Pattern ID" | [ ] |

### Test 8.2: Pattern List Display

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to patterns/intelligence page | Page loads | [ ] |
| 2 | View pattern list | Column header shows "BVD-ID" | [ ] |

---

## Organizations Role-Based Permissions

### Test 9.1: Non-Admin Cannot Add Members

**Precondition:** Login as Member (not Admin/Owner)

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Organization | Organization page loads | [ ] |
| 2 | Look for "Add Member" button | Button NOT visible | [ ] |

### Test 9.2: Non-Admin Cannot Change Roles

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View member list | Members displayed | [ ] |
| 2 | Check role column | Dropdown NOT visible (text only) | [ ] |

### Test 9.3: Remove Member Error Banner

**Precondition:** Login as Admin, attempt to remove member (simulate failure)

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Click remove on member | Removal attempted | [ ] |
| 2 | If API fails | Error banner displayed | [ ] |
| 3 | Verify banner message | Shows error details | [ ] |

---

## Audit Log Expand Arrow

### Test 10.1: Expand Arrow Works

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Audit Logs | Audit log list displays | [ ] |
| 2 | Click expand arrow on log entry | Row expands to show details | [ ] |
| 3 | Click expand arrow again | Row collapses | [ ] |

---

## Webhooks Test Button

### Test 11.1: Test Button Loading State

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Webhooks | Webhook list displays | [ ] |
| 2 | Click Test button on webhook | Loading spinner shows | [ ] |
| 3 | Wait for response | Toast notification appears | [ ] |

### Test 11.2: Test Success Toast

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Test webhook (success case) | Test completes | [ ] |
| 2 | Verify toast | Success toast with response time | [ ] |

### Test 11.3: Test Failure Toast

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Test webhook (failure case) | Test fails | [ ] |
| 2 | Verify toast | Error toast with error message | [ ] |

---

## 12. Vulnerability Modal "View Full Details" Button (v0.38.1)

### Test 12.1: Button Visibility

**Precondition:** User has scans with vulnerabilities

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Scan Results | Scan results page loads | [ ] |
| 2 | Click on a vulnerability | Vulnerability modal opens | [ ] |
| 3 | Look at modal footer | "View Full Details" blue button visible | [ ] |

### Test 12.2: Button Navigation

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open vulnerability modal | Modal opens | [ ] |
| 2 | Click "View Full Details" | Navigates to /vulnerabilities/{id} | [ ] |
| 3 | Verify page content | Full vulnerability detail page loads | [ ] |

### Test 12.3: Button Styling

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open vulnerability modal | Modal opens | [ ] |
| 2 | Observe button styling | Blue primary button (bg-blue-600) | [ ] |
| 3 | Hover over button | Hover state visible (darker blue) | [ ] |

---

## Test Notes

```
[Date] | [Tester] | [Section] | [Result]
2026-01-22 | Claude Code | Implementation | COMPLETE - All features implemented
2026-02-04 | Claude Code | Section 12 | ADDED - View Full Details button tests
```

---

## Related Documentation

- [Dashboard Navigation](../../blocksecops-docs/platform/dashboard/navigation.md)
- [API Keys](../../blocksecops-docs/api/api-key.md)
- [Vulnerability Overview](../../blocksecops-docs/platform/findings/vulnerability-overview.md)
- [Users Management](../../blocksecops-docs/platform/management/users.md)
- [Roles Management](../../blocksecops-docs/platform/management/roles.md)
