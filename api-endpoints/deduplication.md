# Deduplication API

Base URL: `/api/v1/deduplication`

This module provides vulnerability deduplication capabilities, including grouping of duplicate findings across scanners, canonical finding selection, group management, and maintenance operations for fingerprint regeneration and backfilling.

---

## Endpoints

### Get Deduplication Statistics

Returns aggregate statistics for the deduplication system.

**`GET /api/v1/deduplication/stats`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/deduplication/stats \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "total_groups": 768,
  "total_findings_deduplicated": 2637,
  "average_group_size": 3.43,
  "largest_group_size": 12,
  "singleton_groups": 215,
  "scanners_represented": 8
}
```

#### Response Schema

| Field                        | Type    | Description                                         |
|------------------------------|---------|-----------------------------------------------------|
| `total_groups`               | integer | Total number of deduplication groups                |
| `total_findings_deduplicated`| integer | Total findings that have been grouped               |
| `average_group_size`         | float   | Mean number of findings per group                   |
| `largest_group_size`         | integer | Size of the largest deduplication group             |
| `singleton_groups`           | integer | Groups containing only one finding                  |
| `scanners_represented`       | integer | Number of distinct scanners contributing findings   |

---

### List Deduplication Groups

Returns a paginated list of deduplication groups with their canonical finding titles.

**`GET /api/v1/deduplication/groups`**

#### Query Parameters

| Parameter           | Type    | Default | Description                             |
|---------------------|---------|---------|-----------------------------------------|
| `page`              | integer | 1       | Page number                             |
| `limit`             | integer | 20      | Results per page (max 100)              |
| `min_size`          | integer | —       | Minimum group size filter               |
| `scanner`           | string  | —       | Filter by scanner that contributed      |
| `severity`          | string  | —       | Filter by canonical finding severity    |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/deduplication/groups?page=1&limit=10&min_size=2" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "groups": [
    {
      "id": "grp-11223344-5566-7788-99aa-bbccddeeff00",
      "canonical_finding_title": "Reentrancy vulnerability in withdraw()",
      "canonical_severity": "critical",
      "size": 4,
      "scanners": ["slither", "mythril", "soliditydefend"],
      "created_at": "2026-01-15T10:00:00Z"
    },
    {
      "id": "grp-aabbccdd-1122-3344-5566-778899001122",
      "canonical_finding_title": "Unchecked external call return value",
      "canonical_severity": "medium",
      "size": 3,
      "scanners": ["slither", "soliditydefend"],
      "created_at": "2026-01-16T14:30:00Z"
    }
  ],
  "total": 768,
  "page": 1,
  "limit": 10
}
```

---

### Get Group Detail

Retrieves the full detail of a specific deduplication group, including all member findings.

**`GET /api/v1/deduplication/groups/{group_id}`**

#### Path Parameters

| Parameter  | Type   | Description                       |
|------------|--------|-----------------------------------|
| `group_id` | string | UUID of the deduplication group  |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/deduplication/groups/grp-11223344-5566-7788-99aa-bbccddeeff00 \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "id": "grp-11223344-5566-7788-99aa-bbccddeeff00",
  "canonical_finding_id": "f1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "canonical_finding_title": "Reentrancy vulnerability in withdraw()",
  "canonical_severity": "critical",
  "size": 4,
  "findings": [
    {
      "id": "f1a2b3c4-d5e6-7890-abcd-ef1234567890",
      "title": "Reentrancy vulnerability in withdraw()",
      "scanner": "slither",
      "severity": "critical",
      "is_canonical": true,
      "fingerprint": "asm:0xabc123..."
    },
    {
      "id": "f2b3c4d5-e6f7-8901-bcde-f12345678901",
      "title": "Reentrancy in withdraw function",
      "scanner": "mythril",
      "severity": "high",
      "is_canonical": false,
      "fingerprint": "asm:0xabc123..."
    },
    {
      "id": "f3c4d5e6-f7a8-9012-cdef-123456789012",
      "title": "SWC-107: Reentrancy",
      "scanner": "soliditydefend",
      "severity": "critical",
      "is_canonical": false,
      "fingerprint": "asm:0xabc123..."
    },
    {
      "id": "f4d5e6f7-a8b9-0123-defa-234567890123",
      "title": "State change after external call",
      "scanner": "securify",
      "severity": "high",
      "is_canonical": false,
      "fingerprint": "asm:0xabc123..."
    }
  ],
  "created_at": "2026-01-15T10:00:00Z",
  "updated_at": "2026-02-10T08:15:00Z"
}
```

---

### Merge Groups

Merges two or more deduplication groups into a single group.

**`POST /api/v1/deduplication/groups/merge`**

#### Request Body

| Field       | Type     | Required | Description                                  |
|-------------|----------|----------|----------------------------------------------|
| `group_ids` | string[] | Yes      | Array of group UUIDs to merge (min 2)       |
| `canonical_finding_id` | string | No | Finding ID to set as canonical in merged group |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/deduplication/groups/merge \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "group_ids": [
      "grp-11223344-5566-7788-99aa-bbccddeeff00",
      "grp-aabbccdd-1122-3344-5566-778899001122"
    ],
    "canonical_finding_id": "f1a2b3c4-d5e6-7890-abcd-ef1234567890"
  }'
```

#### Response `200 OK`

```json
{
  "id": "grp-11223344-5566-7788-99aa-bbccddeeff00",
  "size": 7,
  "merged_groups": 2,
  "canonical_finding_title": "Reentrancy vulnerability in withdraw()",
  "message": "Successfully merged 2 groups into 1"
}
```

