# Scan Management API

Base URL: `/api/v1/scans`

## Overview

Endpoints for creating, managing, and retrieving security scan results for smart contracts. Supports individual scans, batch operations, and multiple result types including vulnerabilities, fuzzing, formal verification, and gas analysis.

---

## Endpoints

### List Scans

```
GET /api/v1/scans
```

Returns a paginated list of all scans.

| Parameter   | Type    | In    | Description              |
|-------------|---------|-------|--------------------------|
| `page`      | integer | query | Page number (default: 1) |
| `page_size` | integer | query | Items per page           |
| `status`    | string  | query | Filter by status         |

**Response: `200 OK`**

```json
{
  "scans": [
    {
      "id": "scan-uuid",
      "contract_id": "contract-uuid",
      "scan_type": "full",
      "status": "completed",
      "created_at": "2026-01-20T14:00:00Z"
    }
  ],
  "total": 100,
  "page": 1,
  "page_size": 20
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans?page=1&page_size=20" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Create Scan

```
POST /api/v1/scans
```

Creates and initiates a new scan for a contract.

| Parameter     | Type     | In   | Required | Description                                      |
|---------------|----------|------|----------|--------------------------------------------------|
| `contract_id` | string   | body | yes      | ID of the contract to scan                       |
| `scanner_ids` | string[] | body | yes      | Array of scanner IDs to use                      |
| `scan_type`   | string   | body | yes      | Type of scan (`full`, `quick`, `custom`)         |

**Request Body:**

```json
{
  "contract_id": "contract-uuid",
  "scanner_ids": ["slither", "mythril", "securify"],
  "scan_type": "full"
}
```

**Response: `201 Created`**

```json
{
  "id": "scan-uuid",
  "contract_id": "contract-uuid",
  "scan_type": "full",
  "status": "pending",
  "scanners_used": ["slither", "mythril", "securify"],
  "created_at": "2026-01-20T14:00:00Z"
}
```

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_id": "contract-uuid",
    "scanner_ids": ["slither", "mythril"],
    "scan_type": "full"
  }'
```

---

### Bulk Delete Scans

```
DELETE /api/v1/scans
```

Deletes multiple scans at once.

| Parameter  | Type     | In   | Required | Description            |
|------------|----------|------|----------|------------------------|
| `scan_ids` | string[] | body | yes      | Array of scan IDs      |

**Request Body:**

```json
{
  "scan_ids": ["scan-uuid-1", "scan-uuid-2"]
}
```

**Response: `204 No Content`**

**Example:**

```bash
curl -X DELETE "https://api.example.com/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"scan_ids": ["scan-uuid-1", "scan-uuid-2"]}'
```

---

## Batch Scan Endpoints

### Create Batch Scan

```
POST /api/v1/scans/batch
```

Creates scans for multiple contracts in a single batch operation.

| Parameter      | Type     | In   | Required | Description                         |
|----------------|----------|------|----------|-------------------------------------|
| `contract_ids` | string[] | body | yes      | Array of contract IDs to scan       |
| `scanner_ids`  | string[] | body | no       | Scanners to use (default: all)      |
| `scan_type`    | string   | body | no       | Scan type (default: `full`)         |

**Request Body:**

```json
{
  "contract_ids": ["contract-uuid-1", "contract-uuid-2", "contract-uuid-3"],
  "scanner_ids": ["slither", "mythril"],
  "scan_type": "full"
}
```

**Response: `201 Created`**

```json
{
  "batch_id": "batch-uuid",
  "total_scans": 3,
  "status": "pending",
  "created_at": "2026-01-20T14:00:00Z"
}
```

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/scans/batch" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_ids": ["uuid-1", "uuid-2"],
    "scanner_ids": ["slither"],
    "scan_type": "quick"
  }'
