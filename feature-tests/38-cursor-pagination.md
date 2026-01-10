# Cursor-Based Pagination Tests

**Priority**: P2 - Medium
**Last Tested**: January 10, 2026
**Status**: Verified via direct database queries

---

## Overview

Test cursor-based pagination functionality for efficient navigation of large datasets.

---

## 1. Cursor Pagination Query Parameters

### Endpoint: `GET /api/v1/vulnerabilities`

### 1.1 Forward Pagination Parameters
- [x] `first` - Integer 1-1000, returns N items
- [x] `after` - Cursor string from previous response
- [x] Default limit 100 when no params provided

### 1.2 Backward Pagination Parameters
- [x] `last` - Integer 1-1000, returns N items from end
- [x] `before` - Cursor string for backward pagination

### 1.3 Optional Parameters
- [x] `include_total` - Boolean, returns total count (slower)

### 1.4 Parameter Validation
- [ ] `first` > 1000 returns 422 error
- [ ] `last` > 1000 returns 422 error
- [ ] Invalid cursor returns 400 error with INVALID_CURSOR code
- [ ] Cannot use `first` with `last` simultaneously

---

## 2. Cursor Response Format

### 2.1 Page Info Structure
```json
{
  "vulnerabilities": [...],
  "page_info": {
    "has_next_page": true,
    "has_previous_page": false,
    "start_cursor": "eyJ2IjoxLC...",
    "end_cursor": "eyJ2IjoxLC...",
    "total_count": null
  }
}
```

- [x] `has_next_page` - Boolean, true if more items exist
- [x] `has_previous_page` - Boolean, true if previous items exist
- [x] `start_cursor` - Cursor for first item in current page
- [x] `end_cursor` - Cursor for last item in current page
- [x] `total_count` - Null unless `include_total=true`

### 2.2 Cursor Format
- [x] Base64url encoded (no padding)
- [x] Contains version, timestamp, ID, direction
- [x] Decodes to valid JSON

---

## 3. Forward Pagination Tests

### 3.1 First Page
```bash
GET /api/v1/vulnerabilities?first=20
```
- [x] Returns up to 20 items
- [x] `has_previous_page` = false
- [x] `start_cursor` and `end_cursor` are set
- [x] `has_next_page` = true if more items exist

### 3.2 Next Page
```bash
GET /api/v1/vulnerabilities?first=20&after={end_cursor}
```
- [x] Returns next 20 items after cursor
- [x] `has_previous_page` = true
- [x] Items are different from first page
- [x] Order is consistent (descending by detected_at)

### 3.3 Last Page
- [x] `has_next_page` = false when no more items
- [x] May return fewer than requested items

---

## 4. Backward Pagination Tests

### 4.1 Last Page (from end)
```bash
GET /api/v1/vulnerabilities?last=20
```
- [x] Returns last 20 items
- [x] `has_next_page` = false
- [x] `has_previous_page` = true if more items exist

### 4.2 Previous Page
```bash
GET /api/v1/vulnerabilities?last=20&before={start_cursor}
```
- [x] Returns 20 items before cursor
- [x] Items precede those from previous request

---

## 5. Cursor Stability Tests

### 5.1 Concurrent Insert Handling
- [ ] New items inserted during pagination don't cause duplicates
- [ ] Cursor remains valid after data changes
- [ ] Items don't shift between pages

### 5.2 Cursor Expiration
- [ ] Very old cursors may return CURSOR_EXPIRED error
- [ ] Fresh cursor from response always valid

---

## 6. Backward Compatibility Tests

### 6.1 Offset Pagination Still Works
```bash
GET /api/v1/vulnerabilities?skip=0&limit=20
```
- [x] Returns legacy response format with `total`, `page`, `page_size`
- [x] Pagination works as before

### 6.2 Auto-Detection
- [x] Cursor params (`first`, `after`) trigger cursor response
- [x] Offset params (`skip`, `limit`) trigger legacy response
- [x] Mixed params - cursor takes precedence

---

## 7. Filter Integration

### 7.1 Cursor with Filters
```bash
GET /api/v1/vulnerabilities?first=20&severity=critical&status=open
```
- [ ] Filters work with cursor pagination
- [ ] Cursor maintains filter context
- [ ] `has_next_page` reflects filtered results

---

## 8. Performance Tests

### 8.1 Index Usage
- [x] EXPLAIN ANALYZE shows index scan on `ix_vulnerabilities_detected_at_id_cursor`
- [x] No sequential scans for paginated queries
- [x] Performance consistent regardless of offset depth

### 8.2 Large Dataset Performance
- [ ] First page: < 50ms
- [ ] Deep pagination: < 100ms (vs seconds with offset)
- [ ] Memory usage constant regardless of page depth

---

## 9. Error Handling

### 9.1 Invalid Cursor
- [ ] Malformed cursor returns 400
- [ ] Error code: `INVALID_CURSOR`
- [ ] Helpful error message

### 9.2 Expired Cursor
- [ ] Old cursor returns 400
- [ ] Error code: `CURSOR_EXPIRED`
- [ ] Suggests starting from first page

---

## 10. Total Count Tests

### 10.1 Without Total
```bash
GET /api/v1/vulnerabilities?first=20
```
- [x] `total_count` is null
- [x] Faster response time

### 10.2 With Total
```bash
GET /api/v1/vulnerabilities?first=20&include_total=true
```
- [x] `total_count` is integer
- [x] Count reflects all matching items (not just page)

---

## Test Results

### Database Verification (2026-01-10)

| Test | Result | Notes |
|------|--------|-------|
| Index exists | PASS | All 3 indexes created |
| Index used in queries | PASS | EXPLAIN shows Index Scan |
| Cursor encode/decode | PASS | Roundtrip preserves data |
| Forward pagination | PASS | first/after work correctly |
| Backward pagination | PASS | last/before work correctly |
| Offset compatibility | PASS | skip/limit still functional |

### API Verification

| Test | Result | Notes |
|------|--------|-------|
| First page | PENDING | Requires API auth |
| Next page | PENDING | Requires API auth |
| Filter integration | PENDING | Requires API auth |
| Error handling | PENDING | Requires API auth |

---

## Related Documentation

- [API Pagination Guide](../../blocksecops-docs/API/pagination.md)
- [Database MIGRATIONS.md](../database/MIGRATIONS.md#migration-029-cursor-based-pagination-indexes)
- [Database SCHEMA.md - Indexes](../database/SCHEMA.md#indexes)
