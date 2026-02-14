# Vulnerability Management API

Base URL: `/api/v1/vulnerabilities`

## Overview

Endpoints for querying, managing, and analyzing vulnerabilities discovered through security scans. Supports filtering, status management, categorization, and statistical breakdowns.

---

## Endpoints

### List Vulnerabilities

```
GET /api/v1/vulnerabilities
```

Returns a paginated, filterable list of all vulnerabilities.

| Parameter     | Type    | In    | Required | Description                                         |
|---------------|---------|-------|----------|-----------------------------------------------------|
| `page`        | integer | query | no       | Page number (default: 1)                            |
| `page_size`   | integer | query | no       | Items per page (default: 20)                        |
| `severity`    | string  | query | no       | Filter by severity (`critical`, `high`, `medium`, `low`, `informational`) |
| `status`      | string  | query | no       | Filter by status (`open`, `confirmed`, `false_positive`, `resolved`) |
| `category`    | string  | query | no       | Filter by vulnerability category                    |
| `scanner`     | string  | query | no       | Filter by scanner that detected the vulnerability   |
| `contract_id` | string  | query | no       | Filter by contract ID                               |
| `scan_id`     | string  | query | no       | Filter by scan ID                                   |

**Response: `200 OK`**

```json
{
  "vulnerabilities": [
    {
      "id": "vuln-uuid",
      "title": "Reentrancy in withdraw()",
      "severity": "high",
      "status": "open",
      "category": "reentrancy",
      "scanner": "slither",
      "contract_id": "contract-uuid",
      "scan_id": "scan-uuid",
      "line_number": 42,
      "created_at": "2026-01-20T14:05:00Z"
    }
  ],
  "total": 150,
  "page": 1,
  "page_size": 20
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/vulnerabilities?severity=high&status=open&page=1&page_size=20" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Vulnerability Detail

```
GET /api/v1/vulnerabilities/{vuln_id}
```

Returns full detail for a single vulnerability, including fingerprints and deduplication information.

| Parameter | Type   | In   | Required | Description      |
|-----------|--------|------|----------|------------------|
| `vuln_id` | string | path | yes      | Vulnerability ID |

**Response: `200 OK`**

```json
{
  "id": "vuln-uuid",
  "title": "Reentrancy in withdraw()",
  "description": "The withdraw() function makes an external call before updating state, allowing reentrancy attacks.",
  "severity": "high",
  "status": "open",
  "category": "reentrancy",
  "scanner": "slither",
  "contract_id": "contract-uuid",
  "scan_id": "scan-uuid",
  "line_number": 42,
  "code_snippet": "function withdraw() external {\n    (bool success, ) = msg.sender.call{value: balance}(\"\");\n    balance = 0;\n}",
  "recommendation": "Follow the checks-effects-interactions pattern. Update state before making external calls.",
  "fingerprints": {
    "asm_fingerprint": "a1b2c3d4e5f6",
    "semantic_fingerprint": "f6e5d4c3b2a1",
    "location_fingerprint": "1234abcd5678"
  },
  "dedup_info": {
    "is_duplicate": false,
    "canonical_id": null,
    "duplicate_count": 0,
    "related_vulnerabilities": []
  },
  "created_at": "2026-01-20T14:05:00Z",
  "updated_at": "2026-01-20T14:05:00Z"
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/vulnerabilities/{vuln_id}" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Delete Vulnerability

```
DELETE /api/v1/vulnerabilities/{vuln_id}
```

Deletes a single vulnerability record.

| Parameter | Type   | In   | Required | Description      |
|-----------|--------|------|----------|------------------|
| `vuln_id` | string | path | yes      | Vulnerability ID |

**Response: `204 No Content`**

**Example:**

```bash
curl -X DELETE "https://api.example.com/api/v1/vulnerabilities/{vuln_id}" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Update Vulnerability Status

```
PATCH /api/v1/vulnerabilities/{vuln_id}/status
```

Updates the status of a vulnerability (e.g., mark as confirmed, false positive, or resolved).

| Parameter | Type   | In   | Required | Description                                                        |
|-----------|--------|------|----------|--------------------------------------------------------------------|
| `vuln_id` | string | path | yes      | Vulnerability ID                                                   |
| `status`  | string | body | yes      | New status (`open`, `confirmed`, `false_positive`, `resolved`)     |
| `reason`  | string | body | no       | Reason for the status change                                       |

**Request Body:**

```json
{
  "status": "false_positive",
  "reason": "This pattern is intentional for gas optimization"
}
```

**Response: `200 OK`**

```json
{
  "id": "vuln-uuid",
  "status": "false_positive",
  "previous_status": "open",
  "updated_at": "2026-02-01T10:00:00Z",
  "updated_by": "user-uuid"
}
```

**Example:**

```bash
curl -X PATCH "https://api.example.com/api/v1/vulnerabilities/{vuln_id}/status" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "confirmed", "reason": "Verified by manual review"}'
```

---

## Aggregation Endpoints

### Get Categories

```
GET /api/v1/vulnerabilities/categories
```

Returns all vulnerability categories with their respective counts.

**Response: `200 OK`**

```json
{
  "categories": [
    {"name": "reentrancy", "count": 15},
    {"name": "integer-overflow", "count": 12},
    {"name": "access-control", "count": 8},
    {"name": "unchecked-return", "count": 22},
    {"name": "front-running", "count": 3}
  ]
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/vulnerabilities/categories" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Scanners

```
GET /api/v1/vulnerabilities/scanners
```

Returns all scanners that have detected vulnerabilities, with their respective counts.

**Response: `200 OK`**

```json
{
  "scanners": [
    {"name": "slither", "count": 45},
    {"name": "mythril", "count": 30},
    {"name": "securify", "count": 18},
    {"name": "soliditydefend", "count": 52}
  ]
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/vulnerabilities/scanners" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Statistics Endpoints

### Stats by Category

```
GET /api/v1/vulnerabilities/stats/by-category
```

Returns a statistical breakdown of vulnerabilities grouped by category, including severity distribution.

**Response: `200 OK`**

```json
{
  "stats": [
    {
      "category": "reentrancy",
      "total": 15,
      "by_severity": {
        "critical": 3,
        "high": 7,
        "medium": 4,
        "low": 1,
        "informational": 0
      },
      "by_status": {
        "open": 10,
        "confirmed": 3,
        "false_positive": 1,
        "resolved": 1
      }
    },
    {
      "category": "access-control",
      "total": 8,
      "by_severity": {
        "critical": 2,
        "high": 4,
        "medium": 2,
        "low": 0,
        "informational": 0
      },
      "by_status": {
        "open": 5,
        "confirmed": 2,
        "false_positive": 0,
        "resolved": 1
      }
    }
  ]
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/vulnerabilities/stats/by-category" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Stats by Scanner

```
GET /api/v1/vulnerabilities/stats/by-scanner
```

Returns a statistical breakdown of vulnerabilities grouped by the scanner that detected them.

**Response: `200 OK`**

```json
{
  "stats": [
    {
      "scanner": "slither",
      "total": 45,
      "by_severity": {
        "critical": 5,
        "high": 15,
        "medium": 12,
        "low": 8,
        "informational": 5
      },
      "unique_categories": ["reentrancy", "access-control", "unchecked-return"]
    },
    {
      "scanner": "mythril",
      "total": 30,
      "by_severity": {
        "critical": 3,
        "high": 10,
        "medium": 10,
        "low": 5,
        "informational": 2
      },
      "unique_categories": ["integer-overflow", "reentrancy", "front-running"]
    }
  ]
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/vulnerabilities/stats/by-scanner" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Contract-Specific Vulnerabilities

### Get Vulnerabilities for Contract

```
GET /api/v1/vulnerabilities/contracts/{contract_id}/vulnerabilities
```

Returns all vulnerabilities associated with a specific contract across all scans.

| Parameter     | Type    | In    | Required | Description                         |
|---------------|---------|-------|----------|-------------------------------------|
| `contract_id` | string  | path  | yes      | Contract ID                         |
| `page`        | integer | query | no       | Page number (default: 1)            |
| `page_size`   | integer | query | no       | Items per page (default: 20)        |
| `severity`    | string  | query | no       | Filter by severity                  |
| `status`      | string  | query | no       | Filter by status                    |

**Response: `200 OK`**

```json
{
  "contract_id": "contract-uuid",
  "vulnerabilities": [
    {
      "id": "vuln-uuid-1",
      "title": "Reentrancy in withdraw()",
      "severity": "high",
      "status": "open",
      "category": "reentrancy",
      "scanner": "slither",
      "scan_id": "scan-uuid-1",
      "line_number": 42
    },
    {
      "id": "vuln-uuid-2",
      "title": "Unchecked return value",
      "severity": "medium",
      "status": "confirmed",
      "category": "unchecked-return",
      "scanner": "mythril",
      "scan_id": "scan-uuid-2",
      "line_number": 78
    }
  ],
  "total": 27,
  "page": 1,
  "page_size": 20
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/vulnerabilities/contracts/{contract_id}/vulnerabilities?severity=high" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Error Responses

All endpoints return standard error responses:

| Status Code | Description                          |
|-------------|--------------------------------------|
| `400`       | Bad request (invalid parameters)     |
| `401`       | Unauthorized (missing/invalid token) |
| `403`       | Forbidden (insufficient permissions) |
| `404`       | Resource not found                   |
| `422`       | Validation error                     |
| `500`       | Internal server error                |

**Error Response Schema:**

```json
{
  "detail": "Vulnerability not found",
  "status_code": 404
}
```

**Example (404 Not Found):**

```bash
curl -X GET "https://api.example.com/api/v1/vulnerabilities/nonexistent-id" \
  -H "Authorization: Bearer $TOKEN"

# Response: 404
# {"detail": "Vulnerability not found", "status_code": 404}
```
