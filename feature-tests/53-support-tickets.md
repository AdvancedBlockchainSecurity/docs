# Feature Test: Support Ticket System

**Feature ID:** 53
**Date:** February 1, 2026
**Status:** Implemented
**Version:** API v0.22.0, Dashboard v0.37.0

## Overview

The support ticket system allows authenticated users to submit support requests directly from the dashboard. Tickets are stored in the database and optionally synchronized to JIRA Cloud for support team management.

## Test Scenarios

### 1. Access Support Ticket Modal

**Preconditions:**
- User is logged in to the dashboard

**Steps:**
1. Navigate to any dashboard page
2. Look for "Get Help" button in the sidebar footer
3. Click "Get Help" button

**Expected Results:**
- Support ticket modal opens
- Modal displays category dropdown, priority dropdown, subject field, description field
- Submit button is visible

**Status:** PASS

---

### 2. Submit Support Ticket - All Categories

**Preconditions:**
- User is logged in
- Support ticket modal is open

**Test Data:**

| Category | Priority | Subject | Description |
|----------|----------|---------|-------------|
| bug | high | Scan fails on large contracts | When uploading contracts with more than 50 files, the scan process times out after 5 minutes. |
| billing | medium | Question about annual pricing | I'd like to understand the difference between monthly and annual billing options. |
| feature_request | low | Support for Move language | Would be great to have support for Aptos Move smart contracts. |
| security | urgent | Potential data exposure | I noticed my scan results are visible to another user. |
| general | medium | Integration question | How do I integrate the scanner with my GitLab CI pipeline? |

**Steps:**
1. Select category from dropdown
2. Select priority from dropdown
3. Enter subject (minimum 5 characters)
4. Enter description (minimum 20 characters)
5. Click "Submit"

**Expected Results:**
- Success message displayed
- Ticket reference number shown (format: BSO-XXXXXXXX)
- Modal shows confirmation view
- If JIRA enabled: JIRA issue link displayed

**Status:** PASS

---

### 3. Validation - Subject Too Short

**Steps:**
1. Open support ticket modal
2. Enter subject with fewer than 5 characters (e.g., "Bug")
3. Enter valid description
4. Click Submit

**Expected Results:**
- Form validation error shown
- Submit prevented
- Error message: "Subject must be at least 5 characters"

**Status:** PASS

---

### 4. Validation - Description Too Short

**Steps:**
1. Open support ticket modal
2. Enter valid subject
3. Enter description with fewer than 20 characters
4. Click Submit

**Expected Results:**
- Form validation error shown
- Submit prevented
- Error message: "Description must be at least 20 characters"

**Status:** PASS

---

### 5. Rate Limiting

**Preconditions:**
- User has submitted 5 tickets today

**Steps:**
1. Open support ticket modal
2. Fill out valid ticket data
3. Click Submit

**Expected Results:**
- HTTP 429 response
- Error message displayed: "Daily ticket limit reached. Please try again tomorrow."
- User can still view the modal but cannot submit

**Status:** PASS

---

### 6. Auto-Capture Page URL

**Steps:**
1. Navigate to a specific page (e.g., /scans/abc-123)
2. Open support ticket modal
3. Submit a ticket

**Expected Results:**
- Ticket is stored with `page_url` field populated
- URL matches the page user was on when opening modal

**Status:** PASS

---

### 7. Authentication Required

**Preconditions:**
- User is not logged in

**Test via API:**
```bash
curl -X POST http://app.blocksecops.local/api/v1/support-tickets \
  -H "Content-Type: application/json" \
  -d '{"category":"bug","priority":"medium","subject":"Test","description":"Test description for validation."}'
```

**Expected Results:**
- HTTP 401 Unauthorized
- Error message about missing authentication

**Status:** PASS

---

### 8. JIRA Integration - Enabled

**Preconditions:**
- JIRA integration is configured via environment variables
- User submits a ticket

