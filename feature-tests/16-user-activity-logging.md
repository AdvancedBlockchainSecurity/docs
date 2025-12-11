# User Activity Logging Tests

**Priority**: P1 - High
**Phase**: 3.1b - Task 21
**Last Tested**: _Not yet tested_

---

## Overview

Tests for the user activity logging feature including the API endpoint, dashboard UI, and activity tracking integration.

---

## 1. API Endpoint Tests

### 1.1 GET /users/me/activity - Basic

```bash
# Prerequisites: Set $TOKEN with valid Supabase JWT

# Get first page of all activities (default pagination)
curl -X GET "http://localhost:8000/api/v1/users/me/activity" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns 200 OK with valid token
- [ ] Response includes `entries` array
- [ ] Response includes `total_count` field
- [ ] Response includes `page` field (default: 1)
- [ ] Response includes `page_size` field (default: 20)
- [ ] Response includes `total_pages` field
- [ ] Response includes `summary` object

### 1.2 GET /users/me/activity - Filtering

```bash
# Filter by activity type - scan completions only
curl -X GET "http://localhost:8000/api/v1/users/me/activity?activity_type=scan_completed" \
  -H "Authorization: Bearer $TOKEN"

# Filter by file uploads
curl -X GET "http://localhost:8000/api/v1/users/me/activity?activity_type=file_upload" \
  -H "Authorization: Bearer $TOKEN"

# Filter by contract events
curl -X GET "http://localhost:8000/api/v1/users/me/activity?activity_type=contract_created" \
  -H "Authorization: Bearer $TOKEN"

# Filter by payment events
curl -X GET "http://localhost:8000/api/v1/users/me/activity?activity_type=payment" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Filter `activity_type=scan_completed` returns only scan completion events
- [ ] Filter `activity_type=scan_failed` returns only failed scan events
- [ ] Filter `activity_type=file_upload` returns only upload events
- [ ] Filter `activity_type=contract_created` returns only contract creation events
- [ ] Filter `activity_type=contract_deleted` returns only contract deletion events
- [ ] Filter `activity_type=scan_started` returns only scan start events
- [ ] Filter `activity_type=payment` returns only payment events
- [ ] Filter `activity_type=credit_purchase` returns only credit purchase events
- [ ] Filter `activity_type=credit_used` returns only credit usage events
- [ ] Invalid activity_type returns appropriate error

### 1.3 GET /users/me/activity - Pagination

```bash
# Get page 2 with 50 items per page
curl -X GET "http://localhost:8000/api/v1/users/me/activity?page=2&page_size=50" \
  -H "Authorization: Bearer $TOKEN"

# Get page 1 with minimum page size
curl -X GET "http://localhost:8000/api/v1/users/me/activity?page=1&page_size=1" \
  -H "Authorization: Bearer $TOKEN"

# Get with maximum page size (100)
curl -X GET "http://localhost:8000/api/v1/users/me/activity?page_size=100" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] `page=2` returns second page of results
- [ ] `page_size=50` returns 50 items per page (if available)
- [ ] `page_size=1` returns 1 item per page (minimum)
- [ ] `page_size=100` returns up to 100 items per page (maximum)
- [ ] `page_size=0` returns validation error
- [ ] `page_size=101` returns validation error (exceeds max)
- [ ] `page=0` returns validation error
- [ ] Pagination correctly calculates `total_pages`

### 1.4 GET /users/me/activity - Authentication

```bash
# Without token (should fail)
curl -X GET "http://localhost:8000/api/v1/users/me/activity"

# With invalid token (should fail)
curl -X GET "http://localhost:8000/api/v1/users/me/activity" \
  -H "Authorization: Bearer invalid_token"

# With expired token (should fail)
curl -X GET "http://localhost:8000/api/v1/users/me/activity" \
  -H "Authorization: Bearer $EXPIRED_TOKEN"
