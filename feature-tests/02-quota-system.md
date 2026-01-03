# Quota System Tests

**Priority**: P0 - Critical
**Last Tested**: _Not yet tested_
**Related**: Phase 3.1a Freemium Auth

---

## 1. Quota Widget Display

### 1.1 Free Tier Display
- [ ] QuotaWidget shows "Free" tier label
- [ ] Shows scans used / 10 max
- [ ] Shows files-per-scan limit (25)
- [ ] Shows upgrade prompt
- [ ] Progress bar reflects usage

### 1.2 Pro Tier Display
- [ ] QuotaWidget shows "Pro" tier label
- [ ] Shows scans used / 100 max
- [ ] Shows files-per-scan limit (100)
- [ ] Progress bar reflects usage

### 1.3 Enterprise Tier Display
- [ ] QuotaWidget shows "Enterprise" tier label
- [ ] Shows unlimited scans
- [ ] Shows unlimited files-per-scan
- [ ] No upgrade prompt shown

---

## 2. Scan Quota Enforcement

### 2.1 Free Tier (10 scans/month)
- [ ] First 10 scans succeed
- [ ] 11th scan blocked with 402 error
- [ ] Error message mentions quota exceeded
- [ ] Upgrade URL provided in error response
- [ ] UI shows quota exhausted state

### 2.2 Pro Tier (100 scans/month)
- [ ] Scans 1-100 succeed
- [ ] 101st scan blocked
- [ ] Error message appropriate for Pro tier

### 2.3 Enterprise Tier (Unlimited)
- [ ] Large number of scans succeed
- [ ] No quota limit applied

---

## 3. Files-Per-Scan Limits

### 3.1 Free Tier (25 files max)
- [ ] Archive with 25 files uploads successfully
- [ ] Archive with 26+ files shows 402 error
- [ ] Error shows file count and limit
- [ ] Upgrade message shown

### 3.2 Pro Tier (100 files max)
- [ ] Archive with 100 files uploads successfully
- [ ] Archive with 101+ files shows error

### 3.3 Enterprise Tier (Unlimited)
- [ ] Large archive uploads successfully
- [ ] No file count limit applied

### 3.4 Smart Dependency Extraction
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

### 4.2 Pro Tier
- [ ] Single file up to 5 MB succeeds
- [ ] Archive up to 25 MB succeeds
- [ ] Oversized files show appropriate error

### 4.3 Enterprise Tier
- [ ] Single file up to 10 MB succeeds
- [ ] Archive up to 50 MB succeeds

---

## 5. Monthly Quota Reset

- [ ] Quota resets on first of month
- [ ] scans_used resets to 0
- [ ] User can scan again after reset
- [ ] Reset logged/tracked correctly

---

## 6. Priority Queue (Tier-Based)

- [ ] Enterprise scans processed first (priority 1)
- [ ] Pro scans processed second (priority 2)
- [ ] Free scans processed last (priority 3)
- [ ] Queue order visible in scan status

---

## 7. Project Quota Enforcement (January 2026)

### 7.1 Free Tier (3 projects max)
- [ ] First 3 projects created successfully
- [ ] 4th project blocked with 403 error
- [ ] Error message shows quota and upgrade path
- [ ] UI reflects project count/limit

### 7.2 Pro Tier (10 projects max)
- [ ] Projects 1-10 created successfully
- [ ] 11th project blocked with 403 error
- [ ] Error message appropriate for Pro tier

### 7.3 Enterprise Tier (Unlimited)
- [ ] Large number of projects succeed
- [ ] No project limit applied
- [ ] max_projects = -1 in database

### 7.4 Quota Exceeded Error Response (HTTP 403)
```json
{
  "detail": "Project quota exceeded. Your plan allows 3 projects (current: 3). Upgrade to Pro for 10 projects or Enterprise for unlimited."
}
```
- [ ] Error message includes current count
- [ ] Error message includes tier limit
- [ ] Upgrade guidance provided

---

## Tier Limits Reference

| Tier | Scans/Month | Files/Scan | Projects | Single File | Archive |
|------|-------------|------------|----------|-------------|---------|
| Free | 10 | 25 | 3 | 1 MB | 5 MB |
| Pro | 100 | 100 | 10 | 5 MB | 25 MB |
| Enterprise | Unlimited | Unlimited | Unlimited | 10 MB | 50 MB |

---

## Test Notes

_Record quota test results here:_

```
[Date] | [Test] | [Tier] | [Result] | [Notes]
```
