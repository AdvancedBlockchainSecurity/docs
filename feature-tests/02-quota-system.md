# Quota System Tests

**Priority**: P0 - Critical
**Last Updated**: March 7, 2026
**Related**: Phase 3.1a Freemium Auth, Migration 024, Migration 030
**Source of Truth**: `/home/pwner/Git/blocksecops-shared/tier-config/tiers.json`

---

## Tier Reference (Updated March 2026 - 4-Tier Model)

| Tier | Price | Scans/Mo | Files/Scan | LoC/Scan | Projects | Team Members | API Calls |
|------|-------|----------|------------|----------|----------|--------------|-----------|
| Developer | $0 | 3 | Unlimited | Unlimited | 3 | 2 | 0 |
| Starter | $299/mo | 15 | Unlimited | Unlimited | 10 | 5 | 0 |
| Growth | $699/mo | 50 | Unlimited | Unlimited | Unlimited | 15 | Unlimited |
| Enterprise | $1,999+/mo | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited |

**Note:** 4-tier pricing model. Developer tier is free with limited scans. API access available on Growth tier and above.

---

## 1. Quota Widget Display

### 1.1 Developer Tier Display (Free - $0/mo)
- [ ] QuotaWidget shows "Developer" tier label
- [ ] Shows scans used / 3 max
- [ ] Shows files-per-scan as unlimited
- [ ] Shows LoC-per-scan as unlimited
- [ ] Shows projects used / 3 max
- [ ] Shows "No API access" for API calls
- [ ] Shows "Export disabled" indicator
- [ ] Shows upgrade prompt
- [ ] Progress bar reflects usage
- [ ] Shows team members used / 2 max

### 1.2 Starter Tier Display ($299/mo)
- [ ] QuotaWidget shows "Starter" tier label
- [ ] Shows scans used / 15 max
- [ ] Shows unlimited files-per-scan
- [ ] Shows projects used / 10 max
- [ ] Shows "No API access" for API calls
- [ ] Shows team members used / 5 max
- [ ] Shows export enabled
- [ ] Progress bar reflects usage

### 1.3 Growth Tier Display ($699/mo)
- [ ] QuotaWidget shows "Growth" tier label
- [ ] Shows scans used / 50 max
- [ ] Shows unlimited files-per-scan
- [ ] Shows projects as unlimited
- [ ] Shows API calls as unlimited
- [ ] Shows team members used / 15 max
- [ ] Shows API access enabled (unlimited)
- [ ] Progress bar reflects usage

### 1.4 Enterprise Tier Display ($1,999+/mo)
- [ ] QuotaWidget shows "Enterprise" tier label
- [ ] Shows unlimited scans indicator
- [ ] Shows unlimited files-per-scan
- [ ] Shows unlimited projects
- [ ] Shows unlimited API calls
- [ ] Shows unlimited team members
- [ ] No upgrade prompts shown

---

## 2. Scan Quota Enforcement

### 2.1 Developer Tier (3 scans/month - Free)
- [ ] First 3 scans succeed
- [ ] 4th scan blocked with 402 error
- [ ] Error message mentions quota exceeded
- [ ] Upgrade URL provided in error response (/pricing)
- [ ] UI shows quota exhausted state

### 2.2 Starter Tier (15 scans/month - $299/mo)
- [ ] Scans 1-15 succeed
- [ ] 16th scan blocked
- [ ] Error message appropriate for Starter tier
- [ ] Suggests upgrade to Growth

### 2.3 Growth Tier (50 scans/month - $699/mo)
- [ ] Scans 1-50 succeed
- [ ] 51st scan blocked
- [ ] Error message appropriate for Growth tier
- [ ] Suggests upgrade to Enterprise

### 2.4 Enterprise Tier (Unlimited - $1,999+/mo)
- [ ] Large number of scans succeed
- [ ] No quota limit applied
- [ ] monthly_scan_limit = -1 in database

---

## 3. Files-Per-Scan Limits

### 3.1 Developer Tier (Unlimited - Free)
- [ ] Large archive uploads successfully
- [ ] No file count limit applied
- [ ] max_files_per_scan = -1 in database

### 3.2 Starter/Growth/Enterprise Tier (Unlimited)
- [ ] Large archive uploads successfully
- [ ] No file count limit applied
- [ ] max_files_per_scan = -1 in database

### 3.3 Smart Dependency Extraction
- [ ] OpenZeppelin project (200+ files) extracts successfully
- [ ] Smart extraction works for all tiers
- [ ] Only imported files included in extraction

## 3b. Lines-of-Code Per Scan Limits

### 3b.1 Developer Tier (Unlimited - Free)
- [ ] Large codebases upload successfully
- [ ] No LoC limit applied
- [ ] max_loc_per_scan = -1 in database

### 3b.2 Starter/Growth/Enterprise (Unlimited)
- [ ] Large codebases upload successfully
- [ ] No LoC limit applied
- [ ] max_loc_per_scan = -1 in database

---

## 4. File Size Limits

### 4.1 Developer Tier (Free)
- [ ] Files have no per-file size limits in tiers.json
- [ ] Archive uploads succeed
- [ ] Error handling for oversized files

### 4.2 Starter Tier ($299/mo)
- [ ] Files have no per-file size limits in tiers.json
- [ ] Archive uploads succeed
- [ ] Error handling for oversized files

### 4.3 Growth Tier ($699/mo)
- [ ] Files have no per-file size limits in tiers.json
- [ ] Archive uploads succeed
- [ ] Error handling for oversized files

