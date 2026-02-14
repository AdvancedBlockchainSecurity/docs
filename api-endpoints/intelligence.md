# Intelligence API

Base URL: `/api/v1/intelligence`

This module provides access to the blockchain security intelligence database, including real-world exploit records, CVE data, NVD integration, vulnerability pattern matching, semantic search, and SWC-to-CVE mappings.

---

## Endpoints

### Get Intelligence Statistics

Returns aggregate statistics for the intelligence database.

**`GET /api/v1/intelligence/stats`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/intelligence/stats \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "exploit_count": 3,
  "cve_count": 3,
  "total_loss_usd": 882000000,
  "chains": ["ethereum", "bsc", "polygon"],
  "attack_vectors": ["reentrancy", "flash_loan", "access_control"]
}
```

#### Response Schema

| Field            | Type     | Description                                      |
|------------------|----------|--------------------------------------------------|
| `exploit_count`  | integer  | Total number of exploit records in the database  |
| `cve_count`      | integer  | Total number of CVE records                      |
| `total_loss_usd` | integer  | Cumulative financial loss across all exploits     |
| `chains`         | string[] | List of blockchain networks represented          |
| `attack_vectors` | string[] | List of distinct attack vectors                  |

---

### List CVEs

Returns a paginated list of CVE records with severity and CVSS scores.

**`GET /api/v1/intelligence/cves`**

#### Query Parameters

| Parameter  | Type    | Default | Description                            |
|------------|---------|---------|----------------------------------------|
| `page`     | integer | 1       | Page number                            |
| `limit`    | integer | 20      | Results per page (max 100)             |
| `severity` | string  | —       | Filter by severity (low, medium, high, critical) |
| `keyword`  | string  | —       | Search in CVE descriptions             |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/intelligence/cves?page=1&limit=10&severity=critical" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "cves": [
    {
      "id": "cve-aabb1122-3344-5566-7788-99aabbccddee",
      "cve_id": "CVE-2023-26067",
      "description": "Reentrancy vulnerability in ERC-4626 vault implementations",
      "severity": "critical",
      "cvss_score": 9.8,
      "published_at": "2023-03-15T00:00:00Z"
    }
  ],
  "total": 3,
  "page": 1,
  "limit": 10
}
```

---

### Get CVE Detail

Retrieves the full detail of a specific CVE record.

**`GET /api/v1/intelligence/cves/{cve_id}`**

#### Path Parameters

| Parameter | Type   | Description                   |
|-----------|--------|-------------------------------|
| `cve_id`  | string | CVE identifier or internal ID |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/intelligence/cves/CVE-2023-26067 \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "id": "cve-aabb1122-3344-5566-7788-99aabbccddee",
  "cve_id": "CVE-2023-26067",
  "description": "Reentrancy vulnerability in ERC-4626 vault implementations",
  "severity": "critical",
  "cvss_score": 9.8,
  "affected_versions": ["OpenZeppelin < 4.8.2"],
  "references": ["https://nvd.nist.gov/vuln/detail/CVE-2023-26067"],
  "published_at": "2023-03-15T00:00:00Z",
  "updated_at": "2023-04-01T00:00:00Z"
}
```

---

### List Exploit Records

Returns a paginated list of real-world exploit records from the intelligence database.

**`GET /api/v1/intelligence/exploits`**

#### Query Parameters

| Parameter       | Type    | Default | Description                          |
|-----------------|---------|---------|--------------------------------------|
| `page`          | integer | 1       | Page number                          |
| `limit`         | integer | 20      | Results per page (max 100)           |
| `chain`         | string  | —       | Filter by blockchain network         |
| `attack_vector` | string  | —       | Filter by attack vector              |
| `min_loss`      | integer | —       | Minimum loss in USD                  |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/intelligence/exploits?chain=ethereum&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "exploits": [
    {
      "id": "intel-11223344-5566-7788-99aa-bbccddeeff00",
      "protocol": "Euler Finance",
      "chain": "ethereum",
      "attack_vector": "flash_loan",
      "loss_usd": 197000000,
      "date": "2023-03-13T00:00:00Z",
      "description": "Flash loan attack exploiting donation vulnerability in ERC-4626"
    }
  ],
  "total": 3,
  "page": 1,
  "limit": 10
}
```

---

### Get Exploit Record Detail

Retrieves the full detail of a specific intelligence exploit record.

**`GET /api/v1/intelligence/exploits/{exploit_id}`**

#### Path Parameters

