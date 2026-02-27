# Feature Test: Support Ticket System

**Feature ID:** 53
**Date:** February 1, 2026
**Status:** Implemented
**Version:** API v0.26.1, Dashboard v0.39.1

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
curl -X POST http://app.0xapogee.local/api/v1/support-tickets \
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
TOKEN=$(curl -s -X POST http://app.0xapogee.local/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}' | jq -r '.access_token')

# Submit ticket
curl -X POST http://app.0xapogee.local/api/v1/support-tickets \
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
  curl -s -X POST http://app.0xapogee.local/api/v1/support-tickets \
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

## Support Tickets Page (List & Detail)

### 11. Access Support Tickets Page

**Preconditions:**
- User is logged in

**Steps:**
1. Click "Support Tickets" in the sidebar (ADMIN section)
2. Or navigate directly to `/support`

**Expected Results:**
- Support Tickets page loads
- Shows stats bar with Total, Open, In Progress, Resolved counts
- Shows status filter tabs (All, Open, In Progress, Resolved, Closed)
- Shows data table with user's tickets
- "Submit New Ticket" button visible in header

**Status:** PASS

---

### 12. Support Ticket List - Pagination

**Steps:**
1. Navigate to `/support`
2. Verify ticket list shows up to 20 items per page
3. If >20 tickets, check pagination controls at bottom
4. Click page 2

**Expected Results:**
- Page 1 shows first 20 tickets (newest first)
- Pagination shows current page and total pages
- Page 2 loads next set of tickets
- URL does not change (client-side state)

**Status:** PASS

---

### 13. Support Ticket List - Status Filter

**Steps:**
1. Navigate to `/support`
2. Click "Open" filter tab
3. Verify only open tickets shown
4. Click "In Progress" tab
5. Click "All" tab

**Expected Results:**
- Each filter shows only tickets with matching status
- "All" shows all tickets regardless of status
- Stats bar always shows total counts (not filtered counts)
- Active filter tab is visually highlighted

**Status:** PASS

---

### 14. Support Ticket List - Table Columns

**Steps:**
1. Navigate to `/support`
2. Examine table columns

**Expected Results:**
- Columns: Reference, Subject, Category, Priority, Status, JIRA, Created
- Reference format: BSO-XXXXXXXX
- Priority shows colored badge (urgent=red, high=orange, medium=yellow, low=gray)
- Status shows colored badge (open=blue, in_progress=yellow, resolved=green, closed=gray)
- JIRA column shows link to JIRA issue (or "-" if not synced)
- Created shows relative time (e.g., "2 days ago")

**Status:** PASS

---

### 15. Support Ticket Detail - Expandable Row

**Steps:**
1. Navigate to `/support`
2. Click on a ticket row
3. View expanded detail section

**Expected Results:**
- Row expands to show ticket detail below
- Shows full description
- Shows category, priority, status, created/updated timestamps
- If JIRA linked: shows JIRA status, assigned engineer (with avatar if available)
- If JIRA linked: shows comments timeline with author, body, and timestamp
- Clicking row again collapses the detail

**Status:** PASS

---

### 16. Support Ticket Detail - JIRA Live Data

**Preconditions:**
- Ticket has linked JIRA issue
- JIRA integration is configured

**Steps:**
1. Navigate to `/support`
2. Click on a ticket with JIRA link
3. View JIRA details section

**Expected Results:**
- JIRA status shown (e.g., "In Progress", "Done")
- Assigned engineer name displayed
- Assignee avatar shown (if available from JIRA)
- Comments displayed in timeline format (newest first)
- Each comment shows author name, body text, and created timestamp
- Last updated timestamp from JIRA shown

**Status:** PASS (when JIRA configured)

---

### 17. Submit Ticket from Support Page

**Steps:**
1. Navigate to `/support`
2. Click "Submit New Ticket" button in header

**Expected Results:**
- SupportTicketModal opens (same as sidebar "Get Help" button)
- After successful submission, modal closes
- New ticket appears in the list (may require page refresh)

**Status:** PASS

---

## API Test Commands (List & Detail)

### List Tickets (Authenticated)

```bash
# List all tickets (page 1, 20 per page)
curl -X GET "http://app.0xapogee.local/api/v1/support-tickets?page=1&page_size=20" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Response:**
```json
{
  "tickets": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "ticket_reference": "BSO-550E8400",
      "category": "bug",
      "priority": "high",
      "subject": "Test support ticket",
      "status": "open",
      "jira_issue_key": "SUPPORT-123",
      "jira_issue_url": "https://blocksecops.atlassian.net/browse/SUPPORT-123",
      "created_at": "2026-02-05T10:30:00Z",
      "updated_at": "2026-02-05T10:30:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 20
}
```

### List Tickets with Status Filter

```bash
# Filter by status
curl -X GET "http://app.0xapogee.local/api/v1/support-tickets?status=open" \
  -H "Authorization: Bearer $TOKEN"
```

### Get Ticket Detail with JIRA Data

```bash
# Get specific ticket (includes live JIRA data)
curl -X GET "http://app.0xapogee.local/api/v1/support-tickets/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "category": "bug",
  "priority": "high",
  "subject": "Test support ticket",
  "description": "Detailed description of the issue...",
  "user_email": "user@example.com",
  "user_tier": "team",
  "jira_issue_key": "SUPPORT-123",
  "jira_issue_url": "https://blocksecops.atlassian.net/browse/SUPPORT-123",
  "jira_sync_status": "synced",
  "status": "open",
  "created_at": "2026-02-05T10:30:00Z",
  "updated_at": "2026-02-05T10:30:00Z",
  "jira_details": {
    "status": "In Progress",
    "assignee": "Jane Smith",
    "assignee_avatar": "https://avatar.example.com/jane.jpg",
    "comments": [
      {
        "author": "Jane Smith",
        "body": "Looking into this now.",
        "created": "2026-02-05T11:00:00Z"
      }
    ],
    "last_updated": "2026-02-05T11:00:00Z"
  }
}
```

### Verify Ticket Ownership

```bash
# Attempting to view another user's ticket should return 404
curl -X GET "http://app.0xapogee.local/api/v1/support-tickets/other-users-ticket-id" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected:** HTTP 404 "Support ticket not found"

---

## Known Limitations

1. **Rate limit is per calendar day** - Resets at midnight UTC
2. **JIRA sync is synchronous** - May add latency to ticket submission
3. **No file attachments** - Screenshots/files not supported in initial release
4. **JIRA comments are read-only** - Users cannot reply to JIRA comments from the dashboard

## Future Enhancements

- Email notifications on ticket updates
- File attachment support
- Reply to JIRA comments from dashboard
- Admin view of all tickets
