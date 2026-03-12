# Admin Dashboard Metrics Tests

**Priority**: P1 - High
**Last Tested**: February 4, 2026
**Component**: blocksecops-admin-portal
**Version**: 0.1.5

---

## Overview

Tests for the comprehensive admin dashboard with real-time platform metrics, system health monitoring, and analytics panels.

---

## 1. Dashboard Loading

### 1.1 Initial Load
- [ ] Dashboard loads without errors
- [ ] Loading spinner displayed during data fetch
- [ ] All data panels render after load
- [ ] "Last updated" timestamp displayed
- [ ] No console errors

### 1.2 Error Handling
- [ ] Error message displayed if all APIs fail
- [ ] Retry button available on error
- [ ] Partial data displayed if some APIs succeed
- [ ] Graceful degradation (panels hide if no data)

---

## 2. Primary KPI Cards

### 2.1 Total Users Card
- [ ] Displays total user count
- [ ] Shows "+X today, +X this week" subtitle
- [ ] Growth trend percentage displayed (if positive)
- [ ] Links to /users page on click

### 2.2 Total Scans Card
- [ ] Displays total scan count
- [ ] Shows "X today, X this week" subtitle
- [ ] Growth trend percentage displayed (if positive)

### 2.3 Vulnerabilities Card
- [ ] Displays total vulnerability count
- [ ] Shows "X critical, X high" subtitle
- [ ] Red color theme applied

### 2.4 Total Revenue Card
- [ ] Displays formatted revenue (e.g., "$1,234")
- [ ] Shows "$X this month" subtitle
- [ ] Green color theme applied
- [ ] Links to /purchases page on click

### 2.5 Active Users Card
- [ ] Displays active user count
- [ ] Shows "X inactive" subtitle
- [ ] Links to /users?is_active=true on click

### 2.6 Organizations Card
- [ ] Displays organization count
- [ ] Links to /organizations page on click

### 2.7 Active Subscriptions Card
- [ ] Displays active subscription count
- [ ] Shows "X trialing" subtitle
- [ ] Links to /purchases?tab=subscriptions on click

### 2.8 Intelligence Records Card
- [ ] Displays sum of exploits + CVEs
- [ ] Shows "X patterns" subtitle

---

## 3. System Health Panel

### 3.1 Health Badge
- [ ] Green badge for "healthy" status
- [ ] Yellow badge for "degraded" status
- [ ] Red badge for "unhealthy" status
- [ ] Badge displays in header area

### 3.2 Component Status Grid
- [ ] All components displayed in grid
- [ ] Each component shows status icon
- [ ] Green checkmark for healthy
- [ ] Yellow exclamation for degraded
- [ ] Red X for unhealthy
- [ ] Component message displayed if present

### 3.3 Version Display
- [ ] API version displayed
- [ ] Environment displayed (local/staging/production)

### 3.4 Response Time Display (Added 2026-02-05)
- [ ] API Service shows response time in milliseconds (not "-")
- [ ] Response time color-coded: green (<100ms), yellow (<500ms), red (>500ms)
- [ ] Other services with health data show response times
- [ ] Services without health data show "-" gracefully

### 3.5 Scanner Health Status (Added 2026-02-05)
- [ ] All scanners show "Available" when no jobs are failing
- [ ] Scanner with active jobs shows "Running"
- [ ] Scanner with more failures than successes shows "Degraded"
- [ ] Scanner version displayed from API response

---

## 4. Scan Activity Chart

### 4.1 Chart Display
- [ ] 7-day bar chart rendered
- [ ] Day labels shown (Mon, Tue, etc.)
- [ ] Bar heights proportional to counts
- [ ] Count displayed in each bar
- [ ] Hover effect on bars

### 4.2 Data Accuracy
- [ ] Today's count matches API response
- [ ] Historical counts accurate
- [ ] Empty days show minimal bar

---

## 5. Revenue & Transactions Panel

### 5.1 Revenue Metrics
- [ ] Total revenue displayed
- [ ] This month revenue displayed
- [ ] Last month revenue displayed

### 5.2 Transaction Status
- [ ] Total transactions count
- [ ] Verified count with green badge
- [ ] Pending count with yellow badge
- [ ] Failed count with red badge

### 5.3 Credits Metrics
- [ ] Total credits sold displayed
- [ ] This month credits displayed

---

## 6. Vulnerability Breakdown Panel