| Parameter    | Type   | Description                     |
|--------------|--------|---------------------------------|
| `exploit_id` | string | UUID of the exploit record     |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/intelligence/exploits/intel-11223344-5566-7788-99aa-bbccddeeff00 \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "id": "intel-11223344-5566-7788-99aa-bbccddeeff00",
  "protocol": "Euler Finance",
  "chain": "ethereum",
  "attack_vector": "flash_loan",
  "loss_usd": 197000000,
  "date": "2023-03-13T00:00:00Z",
  "description": "Flash loan attack exploiting donation vulnerability in ERC-4626",
  "tx_hashes": ["0xc310a0af..."],
  "references": ["https://rekt.news/euler-rekt/"],
  "related_cves": ["CVE-2023-26067"]
}
```

---

### Enrich Vulnerability with Intelligence

Enriches a detected vulnerability with related intelligence data (exploits, CVEs, patterns).

**`POST /api/v1/intelligence/enrich`**

#### Request Body

| Field              | Type   | Required | Description                               |
|--------------------|--------|----------|-------------------------------------------|
| `vulnerability_id` | string | Yes      | UUID of the vulnerability to enrich       |
| `include_cves`     | bool   | No       | Include related CVEs (default: true)      |
| `include_exploits` | bool   | No       | Include related exploits (default: true)  |
| `include_patterns` | bool   | No       | Include matched patterns (default: true)  |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/intelligence/enrich \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "include_cves": true,
    "include_exploits": true,
    "include_patterns": true
  }'
```

#### Response `200 OK`

```json
{
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "related_cves": ["CVE-2023-26067"],
  "related_exploits": ["intel-11223344-5566-7788-99aa-bbccddeeff00"],
  "matched_patterns": ["BVD-REEN-001"],
  "risk_score": 9.2,
  "enriched_at": "2026-02-14T10:30:00Z"
}
```

---

### Bulk Import Exploits and CVEs

Imports exploit and CVE records in bulk into the intelligence database.

**`POST /api/v1/intelligence/import`**

#### Request Body

| Field      | Type   | Required | Description                         |
|------------|--------|----------|-------------------------------------|
| `exploits` | array  | No       | Array of exploit records to import  |
| `cves`     | array  | No       | Array of CVE records to import      |
| `source`   | string | No       | Data source identifier              |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/intelligence/import \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "exploits": [
      {
        "protocol": "Ronin Network",
        "chain": "ethereum",
        "attack_vector": "access_control",
        "loss_usd": 625000000,
        "date": "2022-03-23",
        "description": "Private key compromise via social engineering"
      }
    ],
    "source": "manual_import"
  }'
```

#### Response `201 Created`

```json
{
  "imported_exploits": 1,
  "imported_cves": 0,
  "errors": []
}
```

---

### Get Recent NVD CVEs for Smart Contracts

Returns recent CVEs from the National Vulnerability Database relevant to smart contracts.

**`GET /api/v1/intelligence/nvd/recent/smart-contracts`**

#### Query Parameters

| Parameter | Type    | Default | Description                    |
|-----------|---------|---------|--------------------------------|
| `days`    | integer | 30      | Lookback period in days        |
| `limit`   | integer | 20      | Maximum results to return      |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/intelligence/nvd/recent/smart-contracts?days=30&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "cves": [
    {
      "cve_id": "CVE-2026-12345",
      "description": "Integer overflow in Solidity compiler versions < 0.8.0",
      "severity": "high",
      "cvss_score": 8.1,
      "published_at": "2026-01-20T00:00:00Z"
    }
  ],
  "total": 1,
  "lookback_days": 30
}
```

---

### Get NVD CVE Detail

Retrieves detailed NVD data for a specific CVE.

**`GET /api/v1/intelligence/nvd/{cve_id}`**

#### Path Parameters

| Parameter | Type   | Description        |
|-----------|--------|--------------------|
| `cve_id`  | string | CVE identifier     |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/intelligence/nvd/CVE-2026-12345 \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "cve_id": "CVE-2026-12345",
  "description": "Integer overflow in Solidity compiler versions < 0.8.0",
  "severity": "high",
  "cvss_v3": {
    "score": 8.1,
    "vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N"
  },
  "references": ["https://nvd.nist.gov/vuln/detail/CVE-2026-12345"],
  "cpe_matches": ["cpe:2.3:a:ethereum:solidity:*:*:*:*:*:*:*:*"],
  "published_at": "2026-01-20T00:00:00Z",
  "last_modified": "2026-01-25T00:00:00Z"
}
```

---

### Regenerate Embeddings

Triggers regeneration of vector embeddings for the intelligence database.

**`POST /api/v1/intelligence/regenerate-embeddings`**

#### Request Body

| Field  | Type   | Required | Description                                    |
|--------|--------|----------|------------------------------------------------|
| `scope`| string | No       | One of: `all`, `exploits`, `cves`, `patterns` |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/intelligence/regenerate-embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "scope": "all"
  }'
```

#### Response `202 Accepted`

