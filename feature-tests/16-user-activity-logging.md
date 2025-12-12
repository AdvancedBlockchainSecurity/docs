# User Activity Logging

## Activity Log Page
**How to test**: Click "Activity Log" in the sidebar

- [ ] Page loads and displays activity list
- [ ] Summary cards show: Scans Completed, Scans Failed, Credits Used, Total Payments
- [ ] Activity entries show icon, description, and timestamp
- [ ] "View Contract" and "View Scan" links work when applicable

## Activity Filtering
**How to test**: Use the "Filter by" dropdown on the Activity Log page

- [ ] "All Activities" shows all entries
- [ ] "File Uploads" shows only upload events
- [ ] "Scans Completed" shows only completed scan events
- [ ] "Scans Failed" shows only failed scan events
- [ ] "Credits Used" shows only credit usage events
- [ ] Clear filter button resets to all activities

## Activity Pagination
**How to test**: Generate 20+ activities, then use pagination controls

- [ ] "Previous" button disabled on first page
- [ ] "Next" button navigates to next page
- [ ] Page count displays correctly (e.g., "Page 1 of 3")

## Activity Tracking
**How to test**: Perform actions and check Activity Log

- [ ] Uploading a file creates "File Upload" entry
- [ ] Creating a contract creates "Contract Created" entry
- [ ] Running a scan creates "Scan Started" and "Scan Completed/Failed" entries
- [ ] Using credits creates "Credits Used" entry

---

## API Endpoints

### GET /api/v1/users/me/activity
**How to test**:
```bash
curl "http://localhost:3000/api/v1/users/me/activity" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns 200 with `entries` array
- [ ] Response includes `total_count`, `page`, `page_size`, `total_pages`
- [ ] Response includes `summary` object

### GET /api/v1/users/me/activity?activity_type=X
**How to test**:
```bash
curl "http://localhost:3000/api/v1/users/me/activity?activity_type=scan_completed" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] `activity_type=scan_completed` returns only scan completions
- [ ] `activity_type=scan_failed` returns only failed scans
- [ ] `activity_type=file_upload` returns only uploads
- [ ] `activity_type=contract_created` returns only contract creations
- [ ] `activity_type=credit_used` returns only credit usage

### GET /api/v1/users/me/activity?page=X&page_size=Y
**How to test**:
```bash
curl "http://localhost:3000/api/v1/users/me/activity?page=2&page_size=10" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] `page=2` returns second page
- [ ] `page_size=10` returns 10 items per page
- [ ] `page_size=100` works (max)
- [ ] `page_size=101` returns error (exceeds max)