### 6.1 Severity Bars
- [ ] Critical bar with red color
- [ ] High bar with orange color
- [ ] Medium bar with yellow color
- [ ] Low bar with blue color

### 6.2 Progress Bars
- [ ] Bar width proportional to total
- [ ] Count displayed next to label
- [ ] Bars animate on load

---

## 7. Deduplication Analytics Panel

### 7.1 Summary Metrics
- [ ] Total dedup groups count
- [ ] Findings deduplicated count
- [ ] Average group size (2 decimal places)

### 7.2 Confidence Breakdown
- [ ] Exact count displayed (green)
- [ ] High count displayed (blue)
- [ ] Medium count displayed (yellow)
- [ ] Low count displayed (gray)

---

## 8. Intelligence Database Panel

### 8.1 Totals
- [ ] Total exploits count
- [ ] Total CVEs count
- [ ] Vulnerability patterns count

### 8.2 Recent Activity
- [ ] Recent exploits (30d) with orange highlight
- [ ] Recent CVEs (30d) with yellow highlight

---

## 9. Users by Tier Panel

### 9.1 Tier Distribution
- [ ] All tiers displayed (free, starter, professional, enterprise)
- [ ] Count and percentage for each tier
- [ ] Progress bar for visual distribution
- [ ] Color coding per tier

---

## 10. Subscriptions by Tier Panel

### 10.1 Status Summary
- [ ] Active count in green
- [ ] Trialing count in yellow
- [ ] Canceled count in red

### 10.2 Tier Distribution
- [ ] Each tier listed with count
- [ ] Sorted by tier name

---

## 11. Quick Actions

### 11.1 Navigation Links
- [ ] Manage Users links to /users
- [ ] Organizations links to /organizations
- [ ] Purchases links to /purchases
- [ ] Audit Logs links to /audit
- [ ] System Health links to /system
- [ ] Emergency links to /emergency

### 11.2 Visual Design
- [ ] Icons displayed for each action
- [ ] Hover effect on action cards
- [ ] Consistent grid layout

---

## 12. Refresh Functionality

### 12.1 Manual Refresh
- [ ] Refresh button visible in header
- [ ] Click triggers data reload
- [ ] Spinner animation during refresh
- [ ] Button disabled during refresh
- [ ] Data updates after refresh

### 12.2 Auto-Refresh
- [ ] Data refreshes every 60 seconds
- [ ] "Last updated" timestamp updates
- [ ] No visual disruption during auto-refresh

---

## 13. Responsive Design

### 13.1 Desktop (1920px+)
- [ ] 4-column grid for KPI cards
- [ ] 6-column grid for health components
- [ ] 2-column layout for panels

### 13.2 Tablet (768px-1024px)
- [ ] 2-column grid for KPI cards
- [ ] 4-column grid for health components
- [ ] Single column for panels

### 13.3 Mobile (< 768px)
- [ ] Single column for all elements
- [ ] Touch-friendly tap targets
- [ ] Horizontal scroll for tables if needed

---

## 14. API Integration

### 14.1 Endpoints Used
- [ ] `GET /admin/system/stats` - System statistics
- [ ] `GET /admin/system/health` - Health check
- [ ] `GET /admin/purchases/stats` - Purchase statistics
- [ ] `GET /intelligence/stats` - Intelligence database stats
- [ ] `GET /deduplication/stats` - Deduplication statistics

### 14.2 Error Resilience
- [ ] Dashboard loads even if some endpoints fail
- [ ] Failed panels show appropriate message or hide
- [ ] Successful panels still display data

---

## Test Execution

### Prerequisites
1. Admin portal running at `http://localhost:5173` or `http://admin.0xapogee.com:3000`
2. API service running and healthy
3. Valid admin credentials with MFA
4. Test data in database (users, scans, vulnerabilities)

### Test Steps
1. Login to admin portal
2. Navigate to Dashboard (default page)
3. Verify all sections load
4. Test manual refresh
5. Wait 60+ seconds for auto-refresh
6. Test all navigation links
7. Resize browser for responsive tests
8. Check browser console for errors

---

## Related Documentation

- [Admin Portal Dashboard Changelog](../changelogs/ADMIN-PORTAL-DASHBOARD-2026-02-04.md)
- [Admin Authentication Tests](./55-admin-portal-isolation.md)
- [Release Notes - February 2026](../../blocksecops-docs/resources/release-notes/2026/february.md)