```json
{
  "task_id": "task-aabbccdd-1122-3344-5566-778899001122",
  "status": "processing",
  "message": "Embedding regeneration started for scope: all"
}
```

---

### Semantic Search

Performs a semantic search across the intelligence database using vector embeddings.

**`POST /api/v1/intelligence/search`**

#### Request Body

| Field     | Type    | Required | Description                               |
|-----------|---------|----------|-------------------------------------------|
| `query`   | string  | Yes      | Natural language search query             |
| `limit`   | integer | No       | Maximum results (default: 10)             |
| `filters` | object  | No       | Optional filters (chain, severity, etc.)  |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/intelligence/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "query": "flash loan attacks on lending protocols",
    "limit": 5,
    "filters": {
      "chain": "ethereum"
    }
  }'
```

#### Response `200 OK`

```json
{
  "results": [
    {
      "id": "intel-11223344-5566-7788-99aa-bbccddeeff00",
      "type": "exploit",
      "title": "Euler Finance Flash Loan Attack",
      "score": 0.94,
      "snippet": "Flash loan attack exploiting donation vulnerability..."
    }
  ],
  "total": 1,
  "query": "flash loan attacks on lending protocols"
}
```

---

### Get SWC-to-CVE Mappings

Returns the mapping between SWC (Smart Contract Weakness Classification) IDs and related CVEs.

**`GET /api/v1/intelligence/swc-mapping`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/intelligence/swc-mapping \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "mappings": [
    {
      "swc_id": "SWC-107",
      "swc_title": "Reentrancy",
      "related_cves": ["CVE-2023-26067"],
      "related_patterns": ["BVD-REEN-001", "BVD-REEN-002"]
    },
    {
      "swc_id": "SWC-101",
      "swc_title": "Integer Overflow and Underflow",
      "related_cves": ["CVE-2018-10299"],
      "related_patterns": ["BVD-MATH-001"]
    }
  ],
  "total": 2
}
```

---

### List Vulnerability Patterns

Returns a paginated list of vulnerability patterns from the intelligence database.

**`GET /api/v1/intelligence/patterns`**

#### Query Parameters

| Parameter  | Type    | Default | Description                    |
|------------|---------|---------|--------------------------------|
| `page`     | integer | 1       | Page number                    |
| `limit`    | integer | 20      | Results per page (max 100)     |
| `category` | string  | —       | Filter by pattern category     |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/intelligence/patterns?page=1&limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "patterns": [
    {
      "id": "pat-11223344-5566-7788-99aa-bbccddeeff00",
      "pattern_id": "BVD-REEN-001",
      "title": "Cross-Function Reentrancy",
      "category": "reentrancy",
      "severity": "critical",
      "description": "Reentrancy via cross-function calls within the same contract"
    }
  ],
  "total": 413
}
```

---

### Get Pattern Detail

Retrieves the full detail of a specific vulnerability pattern.

**`GET /api/v1/intelligence/patterns/{pattern_id}`**

#### Path Parameters

| Parameter    | Type   | Description                         |
|--------------|--------|-------------------------------------|
| `pattern_id` | string | Pattern ID or UUID                 |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/intelligence/patterns/BVD-REEN-001 \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "id": "pat-11223344-5566-7788-99aa-bbccddeeff00",
  "pattern_id": "BVD-REEN-001",
  "title": "Cross-Function Reentrancy",
  "category": "reentrancy",
  "severity": "critical",
  "description": "Reentrancy via cross-function calls within the same contract",
  "detection_signatures": ["external_call_before_state_update"],
  "remediation": "Apply checks-effects-interactions pattern or use a reentrancy guard.",
  "references": ["SWC-107"],
  "related_cves": ["CVE-2023-26067"],
  "created_at": "2025-06-01T00:00:00Z"
}
```

---

### Get Pattern Statistics

Returns usage and detection statistics for a specific vulnerability pattern.

**`GET /api/v1/intelligence/patterns/{pattern_id}/statistics`**

#### Path Parameters

| Parameter    | Type   | Description                         |
|--------------|--------|-------------------------------------|
| `pattern_id` | string | Pattern ID or UUID                 |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/intelligence/patterns/BVD-REEN-001/statistics \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "pattern_id": "BVD-REEN-001",
  "total_detections": 142,
  "true_positives": 128,
  "false_positives": 14,
  "precision": 0.90,
  "last_detected_at": "2026-02-13T15:30:00Z",
  "top_scanners": [
    {"scanner": "slither", "detections": 85},
    {"scanner": "mythril", "detections": 42}
  ]
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
| `422`  | Unprocessable entity      |
| `500`  | Internal server error     |

```json
{
  "detail": "CVE not found: CVE-9999-99999",
  "status_code": 404
}
```
