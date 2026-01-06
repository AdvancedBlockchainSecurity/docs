# Quota System Tests

**Priority**: P0 - Critical
**Last Updated**: January 3, 2026
**Related**: Phase 3.1a Freemium Auth, Migration 024

---

## Tier Reference (Updated January 2026)

| Tier | Scans/Mo | Files/Scan | Projects | Single File | Archive | API Calls | Team |
|------|----------|------------|----------|-------------|---------|-----------|------|
| Free | 10 | 25 | 3 | 1 MB | 5 MB | 0 | 1 |
| Developer | 100 | 50 | 5 | 5 MB | 25 MB | 1,000 | 1 |
| Startup | 500 | 100 | 20 | 10 MB | 50 MB | 10,000 | 10 |
| Professional | Unlimited | Unlimited | Unlimited | 10 MB | 50 MB | Unlimited | 25 |
| Enterprise | Unlimited | Unlimited | Unlimited | 20 MB | 100 MB | Unlimited | Unlimited |

---

## 1. Quota Widget Display

### 1.1 Free Tier Display
- [ ] QuotaWidget shows "Free" tier label
- [ ] Shows scans used / 10 max
- [ ] Shows files-per-scan limit (25)
- [ ] Shows projects used / 3 max
- [ ] Shows "No API access" for API calls
- [ ] Shows upgrade prompt
- [ ] Progress bar reflects usage

### 1.2 Developer Tier Display
- [ ] QuotaWidget shows "Developer" tier label
- [ ] Shows scans used / 100 max
- [ ] Shows files-per-scan limit (50)
- [ ] Shows projects used / 5 max
- [ ] Shows API calls used / 1,000 max
- [ ] Shows "Solo developer" for team (1 user)
- [ ] Progress bar reflects usage

### 1.3 Startup Tier Display
- [ ] QuotaWidget shows "Startup" tier label
- [ ] Shows scans used / 500 max
- [ ] Shows files-per-scan limit (100)
- [ ] Shows projects used / 20 max
- [ ] Shows API calls used / 10,000 max
- [ ] Shows team members used / 10 max
- [ ] Progress bar reflects usage

### 1.4 Professional Tier Display
- [ ] QuotaWidget shows "Professional" tier label
- [ ] Shows unlimited scans indicator
- [ ] Shows unlimited files-per-scan
- [ ] Shows unlimited projects
- [ ] Shows unlimited API calls
- [ ] Shows team members used / 25 max
- [ ] No scan/project upgrade prompt

### 1.5 Enterprise Tier Display
- [ ] QuotaWidget shows "Enterprise" tier label
- [ ] Shows unlimited everything
- [ ] Shows unlimited team members
- [ ] No upgrade prompts shown

---

## 2. Scan Quota Enforcement

### 2.1 Free Tier (10 scans/month)
- [ ] First 10 scans succeed
- [ ] 11th scan blocked with 402 error
- [ ] Error message mentions quota exceeded
- [ ] Upgrade URL provided in error response
- [ ] UI shows quota exhausted state

### 2.2 Developer Tier (100 scans/month)
- [ ] Scans 1-100 succeed
- [ ] 101st scan blocked
- [ ] Error message appropriate for Developer tier
- [ ] Suggests upgrade to Startup

### 2.3 Startup Tier (500 scans/month)
- [ ] Scans 1-500 succeed
- [ ] 501st scan blocked
- [ ] Error message appropriate for Startup tier
- [ ] Suggests upgrade to Professional

### 2.4 Professional Tier (Unlimited)
- [ ] Large number of scans succeed
- [ ] No quota limit applied
- [ ] monthly_scan_limit = -1 in database

### 2.5 Enterprise Tier (Unlimited)
- [ ] Large number of scans succeed
- [ ] No quota limit applied
- [ ] monthly_scan_limit = -1 in database

---

## 3. Files-Per-Scan Limits

### 3.1 Free Tier (25 files max)
- [ ] Archive with 25 files uploads successfully
- [ ] Archive with 26+ files shows 402 error
- [ ] Error shows file count and limit
- [ ] Upgrade message shown

### 3.2 Developer Tier (50 files max)
- [ ] Archive with 50 files uploads successfully
- [ ] Archive with 51+ files shows error

### 3.3 Startup Tier (100 files max)
- [ ] Archive with 100 files uploads successfully
- [ ] Archive with 101+ files shows error

### 3.4 Professional/Enterprise Tier (Unlimited)
- [ ] Large archive uploads successfully
- [ ] No file count limit applied

### 3.5 Smart Dependency Extraction
- [ ] OpenZeppelin project (200+ files) extracts to <25 files
- [ ] Free tier can upload OpenZeppelin projects
- [ ] Only imported files count toward limit

---

## 4. File Size Limits

