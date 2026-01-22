# Quota System Tests

**Priority**: P0 - Critical
**Last Updated**: January 11, 2026
**Related**: Phase 3.1a Freemium Auth, Migration 024, Migration 030
**Source of Truth**: `/docs/standards/tier-standards.md`

---

## Tier Reference (Updated January 2026 - 4-Tier Model)

| Tier | Price | Scans/Mo | Files/Scan | LoC/Scan | Projects | Single File | Archive | API Calls | Team |
|------|-------|----------|------------|----------|----------|-------------|---------|-----------|------|
| Developer | $0 | 10 | 5 | 5,000 | 3 | 1 MB | 5 MB | 0 | 1 |
| Team | $299/mo | 100 | Unlimited | Unlimited | 10 | 5 MB | 25 MB | 1,000 | 5 |
| Growth | $699/mo | 500 | Unlimited | Unlimited | 25 | 10 MB | 50 MB | 10,000 | 15 |
| Enterprise | $1,999+/mo | Unlimited | Unlimited | Unlimited | Unlimited | 20 MB | 100 MB | Unlimited | Unlimited |

**Note:** 4-tier pricing model effective January 2026. Developer tier (formerly free) includes 10 scans/month. API access available on Growth tier and above.

---

## 1. Quota Widget Display

### 1.1 Developer Tier Display (Free - $0/mo)
- [ ] QuotaWidget shows "Developer" tier label
- [ ] Shows scans used / 10 max
- [ ] Shows files-per-scan limit (5)
- [ ] Shows LoC-per-scan limit (5,000)
- [ ] Shows projects used / 3 max
- [ ] Shows "No API access" for API calls
- [ ] Shows "Export disabled" indicator
- [ ] Shows upgrade prompt
- [ ] Progress bar reflects usage
- [ ] Shows "Solo developer" for team (1 user)

### 1.2 Team Tier Display ($299/mo)
- [ ] QuotaWidget shows "Team" tier label
- [ ] Shows scans used / 100 max
- [ ] Shows unlimited files-per-scan
- [ ] Shows projects used / 10 max
- [ ] Shows API calls used / 1,000 max
- [ ] Shows team members used / 5 max
- [ ] Shows export enabled
- [ ] Progress bar reflects usage

### 1.3 Growth Tier Display ($699/mo)
- [ ] QuotaWidget shows "Growth" tier label
- [ ] Shows scans used / 500 max
- [ ] Shows unlimited files-per-scan
- [ ] Shows projects used / 25 max
- [ ] Shows API calls used / 10,000 max
- [ ] Shows team members used / 15 max
- [ ] Shows API access enabled
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

### 2.1 Developer Tier (10 scans/month - Free)
- [ ] First 10 scans succeed
- [ ] 11th scan blocked with 402 error
- [ ] Error message mentions quota exceeded
- [ ] Upgrade URL provided in error response (/pricing)
- [ ] UI shows quota exhausted state

### 2.2 Team Tier (100 scans/month - $299/mo)
- [ ] Scans 1-100 succeed
- [ ] 101st scan blocked
- [ ] Error message appropriate for Team tier
- [ ] Suggests upgrade to Growth

### 2.3 Growth Tier (500 scans/month - $699/mo)
- [ ] Scans 1-500 succeed
- [ ] 501st scan blocked
- [ ] Error message appropriate for Growth tier
- [ ] Suggests upgrade to Enterprise

### 2.4 Enterprise Tier (Unlimited - $1,999+/mo)
- [ ] Large number of scans succeed
- [ ] No quota limit applied
- [ ] monthly_scan_limit = -1 in database

---

## 3. Files-Per-Scan Limits

### 3.1 Developer Tier (5 files max - Free)
- [ ] Archive with 5 files uploads successfully
- [ ] Archive with 6+ files shows 402 error
- [ ] Error shows file count and limit
- [ ] Upgrade message shown