### 4.4 Enterprise Tier ($1,999+/mo)
- [ ] Files have no per-file size limits in tiers.json
- [ ] Archive uploads succeed
- [ ] Error handling for oversized files

---

## 5. Monthly/Annual Quota Reset

### 5.1 Monthly Subscribers
- [ ] Quota resets on first of month
- [ ] monthly_scans_used resets to 0
- [ ] monthly_api_calls_used resets to 0
- [ ] quota_reset_at updated to next month
- [ ] User can scan again after reset
- [ ] Reset logged/tracked correctly

### 5.2 Annual Subscribers
- [ ] Quota resets on subscription renewal date
- [ ] quota_reset_at aligns with subscription.current_period_end
- [ ] Counters reset on annual billing period
- [ ] Annual subscribers get monthly quotas renewed annually

### 5.3 Background Reset Task
- [ ] Scheduler runs hourly to check for resets
- [ ] Automatic reset for users past quota_reset_at
- [ ] Both monthly and annual intervals supported
- [ ] Reset statistics logged (monthly_reset, annual_reset counts)

---

## 6. Priority Queue (Tier-Based)

| Tier | Priority Value | Description |
|------|---------------|-------------|
| Enterprise | 5 | Highest priority |
| Growth | 15 | High priority |
| Starter | 30 | Medium priority |
| Developer | 50 | Normal priority |

- [ ] Enterprise scans processed first (priority 5)
- [ ] Growth scans processed second (priority 15)
- [ ] Starter scans processed third (priority 30)
- [ ] Developer scans processed last (priority 50)
- [ ] Queue order visible in scan status

---

## 7. Project Quota Enforcement

### 7.1 Developer Tier (3 projects max - Free)
- [ ] First 3 projects created successfully
- [ ] 4th project blocked with 403 error
- [ ] Error message shows quota and upgrade path
- [ ] UI reflects project count/limit

### 7.2 Starter Tier (10 projects max - $299/mo)
- [ ] Projects 1-10 created successfully
- [ ] 11th project blocked with 403 error
- [ ] Suggests upgrade to Growth

### 7.3 Growth Tier (Unlimited projects - $699/mo)
- [ ] Large number of projects succeed
- [ ] No project limit applied
- [ ] max_projects = -1 in database

### 7.4 Enterprise Tier (Unlimited - $1,999+/mo)
- [ ] Large number of projects succeed
- [ ] No project limit applied
- [ ] max_projects = -1 in database

### 7.5 Quota Exceeded Error Response (HTTP 403)
```json
{
  "detail": "Project quota exceeded. Your plan allows 3 projects (current: 3). Upgrade to Team for 10 projects or Growth for 25 projects."
}
```
- [ ] Error message includes current count
- [ ] Error message includes tier limit
- [ ] Upgrade guidance provided

---

## 8. API Call Quota Enforcement (New in Migration 024)

### 8.1 Developer Tier (0 API calls - Free)
- [ ] API requests return 403 "API access not available"
- [ ] Upgrade message suggests Growth tier (API access starts at Growth)
- [ ] API key creation blocked

### 8.2 Starter Tier (0 API calls - $299/mo)
- [ ] API requests return 403 "API access not available"
- [ ] Upgrade message suggests Growth tier
- [ ] API key creation blocked

### 8.3 Growth Tier (Unlimited API calls - $699/mo)
- [ ] API calls succeed without limits
- [ ] Counter tracks usage for analytics
- [ ] Full API access enabled
- [ ] No 429 rate limit responses for quota

### 8.4 Enterprise (Unlimited - $1,999+/mo)
- [ ] No API call limit
- [ ] monthly_api_calls_limit = -1 in database

### 8.5 API Call Tracking
- [ ] Each authenticated API request increments counter
- [ ] Counter visible in quota widget
- [ ] Resets monthly with other quotas

---

## 9. Team Seat Quota Enforcement (New in Migration 024)

### 9.1 Developer Tier (2 users - Free)
- [ ] Invites up to 1 succeed (plus owner = 2)
- [ ] 2nd invite blocked
- [ ] Current seat count shown
- [ ] Suggests upgrade to Starter

### 9.2 Starter Tier (5 users - $299/mo)
- [ ] Invites up to 4 succeed (plus owner = 5)
- [ ] 5th invite blocked
- [ ] Current seat count shown
- [ ] Suggests upgrade to Growth

### 9.3 Growth Tier (15 users - $699/mo)
- [ ] Invites up to 14 succeed (plus owner = 15)
- [ ] 15th invite blocked
- [ ] Suggests upgrade to Enterprise

### 9.4 Enterprise Tier (Unlimited - $1,999+/mo)
- [ ] No seat limit
- [ ] max_team_members = -1 in database

---

## 10. Export Feature Enforcement (NEW)

### 10.1 Developer Tier (Export Disabled - Free)
- [ ] Export buttons hidden or disabled
- [ ] Export API returns 403 error
- [ ] Error response includes upgrade URL
- [ ] Error message: "Export feature is not available on your current tier"

### 10.2 Starter/Growth/Enterprise (Export Enabled)
- [ ] Export buttons visible and functional
- [ ] PDF export works
- [ ] JSON export works
- [ ] export_enabled = true in database

### 10.3 Export API Error Response (HTTP 403)
```json
{
  "detail": {
    "error": "export_not_available",
    "message": "Export feature is not available on your current tier. Upgrade to Team or higher to export reports.",
    "tier": "developer",
    "upgrade_url": "/pricing"
  }
}
```

---

## Test Notes

_Record quota test results here:_

```
[Date] | [Test] | [Tier] | [Result] | [Notes]
```