---

### Set Canonical Finding

Updates the canonical (representative) finding for a deduplication group.

**`PATCH /api/v1/deduplication/groups/{group_id}/canonical`**

#### Path Parameters

| Parameter  | Type   | Description                       |
|------------|--------|-----------------------------------|
| `group_id` | string | UUID of the deduplication group  |

#### Request Body

| Field        | Type   | Required | Description                              |
|--------------|--------|----------|------------------------------------------|
| `finding_id` | string | Yes      | UUID of the finding to set as canonical |

#### Example Request

```bash
curl -X PATCH http://localhost:8000/api/v1/deduplication/groups/grp-11223344-5566-7788-99aa-bbccddeeff00/canonical \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "finding_id": "f2b3c4d5-e6f7-8901-bcde-f12345678901"
  }'
```

#### Response `200 OK`

```json
{
  "group_id": "grp-11223344-5566-7788-99aa-bbccddeeff00",
  "canonical_finding_id": "f2b3c4d5-e6f7-8901-bcde-f12345678901",
  "canonical_finding_title": "Reentrancy in withdraw function",
  "updated_at": "2026-02-14T10:30:00Z"
}
```

---

### Ungroup a Finding

Removes a finding from its deduplication group, making it a standalone entry.

**`DELETE /api/v1/deduplication/findings/{finding_id}/ungroup`**

#### Path Parameters

| Parameter    | Type   | Description                  |
|--------------|--------|------------------------------|
| `finding_id` | string | UUID of the finding         |

#### Example Request

```bash
curl -X DELETE http://localhost:8000/api/v1/deduplication/findings/f4d5e6f7-a8b9-0123-defa-234567890123/ungroup \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "finding_id": "f4d5e6f7-a8b9-0123-defa-234567890123",
  "previous_group_id": "grp-11223344-5566-7788-99aa-bbccddeeff00",
  "message": "Finding removed from group. Group size is now 3."
}
```

---

### Match a Vulnerability

Attempts to match a vulnerability against existing deduplication groups.

**`POST /api/v1/deduplication/vulnerabilities/{vulnerability_id}/match`**

#### Path Parameters

| Parameter          | Type   | Description                      |
|--------------------|--------|----------------------------------|
| `vulnerability_id` | string | UUID of the vulnerability        |

#### Request Body

| Field           | Type    | Required | Description                              |
|-----------------|---------|----------|------------------------------------------|
| `auto_group`    | boolean | No       | Automatically add to best match group    |
| `min_similarity`| float   | No       | Minimum similarity threshold (default: 0.8) |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/deduplication/vulnerabilities/a1b2c3d4-e5f6-7890-abcd-ef1234567890/match \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "auto_group": false,
    "min_similarity": 0.8
  }'
```

#### Response `200 OK`

```json
{
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "matches": [
    {
      "group_id": "grp-11223344-5566-7788-99aa-bbccddeeff00",
      "canonical_title": "Reentrancy vulnerability in withdraw()",
      "similarity": 0.94,
      "match_method": "fingerprint"
    }
  ],
  "total_matches": 1,
  "auto_grouped": false
}
```

---

### Backfill Detector IDs

Maintenance operation that backfills missing detector IDs across existing findings.

**`POST /api/v1/deduplication/maintenance/backfill-detector-ids`**

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/deduplication/maintenance/backfill-detector-ids \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "processed": 2637,
  "updated": 145,
  "errors": 0,
  "duration_seconds": 12.3
}
```

---

### Regenerate Empty Fingerprints

Maintenance operation that regenerates fingerprints for findings with empty or missing fingerprints.

**`POST /api/v1/deduplication/maintenance/regenerate-empty-fingerprints`**

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/deduplication/maintenance/regenerate-empty-fingerprints \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "processed": 2637,
  "regenerated": 89,
  "still_empty": 3,
  "errors": 0,
  "duration_seconds": 45.7
}
```

---

### Run Full Backfill

Comprehensive maintenance operation that runs all backfill operations in sequence: detector ID backfill, fingerprint regeneration, and re-grouping.

**`POST /api/v1/deduplication/maintenance/run-full-backfill`**

#### Request Body

| Field        | Type    | Required | Description                              |
|--------------|---------|----------|------------------------------------------|
| `dry_run`    | boolean | No       | Preview changes without applying them    |
| `batch_size` | integer | No       | Processing batch size (default: 100)     |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/deduplication/maintenance/run-full-backfill \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "dry_run": false,
    "batch_size": 100
  }'
```

#### Response `200 OK`

```json
{
  "steps_completed": [
    {
      "step": "backfill_detector_ids",
      "processed": 2637,
      "updated": 145
    },
    {
      "step": "regenerate_fingerprints",
      "processed": 2637,
      "regenerated": 89
    },
    {
      "step": "regroup_findings",
      "processed": 2637,
      "new_groups": 12,
      "merged_groups": 5
    }
  ],
  "total_duration_seconds": 78.4,
  "dry_run": false
}
```

---

## Error Responses

All endpoints may return the following error responses:

| Status | Description               |
|--------|---------------------------|
| `400`  | Bad request / validation  |
| `401`  | Unauthorized              |
| `404`  | Resource not found        |
| `409`  | Conflict (e.g., merge conflict) |
| `422`  | Unprocessable entity      |
| `500`  | Internal server error     |

```json
{
  "detail": "Group not found: grp-00000000-0000-0000-0000-000000000000",
  "status_code": 404
}
```