### 3.2 Team/Growth/Enterprise Tier (Unlimited)
- [ ] Large archive uploads successfully
- [ ] No file count limit applied
- [ ] max_files_per_scan = -1 in database

### 3.3 Smart Dependency Extraction
- [ ] OpenZeppelin project (200+ files) extracts to <5 files for Developer tier
- [ ] Smart extraction respects tier limits
- [ ] Only imported files count toward limit

## 3b. Lines-of-Code Per Scan Limits (NEW)

### 3b.1 Developer Tier (5,000 LoC max - Free)
- [ ] Code under 5,000 LoC uploads successfully
- [ ] Code over 5,000 LoC shows 402 error
- [ ] Error shows total LoC and limit
- [ ] Upgrade message suggests Team tier

### 3b.2 Team/Growth/Enterprise (Unlimited)
- [ ] Large codebases upload successfully
- [ ] No LoC limit applied
- [ ] max_loc_per_scan = -1 in database

---

## 4. File Size Limits

### 4.1 Developer Tier (Free)
- [ ] Single file up to 1 MB succeeds
- [ ] Single file over 1 MB shows 413 error
- [ ] Archive up to 5 MB succeeds
- [ ] Archive over 5 MB shows 413 error
- [ ] Error shows tier and limit info

### 4.2 Team Tier ($299/mo)
- [ ] Single file up to 5 MB succeeds
- [ ] Archive up to 25 MB succeeds
- [ ] Oversized files show appropriate error

### 4.3 Growth Tier ($699/mo)
- [ ] Single file up to 10 MB succeeds
- [ ] Archive up to 50 MB succeeds

### 4.4 Enterprise Tier ($1,999+/mo)
- [ ] Single file up to 20 MB succeeds
- [ ] Archive up to 100 MB succeeds

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
| Team | 30 | Medium priority |
| Developer | 50 | Normal priority |

- [ ] Enterprise scans processed first (priority 5)
- [ ] Growth scans processed second (priority 15)
- [ ] Team scans processed third (priority 30)
- [ ] Developer scans processed last (priority 50)
- [ ] Queue order visible in scan status

---

## 7. Project Quota Enforcement

### 7.1 Developer Tier (3 projects max - Free)
- [ ] First 3 projects created successfully
- [ ] 4th project blocked with 403 error
- [ ] Error message shows quota and upgrade path
- [ ] UI reflects project count/limit

### 7.2 Team Tier (10 projects max - $299/mo)
- [ ] Projects 1-10 created successfully
- [ ] 11th project blocked with 403 error
- [ ] Suggests upgrade to Growth

### 7.3 Growth Tier (25 projects max - $699/mo)
- [ ] Projects 1-25 created successfully
- [ ] 26th project blocked with 403 error
- [ ] Suggests upgrade to Enterprise

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

### 8.2 Team Tier (1,000 calls/month - $299/mo)
- [ ] API calls 1-1,000 succeed
- [ ] 1,001st call returns 429 error
- [ ] Counter increments per request
- [ ] Suggests upgrade to Growth

### 8.3 Growth Tier (10,000 calls/month - $699/mo)
- [ ] API calls 1-10,000 succeed
- [ ] 10,001st call returns 429 error
- [ ] Suggests upgrade to Enterprise
- [ ] Full API access enabled

### 8.4 Enterprise (Unlimited - $1,999+/mo)
- [ ] No API call limit
- [ ] monthly_api_calls_limit = -1 in database

### 8.5 API Call Tracking
- [ ] Each authenticated API request increments counter
- [ ] Counter visible in quota widget
- [ ] Resets monthly with other quotas

---

## 9. Team Seat Quota Enforcement (New in Migration 024)

### 9.1 Developer Tier (1 user - Free)
- [ ] No invite option shown
- [ ] Solo user only
- [ ] Upgrade prompt for team features

### 9.2 Team Tier (5 users - $299/mo)
- [ ] Invites 1-4 succeed (plus owner = 5)
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

### 10.2 Team/Growth/Enterprise (Export Enabled)
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
