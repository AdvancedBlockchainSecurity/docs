# Favorites & Annotations

## Favorite a Contract
**How to test**: Navigate to any contract detail page (`/contracts/{id}`)

- [ ] Star icon appears next to contract name
- [ ] Clicking star fills it with yellow (favorited)
- [ ] Clicking again removes the favorite (outline star)
- [ ] Favorite state persists after page refresh

## Favorite a Scan
**How to test**: Navigate to any scan results page (`/scans/{id}`)

- [ ] Star icon appears next to "Scan Results" heading
- [ ] Clicking star fills it with yellow (favorited)
- [ ] Clicking again removes the favorite (outline star)
- [ ] Favorite state persists after page refresh

## Favorites Widget
**How to test**: Navigate to Dashboard (`/`)

- [ ] Favorites widget appears on dashboard (below Intelligence Widget)
- [ ] Shows "No favorites yet" if no items favorited
- [ ] Shows favorited items with appropriate icons (folder/document/magnifying glass)
- [ ] Clicking favorited item navigates to detail page
- [ ] Shows "+X more" when more than 5 favorites exist

## Annotation Status on Vulnerabilities
**How to test**: Navigate to scan results page (`/scans/{id}`) with vulnerabilities

- [ ] "Set Status" dropdown appears on each vulnerability card
- [ ] Clicking opens dropdown with status options
- [ ] Selecting a status updates the dropdown immediately (optimistic update)
- [ ] Available statuses: False Positive, Acknowledged, Confirmed, Won't Fix, In Progress, Fixed

## Annotation in Vulnerability Detail Modal
**How to test**: Click on any vulnerability to open detail modal

- [ ] "Annotation Status" section appears in modal (before Metadata section)
- [ ] Status dropdown works same as list view
- [ ] Status persists after closing and reopening modal

---

## Favorites API Endpoints

### POST /api/v1/favorites
**How to test**:
```bash
curl -X POST "http://localhost:3000/api/v1/favorites" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"item_type": "contract", "item_id": "<CONTRACT_ID>"}'
```

- [ ] Returns 201 with favorite object
- [ ] Supports item_type: contract, project, scan

### GET /api/v1/favorites
**How to test**:
```bash
curl "http://localhost:3000/api/v1/favorites" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns array of user's favorites
- [ ] Each favorite includes item_type, item_id, created_at

### GET /api/v1/favorites/check/:type/:id
**How to test**:
```bash
curl "http://localhost:3000/api/v1/favorites/check/contract/<CONTRACT_ID>" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns `{is_favorited: true}` if favorited
- [ ] Returns `{is_favorited: false}` if not favorited

### DELETE /api/v1/favorites/:type/:id
**How to test**:
```bash
curl -X DELETE "http://localhost:3000/api/v1/favorites/contract/<CONTRACT_ID>" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns 204 No Content
- [ ] Favorite is removed from list

### PUT /api/v1/favorites/reorder
**How to test**:
```bash
curl -X PUT "http://localhost:3000/api/v1/favorites/reorder" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"favorite_ids": ["<ID1>", "<ID2>", "<ID3>"]}'
```

- [ ] Returns updated favorites in new order

---

## Annotations API Endpoints

### POST /api/v1/annotations
**How to test**:
```bash
curl -X POST "http://localhost:3000/api/v1/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"vulnerability_id": "<VULN_ID>", "status": "false_positive", "note": "Not applicable"}'
```

- [ ] Returns 201 with annotation object
- [ ] Supports statuses: false_positive, acknowledged, confirmed, wont_fix, in_progress, fixed

### GET /api/v1/annotations/vulnerability/:id
**How to test**:
```bash
curl "http://localhost:3000/api/v1/annotations/vulnerability/<VULN_ID>" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns annotation if exists
- [ ] Returns null/empty if no annotation

### GET /api/v1/annotations
**How to test**:
```bash
curl "http://localhost:3000/api/v1/annotations" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns paginated list of all user's annotations

### GET /api/v1/annotations/scan/:id
**How to test**:
```bash
curl "http://localhost:3000/api/v1/annotations/scan/<SCAN_ID>" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns all annotations for vulnerabilities in that scan

### GET /api/v1/annotations/:id/history
**How to test**:
```bash
curl "http://localhost:3000/api/v1/annotations/<ANNOTATION_ID>/history" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns history of status changes
- [ ] Each entry shows old_status, new_status, timestamp

### DELETE /api/v1/annotations/:id
**How to test**:
```bash
curl -X DELETE "http://localhost:3000/api/v1/annotations/<ANNOTATION_ID>" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns 204 No Content
- [ ] Annotation is removed

### POST /api/v1/annotations/bulk
**How to test**:
```bash
curl -X POST "http://localhost:3000/api/v1/annotations/bulk" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"annotations": [{"vulnerability_id": "<ID1>", "status": "false_positive"}, {"vulnerability_id": "<ID2>", "status": "confirmed"}]}'
```

- [ ] Creates multiple annotations at once
- [ ] Returns created annotations
