# Error Handling & Edge Cases Tests

**Priority**: P2 - Medium
**Last Tested**: _Not yet tested_

---

## 1. Upload Errors

### 1.1 File Type Errors (400)
- [ ] .js file rejected
- [ ] .py file rejected
- [ ] .txt file rejected
- [ ] .exe file rejected
- [ ] Error message lists allowed extensions
- [ ] Error message shows received extension

### 1.2 File Size Errors (413)
- [ ] Single file over limit rejected
- [ ] Archive over limit rejected
- [ ] Error shows file size
- [ ] Error shows tier limit
- [ ] Error shows current tier
- [ ] Upgrade suggestion included

### 1.3 File Count Errors (402)
- [ ] Archive with too many files rejected
- [ ] Error shows file count
- [ ] Error shows tier limit
- [ ] Upgrade URL provided

### 1.4 Archive Errors
- [ ] Empty archive rejected
- [ ] Corrupted ZIP rejected
- [ ] Corrupted TAR rejected
- [ ] Non-UTF-8 content handled
- [ ] Zip bomb protection (if implemented)

### 1.5 Quota Errors (402)
- [ ] Scan when quota exhausted
- [ ] Error shows "quota_exceeded"
- [ ] Error shows scans remaining (0)
- [ ] Upgrade URL provided
- [ ] Next reset date shown (if available)

---

## 2. Authentication Errors

### 2.1 Unauthorized (401)
- [ ] Upload without token
- [ ] Scan without token
- [ ] Projects without token
- [ ] Error message clear
- [ ] Redirect to login (UI)

### 2.2 Forbidden (403)
- [ ] Access other user's contract
- [ ] Edit other user's project
- [ ] Delete other user's resource
- [ ] Error distinguishes from 404

### 2.3 Token Errors
- [ ] Expired token rejected
- [ ] Invalid token rejected
- [ ] Malformed token rejected

---

## 3. Resource Errors

### 3.1 Not Found (404)
- [ ] Non-existent contract ID
- [ ] Non-existent scan ID
- [ ] Non-existent project ID
- [ ] Invalid UUID format handled

### 3.2 Conflict Errors
- [ ] Duplicate resource creation (if applicable)
- [ ] Concurrent modification (if applicable)

---

## 4. Scan Errors

### 4.1 Scanner Errors
- [ ] Scanner timeout handled
- [ ] Scanner crash handled
- [ ] Partial results saved
- [ ] Error logged for debugging
- [ ] User sees meaningful error

### 4.2 Contract Errors
- [ ] Contract with syntax errors
- [ ] Contract with compilation errors
- [ ] Missing imports in contract
- [ ] Error details shown to user

---

## 5. Framework Detection Edge Cases

### 5.1 Config Parsing Errors
- [ ] Malformed foundry.toml handled
- [ ] Malformed hardhat.config.js handled
- [ ] Empty config file handled
- [ ] Falls back to "plain" on error

### 5.2 Import Resolution Edge Cases
- [ ] Missing remapping logged
- [ ] Missing dependency logged
- [ ] Scan continues despite missing deps
- [ ] Warning shown to user

### 5.3 Circular Imports
- [ ] A imports B, B imports A
- [ ] Deep circular chains
- [ ] No infinite loop
- [ ] Both files extracted once

---

## 6. Archive Edge Cases

### 6.1 Path Edge Cases
- [ ] Very long file paths
- [ ] Unicode characters in paths
- [ ] Spaces in paths
- [ ] Special characters in paths

### 6.2 Directory Edge Cases
- [ ] Very deep nesting (10+ levels)
- [ ] Empty directories ignored
- [ ] Symbolic links handled (or rejected)

### 6.3 Content Edge Cases
- [ ] Very large single file
- [ ] Many small files
- [ ] Binary files in archive (ignored)
- [ ] Mixed encodings

---

## 7. Rate Limiting

- [ ] Too many requests returns 429
- [ ] Retry-After header present
- [ ] Rate limit by IP and/or user
- [ ] Different limits per endpoint

---

## 8. Input Validation

### 8.1 Contract Name
- [ ] Very long name truncated/rejected
- [ ] Special characters handled
- [ ] Empty name uses default
- [ ] XSS attempts sanitized

### 8.2 Project Name
- [ ] Very long name handled
- [ ] Special characters handled
- [ ] Required field enforced

### 8.3 Query Parameters
- [ ] Invalid page number handled
- [ ] Negative limit handled
- [ ] SQL injection attempts blocked

---

## 9. Database Errors

- [ ] Connection failure handled gracefully
- [ ] Transaction rollback on error
- [ ] User sees generic error (not SQL details)
- [ ] Error logged for debugging

---

## 10. Graceful Degradation

- [ ] Scanner service down - informative error
- [ ] Database slow - timeout handled
- [ ] External service down - fallback behavior
- [ ] Partial failure - save what's possible

---

## 11. Error Message Quality

### 11.1 User-Friendly Messages
- [ ] No technical jargon
- [ ] Clear action to take
- [ ] Contact support option
- [ ] No sensitive info leaked

### 11.2 Developer-Friendly (API)
- [ ] Consistent error format
- [ ] Error codes for programmatic handling
- [ ] Helpful messages in detail
- [ ] Request ID for support tickets

---

## Test Scenarios

### Scenario: Free Tier Hitting Limits
1. Upload 10 contracts (quota limit)
2. Try 11th upload
3. Verify 402 error
4. Verify upgrade message

### Scenario: Large OpenZeppelin Project
1. Create project with 200+ OZ files
2. Upload as Free tier
3. Verify smart filtering activates
4. Verify <25 files extracted

### Scenario: Corrupted Archive
1. Create intentionally corrupted ZIP
2. Upload
3. Verify clear error message
4. Verify no server crash

---

## Test Notes

_Record error handling test results here:_

```
[Date] | [Error Type] | [Scenario] | [Result] | [Notes]
```
