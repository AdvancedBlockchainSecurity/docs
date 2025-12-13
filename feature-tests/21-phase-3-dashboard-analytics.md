# Phase 3: Dashboard Analytics & Scan Details Testing

**Version:** 1.0.0
**Created:** December 12, 2025
**Status:** Ready for Testing

---

## Overview

This document covers testing for Phase 3 features:
- Dashboard Visualizations
- Scan Detail Page Improvements
- Real-Time WebSocket Updates

---

## Prerequisites

- User logged in with valid session
- At least one completed scan with vulnerabilities
- Port-forwards active (Traefik on 3000)

---

## 1. Dashboard Visualizations

**URL:** http://127.0.0.1:3000 (Dashboard page)

### 1.1 Main Dashboard Charts

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Risk trend line chart | Navigate to Dashboard | Line chart displays vulnerability trend over time |
| Severity distribution pie | View Dashboard | Pie chart shows Critical/High/Medium/Low breakdown |
| Stats cards | View Dashboard | Cards show Total Scans, Vulnerabilities, Contracts, Risk Score |
| Scan activity chart | View Dashboard | Line chart shows last 30 days scan activity |

### 1.2 Analytics Page

**URL:** http://127.0.0.1:3000/analytics

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Summary stats | Navigate to Analytics | Widgets show total stats with trend indicators |
| Severity distribution | View Analytics | Bar/pie chart shows severity breakdown |
| Period comparison | View Analytics | Chart compares first half vs second half of period |
| Tool effectiveness | View Analytics | Chart shows findings per scanner tool |
| Scanner performance | View Analytics | Chart shows scanner success rates and timing |
| Project health cards | Scroll down | Cards show health score per project |

### 1.3 Time Range Selector

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| 7 days | Select "7 days" from dropdown | Charts update to show 7-day data |
| 14 days | Select "14 days" | Charts update to show 14-day data |
| 30 days | Select "30 days" | Charts update to show 30-day data |
| 90 days | Select "90 days" | Charts update to show 90-day data |
| 180 days | Select "180 days" | Charts update to show 180-day data |
| 365 days | Select "365 days" | Charts update to show full year |

### 1.4 Export Functionality

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Export PDF | Click "Export PDF" button | PDF file downloads with analytics data |
| Export JSON | Click "Export JSON" button | JSON file downloads with raw data |
| Export CSV | Click "Export CSV" button | CSV file downloads with tabular data |

### 1.5 Auto-Refresh

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Live indicator | View Analytics page | "Live" indicator visible (green dot or text) |
| Auto-refresh | Wait 30-60 seconds | Data refreshes automatically |
| Manual refresh | Click refresh button | Data reloads immediately |

---

## 2. Scan Detail Page

**URL:** http://127.0.0.1:3000/scans/{scan-id}

### 2.1 Severity Distribution

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Pie chart | View scan results | Pie chart shows severity breakdown |
| Summary cards | View scan results | Cards show Critical/High/Medium/Low counts |
| Scanner breakdown | View scan results | Panel shows scanner vs intelligence findings |

### 2.2 Filtering

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Severity filter | Select "Critical" | Only critical findings shown |
| Status filter | Select "Open" | Only open findings shown |
| Category filter | Select a category | Findings filtered by category |
| Scanner filter | Select a scanner | Only findings from that scanner shown |
| Confidence slider | Drag to 80% | Only findings with 80%+ confidence shown |
| Combined filters | Apply multiple filters | Filters work together (AND logic) |
| Clear filters | Click "Clear" | All findings shown again |

### 2.3 Sorting

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Sort by severity | Click severity sort | Findings ordered Critical → Low |
| Sort by date | Click date sort | Findings ordered by discovery date |
| Sort by line number | Click line sort | Findings ordered by line number |
| Sort by category | Click category sort | Findings ordered alphabetically by category |

### 2.4 Bulk Operations

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Select individual | Click checkbox on finding | Finding selected, counter updates |
| Select all | Click "Select All" | All visible findings selected |
| Mark Acknowledged | Select findings → Click "Acknowledged" | Status changes to Acknowledged |
| Mark Fixed | Select findings → Click "Fixed" | Status changes to Fixed |
| Mark False Positive | Select findings → Click "False Positive" | Status changes to False Positive |
| Clear selection | Click "Clear Selection" | All checkboxes unchecked |

### 2.5 Export

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Export PDF | Click "Export PDF" | PDF report downloads |
| Export CSV | Click "Export CSV" | CSV file downloads |
| Export JSON | Click "Export JSON" | JSON file downloads |
| Export SARIF | Click "Export SARIF" | SARIF file downloads (GitHub compatible) |

### 2.6 Vulnerability Details

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Open modal | Click on a finding | Detail modal opens |
| Code snippet | View modal | Code block shows with syntax highlighting |
| File location | View modal | File path and line number displayed |
| Pattern badge | View modal | Pattern code badge visible (if applicable) |
| Deduplication indicator | View modal | Shows if finding was deduplicated |
| Recommendation | View modal | Remediation recommendation displayed |
| Close modal | Click X or outside | Modal closes |

---

## 3. Real-Time WebSocket Updates

### 3.1 Scan Progress

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Progress bar | Trigger new scan → View scan page | Progress bar shows percentage |
| Progress updates | Watch during scan | Bar updates as tools complete |
| Tool status | View during scan | Shows which scanner is running |

### 3.2 Live Updates

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Vulnerability count | Watch during scan | Count increases as findings discovered |
| Live indicator | View during scan | "Live" or green dot visible |
| Scan list update | View scans list | New scans appear automatically |

### 3.3 Completion

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Completion notification | Wait for scan to finish | Toast/notification appears |
| Auto-refresh results | Scan completes | Results load automatically |
| Status update | Scan completes | Status changes from "running" to "completed" |

---

## 4. Test Scenarios

### Scenario 1: New User Dashboard Review

1. Login as new user
2. Navigate to Dashboard
3. Verify charts show "No data" or appropriate empty state
4. Upload a contract and run scan
5. Return to Dashboard
6. Verify charts now show data

### Scenario 2: Analytics Deep Dive

1. Navigate to Analytics page
2. Set time range to 30 days
3. Review all charts and metrics
4. Export PDF report
5. Change time range to 7 days
6. Verify data updates appropriately

### Scenario 3: Scan Results Workflow

1. Navigate to a completed scan
2. Filter by "Critical" severity
3. Select all critical findings
4. Mark as "Acknowledged"
5. Clear filter
6. Verify status updated for those findings
7. Export results as SARIF

### Scenario 4: Real-Time Monitoring

1. Upload a new contract
2. Trigger scan with multiple tools (Slither, Aderyn, Semgrep)
3. Navigate to scan results page immediately
4. Watch progress bar update
5. Watch vulnerability count increase
6. Wait for completion notification
7. Verify all results loaded

---

## 5. Known Issues

| Issue | Status | Workaround |
|-------|--------|------------|
| None currently | - | - |

---

## 6. Related Documentation

- [Dashboard Implementation](../../blocksecops-dashboard/src/pages/Dashboard.tsx)
- [Analytics Implementation](../../blocksecops-dashboard/src/pages/DashboardAnalytics.tsx)
- [Scan Results Implementation](../../blocksecops-dashboard/src/pages/ScanResults.tsx)
- [WebSocket Hooks](../../blocksecops-dashboard/src/hooks/useWebSocket.ts)

---

**Document Owner:** QA Team
**Last Updated:** December 12, 2025