```

- [ ] Request without token returns 401 Unauthorized
- [ ] Request with invalid token returns 401 Unauthorized
- [ ] Request with expired token returns 401 Unauthorized

---

## 2. Activity Entry Structure

### 2.1 Entry Fields

Each activity log entry should contain:

- [ ] `id` - UUID of activity entry
- [ ] `activity_type` - One of valid activity types
- [ ] `description` - Human-readable description
- [ ] `contract_id` - UUID or null
- [ ] `scan_id` - UUID or null
- [ ] `scanner_type` - String or null (e.g., "slither", "aderyn")
- [ ] `scan_status` - String or null (e.g., "completed", "failed")
- [ ] `credits_used` - Integer (default 0)
- [ ] `payment_amount` - Decimal or null
- [ ] `payment_currency` - String or null (e.g., "USDC")
- [ ] `metadata` - JSON object or null
- [ ] `created_at` - ISO 8601 timestamp

### 2.2 Summary Fields

Summary object should contain:

- [ ] `scans_completed` - Integer count
- [ ] `scans_failed` - Integer count
- [ ] `total_credits_used` - Integer count
- [ ] `total_payments` - Decimal total

---

## 3. Dashboard UI Tests

### 3.1 Activity Log Page Access

- [ ] Activity Log link visible in sidebar under OVERVIEW
- [ ] Clicking Activity Log navigates to `/activity`
- [ ] Activity Log page loads without errors
- [ ] Page shows loading state while fetching

### 3.2 Summary Cards

- [ ] Summary card for "Scans Completed" displays correctly
- [ ] Summary card for "Scans Failed" displays correctly
- [ ] Summary card for "Credits Used" displays correctly
- [ ] Summary card for "Total Payments" displays correctly
- [ ] Summary cards update when filter changes

### 3.3 Activity Table

- [ ] Activity entries displayed in table format
- [ ] Table shows activity type with appropriate icon/badge
- [ ] Table shows description
- [ ] Table shows related contract (if applicable)
- [ ] Table shows timestamp
- [ ] Table sorted by most recent first

### 3.4 Filtering

- [ ] Filter dropdown shows all activity types
- [ ] Filter dropdown includes "All Activities" option
- [ ] Selecting filter updates table results
- [ ] Selecting filter updates summary cards
- [ ] Filter persists across page refresh (if applicable)

### 3.5 Pagination

- [ ] Pagination controls visible when results > page size
- [ ] "Previous" button disabled on first page
- [ ] "Next" button disabled on last page
- [ ] Clicking page number loads correct page
- [ ] Current page highlighted

### 3.6 Empty State

- [ ] Empty state displayed when no activities exist
- [ ] Empty state message is user-friendly
- [ ] Empty state displayed when filter returns no results

---

## 4. Activity Logging Integration

### 4.1 File Upload Activity

- [ ] File upload creates `file_upload` activity entry
- [ ] Activity includes file name in description
- [ ] Activity includes contract_id (if applicable)

### 4.2 Contract Activity

- [ ] Contract creation creates `contract_created` activity entry
- [ ] Contract deletion creates `contract_deleted` activity entry
- [ ] Activities include contract_id

### 4.3 Scan Activity

- [ ] Scan start creates `scan_started` activity entry
- [ ] Scan completion creates `scan_completed` activity entry
- [ ] Scan failure creates `scan_failed` activity entry
- [ ] Activity includes scanner_type
- [ ] Activity includes scan_status
- [ ] Activity includes scan_id
- [ ] Activity includes credits_used

### 4.4 Payment Activity

- [ ] Credit purchase creates `credit_purchase` activity entry
- [ ] Credit usage creates `credit_used` activity entry
- [ ] Payment completion creates `payment` activity entry
- [ ] Activity includes payment_amount
- [ ] Activity includes payment_currency

---

## 5. Data Isolation

### 5.1 User Isolation

- [ ] User A cannot see User B's activities
- [ ] Activities only returned for authenticated user
- [ ] No activity IDs leaked across users

---

## 6. Cascade Behavior

### 6.1 Contract Deletion

When a contract is deleted:
- [ ] Activity log `contract_id` set to NULL (not deleted)
- [ ] Activity description still readable
- [ ] Historical activity preserved

### 6.2 Scan Deletion

When a scan is deleted:
- [ ] Activity log `scan_id` set to NULL (not deleted)
- [ ] Activity description still readable
- [ ] Historical activity preserved

---

## Test Notes

_Record activity logging test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