### 4.1 Free Tier
- [ ] Single file up to 1 MB succeeds
- [ ] Single file over 1 MB shows 413 error
- [ ] Archive up to 5 MB succeeds
- [ ] Archive over 5 MB shows 413 error
- [ ] Error shows tier and limit info

### 4.2 Developer Tier
- [ ] Single file up to 5 MB succeeds
- [ ] Archive up to 25 MB succeeds
- [ ] Oversized files show appropriate error

### 4.3 Startup Tier
- [ ] Single file up to 10 MB succeeds
- [ ] Archive up to 50 MB succeeds

### 4.4 Professional Tier
- [ ] Single file up to 10 MB succeeds
- [ ] Archive up to 50 MB succeeds

### 4.5 Enterprise Tier
- [ ] Single file up to 20 MB succeeds
- [ ] Archive up to 100 MB succeeds

---

## 5. Monthly Quota Reset

- [ ] Quota resets on first of month
- [ ] monthly_scans_used resets to 0
- [ ] monthly_api_calls_used resets to 0
- [ ] User can scan again after reset
- [ ] Reset logged/tracked correctly

---

## 6. Priority Queue (Tier-Based)

| Tier | Priority Value | Description |
|------|---------------|-------------|
| Enterprise | 5 | Highest priority |
| Professional | 10 | High priority |
| Startup | 25 | Medium priority |
| Developer | 40 | Normal priority |
| Free | 50 | Lowest priority |

- [ ] Enterprise scans processed first (priority 5)
- [ ] Professional scans processed second (priority 10)
- [ ] Startup scans processed third (priority 25)
- [ ] Developer scans processed fourth (priority 40)
- [ ] Free scans processed last (priority 50)
- [ ] Queue order visible in scan status

---

## 7. Project Quota Enforcement

### 7.1 Free Tier (3 projects max)
- [ ] First 3 projects created successfully
- [ ] 4th project blocked with 403 error
- [ ] Error message shows quota and upgrade path
- [ ] UI reflects project count/limit

### 7.2 Developer Tier (5 projects max)
- [ ] Projects 1-5 created successfully
- [ ] 6th project blocked with 403 error
- [ ] Suggests upgrade to Startup

### 7.3 Startup Tier (20 projects max)
- [ ] Projects 1-20 created successfully
- [ ] 21st project blocked with 403 error
- [ ] Suggests upgrade to Professional

### 7.4 Professional/Enterprise Tier (Unlimited)
- [ ] Large number of projects succeed
- [ ] No project limit applied
- [ ] max_projects = -1 in database

### 7.5 Quota Exceeded Error Response (HTTP 403)
```json
{
  "detail": "Project quota exceeded. Your plan allows 3 projects (current: 3). Upgrade to Developer for 5 projects or Startup for 20 projects."
}
```
- [ ] Error message includes current count
- [ ] Error message includes tier limit
- [ ] Upgrade guidance provided

---

## 8. API Call Quota Enforcement (New in Migration 024)

### 8.1 Free Tier (0 API calls)
- [ ] API requests return 403 "API access not available"
- [ ] Upgrade message suggests Developer tier
- [ ] API key creation blocked

### 8.2 Developer Tier (1,000 calls/month)
- [ ] API calls 1-1,000 succeed
- [ ] 1,001st call returns 429 error
- [ ] Counter increments per request
- [ ] Suggests upgrade to Startup

### 8.3 Startup Tier (10,000 calls/month)
- [ ] API calls 1-10,000 succeed
- [ ] 10,001st call returns 429 error
- [ ] Suggests upgrade to Professional

### 8.4 Professional/Enterprise (Unlimited)
- [ ] No API call limit
- [ ] monthly_api_calls_limit = -1 in database

### 8.5 API Call Tracking
- [ ] Each authenticated API request increments counter
- [ ] Counter visible in quota widget
- [ ] Resets monthly with other quotas

---

## 9. Team Seat Quota Enforcement (New in Migration 024)

### 9.1 Free/Developer Tier (1 user)
- [ ] No invite option shown
- [ ] Solo user only
- [ ] Upgrade prompt for team features

### 9.2 Startup Tier (10 users)
- [ ] Invites 1-9 succeed (plus owner = 10)
- [ ] 10th invite blocked
- [ ] Current seat count shown
- [ ] Suggests upgrade to Professional

### 9.3 Professional Tier (25 users)
- [ ] Invites up to 24 succeed (plus owner = 25)
- [ ] 25th invite blocked
- [ ] Suggests upgrade to Enterprise

### 9.4 Enterprise Tier (Unlimited)
- [ ] No seat limit
- [ ] max_team_members = -1 in database

---

## Test Notes

_Record quota test results here:_

```
[Date] | [Test] | [Tier] | [Result] | [Notes]
```