**Expected Results:**
- JIRA issue created in configured project
- `jira_issue_key` populated (e.g., SUPPORT-123)
- `jira_issue_url` populated
- `jira_sync_status` = 'synced'
- User sees JIRA link in confirmation

**Status:** PASS (when configured)

---

### 9. JIRA Integration - Disabled

**Preconditions:**
- JIRA integration is NOT configured (SUPPORT_JIRA_ENABLED=false)

**Expected Results:**
- Ticket stored in database
- `jira_sync_status` = 'disabled'
- `jira_issue_key` = null
- User sees only ticket reference number (no JIRA link)

**Status:** PASS

---

### 10. JIRA Integration - API Failure

**Preconditions:**
- JIRA integration is configured but JIRA API is unavailable

**Expected Results:**
- Ticket stored in database
- `jira_sync_status` = 'failed'
- User still sees success with ticket reference
- Error logged for retry

**Status:** PASS

---

## API Test Commands

### Submit Ticket (Authenticated)

```bash
# Get auth token
TOKEN=$(curl -s -X POST http://app.blocksecops.local/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}' | jq -r '.access_token')

# Submit ticket
curl -X POST http://app.blocksecops.local/api/v1/support-tickets \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "category": "bug",
    "priority": "high",
    "subject": "Test support ticket",
    "description": "This is a test support ticket submission to verify the feature works correctly."
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "ticket_id": "550e8400-e29b-41d4-a716-446655440000",
  "ticket_reference": "BSO-A1B2C3D4",
  "jira_issue_key": null,
  "jira_issue_url": null,
  "message": "Support ticket submitted successfully"
}
```

### Check Rate Limit

Submit 6 tickets in a row:
```bash
for i in {1..6}; do
  curl -s -X POST http://app.blocksecops.local/api/v1/support-tickets \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"category\":\"general\",\"priority\":\"low\",\"subject\":\"Rate limit test $i\",\"description\":\"Testing rate limiting functionality ticket number $i.\"}" | jq -r '.success // .detail'
done
```

**Expected:** First 5 return `true`, 6th returns rate limit error.

---

## Database Verification

```sql
-- Check recent tickets
SELECT id, category, priority, subject, jira_sync_status, created_at
FROM support_tickets
ORDER BY created_at DESC
LIMIT 10;

-- Check rate limit (tickets per user per day)
SELECT user_id, COUNT(*) as tickets_today
FROM support_tickets
WHERE created_at >= CURRENT_DATE
GROUP BY user_id;

-- Check JIRA sync status distribution
SELECT jira_sync_status, COUNT(*)
FROM support_tickets
GROUP BY jira_sync_status;
```

---

## Configuration Reference

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SUPPORT_JIRA_ENABLED` | Enable JIRA integration | `false` |
| `SUPPORT_JIRA_BASE_URL` | JIRA instance URL | - |
| `SUPPORT_JIRA_API_EMAIL` | JIRA API user email | - |
| `SUPPORT_JIRA_API_TOKEN` | JIRA API token | - |
| `SUPPORT_JIRA_PROJECT_KEY` | Target JIRA project | - |

### Category-to-JIRA Mapping

| Category | JIRA Label |
|----------|------------|
| bug | `bug`, `user-reported` |
| billing | `billing`, `user-reported` |
| feature_request | `feature-request`, `user-reported` |
| security | `security`, `user-reported`, `priority-review` |
| general | `general`, `user-reported` |

### Priority Mapping

| User Priority | JIRA Priority |
|---------------|---------------|
| low | Lowest |
| medium | Medium |
| high | High |
| urgent | Highest |

---

## Known Limitations

1. **No ticket history page** - Users cannot view past tickets (by design)
2. **Rate limit is per calendar day** - Resets at midnight UTC
3. **JIRA sync is synchronous** - May add latency to ticket submission
4. **No file attachments** - Screenshots/files not supported in initial release

## Future Enhancements

- Ticket status tracking
- Email notifications on ticket updates
- File attachment support
- Ticket history page (optional)
- Admin view of all tickets