```

---

### List Batches

```
GET /api/v1/scans/batch
```

Returns a list of all batch scan operations.

**Response: `200 OK`**

```json
{
  "batches": [
    {
      "batch_id": "batch-uuid",
      "total_scans": 3,
      "completed": 2,
      "status": "in_progress",
      "created_at": "2026-01-20T14:00:00Z"
    }
  ]
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/batch" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Batch Detail

```
GET /api/v1/scans/batch/{batch_id}
```

Returns details of a specific batch scan operation.

| Parameter  | Type   | In   | Required | Description  |
|------------|--------|------|----------|--------------|
| `batch_id` | string | path | yes      | Batch ID     |

**Response: `200 OK`**

```json
{
  "batch_id": "batch-uuid",
  "total_scans": 3,
  "completed": 2,
  "failed": 0,
  "status": "in_progress",
  "scans": [
    {"scan_id": "scan-uuid-1", "contract_id": "uuid-1", "status": "completed"},
    {"scan_id": "scan-uuid-2", "contract_id": "uuid-2", "status": "completed"},
    {"scan_id": "scan-uuid-3", "contract_id": "uuid-3", "status": "running"}
  ]
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/batch/{batch_id}" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Update Batch Status

```
POST /api/v1/scans/batch/{batch_id}/update-status
```

Manually triggers a status recalculation for a batch.

| Parameter  | Type   | In   | Required | Description  |
|------------|--------|------|----------|--------------|
| `batch_id` | string | path | yes      | Batch ID     |

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/scans/batch/{batch_id}/update-status" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Comparison Endpoint

### Compare Scans

```
GET /api/v1/scans/compare
```

Compares results between two or more scans.

| Parameter  | Type     | In    | Required | Description               |
|------------|----------|-------|----------|---------------------------|
| `scan_ids` | string[] | query | yes      | Comma-separated scan IDs  |

**Response: `200 OK`**

```json
{
  "scans_compared": ["scan-uuid-1", "scan-uuid-2"],
  "new_vulnerabilities": [],
  "resolved_vulnerabilities": [],
  "unchanged_vulnerabilities": []
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/compare?scan_ids=uuid-1,uuid-2" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Contract Scans

### Get Scans for Contract

```
GET /api/v1/scans/contracts/{contract_id}/scans
```

Returns all scans associated with a specific contract.

| Parameter     | Type   | In   | Required | Description   |
|---------------|--------|------|----------|---------------|
| `contract_id` | string | path | yes      | Contract ID   |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/contracts/{contract_id}/scans" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Individual Scan Endpoints

### Get Scan Detail

```
GET /api/v1/scans/{scan_id}
```

Returns full detail of a single scan.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Response: `200 OK`**

```json
{
  "id": "scan-uuid",
  "contract_id": "contract-uuid",
  "scan_type": "full",
  "status": "completed",
  "critical_count": 1,
  "high_count": 3,
  "medium_count": 7,
  "low_count": 12,
  "scanners_used": ["slither", "mythril", "securify"],
  "started_at": "2026-01-20T14:00:00Z",
  "completed_at": "2026-01-20T14:05:32Z"
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Delete Scan

```
DELETE /api/v1/scans/{scan_id}
```

Deletes a single scan and its associated results.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Response: `204 No Content`**

**Example:**

```bash
curl -X DELETE "https://api.example.com/api/v1/scans/{scan_id}" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Check Results Ready

```
GET /api/v1/scans/{scan_id}/check-results
```

Checks whether scan results are ready for retrieval.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Response: `200 OK`**

```json
{
  "scan_id": "scan-uuid",
  "ready": true,
  "progress_percent": 100
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/check-results" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Export Results

```
GET /api/v1/scans/{scan_id}/export
```

Exports scan results in the specified format.

| Parameter | Type   | In    | Required | Description                        |
|-----------|--------|-------|----------|------------------------------------|
| `scan_id` | string | path  | yes      | Scan ID                            |
| `format`  | string | query | no       | Export format (`json`, `csv`, `pdf`) |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/export?format=pdf" \
  -H "Authorization: Bearer $TOKEN" \
  -o scan-report.pdf
```

---

### Submit Fuzzing Results

```
POST /api/v1/scans/{scan_id}/fuzzing-results
```

Submits fuzzing results from an external fuzzer for a scan.

| Parameter | Type   | In   | Required | Description           |
|-----------|--------|------|----------|-----------------------|
| `scan_id` | string | path | yes      | Scan ID               |
| `results` | object | body | yes      | Fuzzing result data   |

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/scans/{scan_id}/fuzzing-results" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"results": {"test_cases": 5000, "failures": 3, "coverage": 87.5}}'
```

---

### Submit Results

```
POST /api/v1/scans/{scan_id}/results
```

Submits scan results from an external scanner.

| Parameter | Type   | In   | Required | Description         |
|-----------|--------|------|----------|---------------------|
| `scan_id` | string | path | yes      | Scan ID             |
| `results` | object | body | yes      | Scanner result data |

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/scans/{scan_id}/results" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"results": {"scanner": "slither", "findings": []}}'
```

---

## Result Retrieval Endpoints

### Get Vulnerabilities

```
GET /api/v1/scans/{scan_id}/vulnerabilities
```

Returns all vulnerabilities found in a scan.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Response: `200 OK`**

```json
{
  "vulnerabilities": [
    {
      "id": "vuln-uuid",
      "title": "Reentrancy in withdraw()",
      "severity": "high",
      "category": "reentrancy",
      "line_number": 42,
      "scanner": "slither"
    }
  ],
  "total": 23
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/vulnerabilities" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Vulnerability Breakdown

```
GET /api/v1/scans/{scan_id}/vulnerabilities/breakdown
```

Returns vulnerabilities split by source: scanner results vs intelligence-enriched results.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Response: `200 OK`**

```json
{
  "scanner_results": [
    {"id": "vuln-uuid-1", "title": "Reentrancy", "source": "slither"}
  ],
  "intelligence_results": [
    {"id": "vuln-uuid-2", "title": "Known exploit pattern", "source": "threat_intel"}
  ]
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/vulnerabilities/breakdown" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Result Types

```
GET /api/v1/scans/{scan_id}/result-types
```

Returns the types of results available for a scan.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Response: `200 OK`**

```json
{
  "result_types": [
    "vulnerabilities",
    "code_quality",
    "gas_analysis",
    "fuzzing",
    "formal_verification"
  ]
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/result-types" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Code Quality Findings

```
GET /api/v1/scans/{scan_id}/code-quality
```

Returns code quality findings from the scan.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/code-quality" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Formal Verification Results

```
GET /api/v1/scans/{scan_id}/formal-verification
```

Returns formal verification results for the scan.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/formal-verification" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Fuzzing Results

```
GET /api/v1/scans/{scan_id}/fuzzing
```

Returns fuzzing test results for the scan.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/fuzzing" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Gas Analysis Results

```
GET /api/v1/scans/{scan_id}/gas-analysis
```

Returns gas analysis results for the scan.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `scan_id` | string | path | yes      | Scan ID      |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/scans/{scan_id}/gas-analysis" \
  -H "Authorization: Bearer $TOKEN"
```
