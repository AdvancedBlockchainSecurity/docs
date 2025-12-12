# Batch Scan Operations

## Create Batch Scan
**How to test**: Navigate to `/scan` and create a batch scan

- [ ] Contract selection shows all user's contracts
- [ ] "Select all" and "Clear all" buttons work
- [ ] Scanner selection shows available scanners (SolidityDefend, Slither, Aderyn, Wake, Mythril, Semgrep)
- [ ] Default scanners are pre-selected (SolidityDefend, Slither, Aderyn)
- [ ] Submit button disabled when no contracts selected
- [ ] Submit button disabled when no scanners selected
- [ ] Shows "Creating Batch..." during submission
- [ ] Success message appears after batch created
- [ ] Selected contracts clear after successful creation

## Batch Scan History
**How to test**: View the history section on `/scan` page

- [ ] Shows list of previous batch scans
- [ ] Each batch shows status badge (pending, running, completed, failed)
- [ ] Each batch shows total contract count
- [ ] Each batch shows completion progress (X/Y completed)
- [ ] Each batch shows progress bar
- [ ] Shows creation timestamp
- [ ] Refresh button updates the list
- [ ] Auto-refreshes every 5 seconds

## Batch Scan Details (Expanded)
**How to test**: Click on a batch scan to expand details

- [ ] Shows severity counts (Critical, High, Medium, Low)
- [ ] Lists individual scans with:
  - [ ] Contract name
  - [ ] Status badge
  - [ ] Vulnerability count
  - [ ] Link to scan results
- [ ] Running scans show spinning icon
- [ ] Completed scans link to `/scans/:id`

## Status Badges
**How to test**: Observe status badges throughout the UI

- [ ] `pending` - Gray badge with clock icon
- [ ] `running` - Blue badge with spinning icon
- [ ] `completed` - Green badge with checkmark
- [ ] `partially_completed` - Yellow badge with warning icon
- [ ] `failed` - Red badge with error icon

---

## API Endpoints

### POST /api/v1/scans/batch
**How to test**:
```bash
curl -X POST "http://localhost:3000/api/v1/scans/batch" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_ids": ["<CONTRACT_ID_1>", "<CONTRACT_ID_2>"],
    "scanner_ids": ["slither", "aderyn"],
    "scan_type": "full",
    "priority": "normal"
  }'
```

- [ ] Returns `batch_id` UUID
- [ ] Returns `total_contracts` count
- [ ] Returns `queued_scans` count
- [ ] Returns `failed_to_queue` count (0 for success)
- [ ] Returns `scans` array with individual scan info
- [ ] Returns `message` string
- [ ] Returns 400 if contract_ids empty
- [ ] Returns 400 if contract_ids > 100
- [ ] Returns 401 if not authenticated
- [ ] Returns 403 if any contract belongs to another user

### GET /api/v1/scans/batch
**How to test**:
```bash
curl "http://localhost:3000/api/v1/scans/batch?limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns `batches` array
- [ ] Returns `total` count
- [ ] Returns `page` number
- [ ] Returns `page_size` number
- [ ] Batches are ordered by created_at descending
- [ ] Supports `skip` and `limit` pagination
- [ ] Supports `status` filter

### GET /api/v1/scans/batch/:batch_id
**How to test**:
```bash
curl "http://localhost:3000/api/v1/scans/batch/<BATCH_ID>" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns batch details with all fields:
  - [ ] `id` - UUID
  - [ ] `user_id` - UUID
  - [ ] `project_id` - UUID or null
  - [ ] `total_contracts` - integer
  - [ ] `completed_count` - integer
  - [ ] `failed_count` - integer
  - [ ] `status` - string enum
  - [ ] `priority` - string
  - [ ] `scanner_ids` - string array or null
  - [ ] `created_at` - ISO timestamp
  - [ ] `completed_at` - ISO timestamp or null
  - [ ] `scans` - array of scan details
  - [ ] `progress_percent` - float 0-100
  - [ ] `critical_count` - integer
  - [ ] `high_count` - integer
  - [ ] `medium_count` - integer
  - [ ] `low_count` - integer
- [ ] Returns 404 if batch not found
- [ ] Returns 403 if batch belongs to another user

## Batch Scan Item Status
**How to test**: Verify individual scan items in batch response

- [ ] Each scan has `scan_id` UUID
- [ ] Each scan has `contract_id` UUID
- [ ] Each scan has `contract_name` string or null
- [ ] Each scan has `status` (queued, running, completed, failed)
- [ ] Each scan has `error` string or null
- [ ] Each scan has `vulnerability_count` integer
- [ ] Each scan has `created_at` ISO timestamp
