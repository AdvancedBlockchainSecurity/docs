# AI Code Repair API

Base URL: `/api/v1/code-repair`

This module provides AI-powered automatic code repair generation for detected vulnerabilities. It produces fix suggestions with original and fixed code snippets, confidence scores, and an application workflow.

---

## Endpoints

### Generate AI Repair

Generates an AI-powered code repair for a given vulnerability.

**`POST /api/v1/code-repair/generate`**

#### Request Body

| Field              | Type   | Required | Description                             |
|--------------------|--------|----------|-----------------------------------------|
| `vulnerability_id` | string | Yes      | UUID of the vulnerability to repair     |
| `fix_strategy`     | string | No       | Strategy hint: `minimal`, `comprehensive` |
| `language`         | string | No       | Source language (e.g., `solidity`)       |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/code-repair/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "fix_strategy": "minimal",
    "language": "solidity"
  }'
```

#### Response `201 Created`

```json
{
  "id": "rep-00112233-4455-6677-8899-aabbccddeeff",
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "fix_type": "reentrancy_guard",
  "confidence": 0.95,
  "original_code": "function withdraw(uint amount) public {\n    require(balances[msg.sender] >= amount);\n    msg.sender.call{value: amount}(\"\");\n    balances[msg.sender] -= amount;\n}",
  "fixed_code": "function withdraw(uint amount) public nonReentrant {\n    require(balances[msg.sender] >= amount);\n    balances[msg.sender] -= amount;\n    msg.sender.call{value: amount}(\"\");\n}",
  "explanation": "Applied checks-effects-interactions pattern and added nonReentrant modifier.",
  "status": "pending",
  "created_at": "2026-02-14T10:30:00Z"
}
```

---

### List All Repairs

Returns a paginated list of all generated code repairs.

**`GET /api/v1/code-repair/repairs`**

#### Query Parameters

| Parameter   | Type    | Default | Description                          |
|-------------|---------|---------|--------------------------------------|
| `page`      | integer | 1       | Page number                          |
| `limit`     | integer | 20      | Results per page (max 100)           |
| `fix_type`  | string  | —       | Filter by fix type                   |
| `status`    | string  | —       | Filter by status: `pending`, `applied`, `rejected` |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/code-repair/repairs?page=1&limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "repairs": [
    {
      "id": "rep-00112233-4455-6677-8899-aabbccddeeff",
      "fix_type": "reentrancy_guard",
      "confidence": 0.95,
      "original_code": "function withdraw(uint amount) public { ... }",
      "fixed_code": "function withdraw(uint amount) public nonReentrant { ... }",
      "explanation": "Applied checks-effects-interactions pattern and added nonReentrant modifier."
    },
    {
      "id": "rep-11223344-5566-7788-99aa-bbccddeeff00",
      "fix_type": "access_control",
      "confidence": 0.97,
      "original_code": "function setOwner(address _owner) public { ... }",
      "fixed_code": "function setOwner(address _owner) public onlyOwner { ... }",
      "explanation": "Added onlyOwner modifier to restrict access."
    },
    {
      "id": "rep-22334455-6677-8899-aabb-ccddeeff0011",
      "fix_type": "overflow_protection",
      "confidence": 0.93,
      "original_code": "uint256 result = a + b;",
      "fixed_code": "uint256 result = a.add(b);",
      "explanation": "Replaced raw arithmetic with SafeMath to prevent overflow."
    }
  ],
  "total": 3
}
```

---

### Get Repair Detail

Retrieves the full detail of a specific repair.

**`GET /api/v1/code-repair/repairs/{repair_id}`**

#### Path Parameters

| Parameter   | Type   | Description              |
|-------------|--------|--------------------------|
| `repair_id` | string | UUID of the repair       |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/code-repair/repairs/rep-00112233-4455-6677-8899-aabbccddeeff \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "id": "rep-00112233-4455-6677-8899-aabbccddeeff",
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "fix_type": "reentrancy_guard",
  "confidence": 0.95,
  "original_code": "function withdraw(uint amount) public {\n    require(balances[msg.sender] >= amount);\n    msg.sender.call{value: amount}(\"\");\n    balances[msg.sender] -= amount;\n}",
  "fixed_code": "function withdraw(uint amount) public nonReentrant {\n    require(balances[msg.sender] >= amount);\n    balances[msg.sender] -= amount;\n    msg.sender.call{value: amount}(\"\");\n}",
  "explanation": "Applied checks-effects-interactions pattern and added nonReentrant modifier.",
  "status": "pending",
  "created_at": "2026-02-14T10:30:00Z",
  "updated_at": "2026-02-14T10:30:00Z"
}
```

---

### Delete a Repair

Permanently removes a repair record.

**`DELETE /api/v1/code-repair/repairs/{repair_id}`**

#### Path Parameters

| Parameter   | Type   | Description              |
|-------------|--------|--------------------------|
| `repair_id` | string | UUID of the repair       |

#### Example Request

```bash
curl -X DELETE http://localhost:8000/api/v1/code-repair/repairs/rep-00112233-4455-6677-8899-aabbccddeeff \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `204 No Content`

No response body.

---

### Apply a Repair

Marks a repair as applied and triggers any downstream integrations (e.g., creating a PR).

**`POST /api/v1/code-repair/repairs/{repair_id}/apply`**

#### Path Parameters

| Parameter   | Type   | Description              |
|-------------|--------|--------------------------|
| `repair_id` | string | UUID of the repair       |

#### Request Body

| Field         | Type    | Required | Description                          |
|---------------|---------|----------|--------------------------------------|
| `create_pr`   | boolean | No       | Whether to create a pull request     |
| `branch_name` | string  | No       | Target branch name for the PR        |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/code-repair/repairs/rep-00112233-4455-6677-8899-aabbccddeeff/apply \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "create_pr": true,
    "branch_name": "fix/reentrancy-guard"
  }'
```

#### Response `200 OK`

```json
{
  "id": "rep-00112233-4455-6677-8899-aabbccddeeff",
  "status": "applied",
  "applied_at": "2026-02-14T11:00:00Z",
  "pr_url": "https://github.com/org/repo/pull/42"
}
```

---

### Submit Feedback on a Repair

Provides feedback on the quality of a generated repair.

**`POST /api/v1/code-repair/repairs/{repair_id}/feedback`**

#### Path Parameters

| Parameter   | Type   | Description              |
|-------------|--------|--------------------------|
| `repair_id` | string | UUID of the repair       |

#### Request Body

| Field    | Type   | Required | Description                                         |
|----------|--------|----------|-----------------------------------------------------|
| `rating` | string | Yes      | One of: `correct`, `partially_correct`, `incorrect` |
| `comment`| string | No       | Free-text feedback                                  |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/code-repair/repairs/rep-00112233-4455-6677-8899-aabbccddeeff/feedback \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "rating": "correct",
    "comment": "Fix resolved the reentrancy issue without side effects."
  }'
```

#### Response `201 Created`

```json
{
  "id": "fb-aabbccdd-1122-3344-5566-778899001122",
  "repair_id": "rep-00112233-4455-6677-8899-aabbccddeeff",
  "rating": "correct",
  "comment": "Fix resolved the reentrancy issue without side effects.",
  "created_at": "2026-02-14T11:15:00Z"
}
```

---

### Get Repair Statistics

Returns aggregate statistics for all code repairs.

**`GET /api/v1/code-repair/statistics`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/code-repair/statistics \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "total_repairs": 3,
  "applied_repairs": 0,
  "average_confidence": 0.95
}
```

#### Response Schema

| Field                | Type    | Description                             |
|----------------------|---------|-----------------------------------------|
| `total_repairs`      | integer | Total number of repairs generated       |
| `applied_repairs`    | integer | Number of repairs that have been applied|
| `average_confidence` | float   | Mean confidence score across all repairs|

---

### Get Repairs for a Vulnerability

Retrieves all repair records associated with a specific vulnerability.

**`GET /api/v1/code-repair/vulnerabilities/{vulnerability_id}/repairs`**

#### Path Parameters

| Parameter          | Type   | Description                          |
|--------------------|--------|--------------------------------------|
| `vulnerability_id` | string | UUID of the target vulnerability     |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/code-repair/vulnerabilities/a1b2c3d4-e5f6-7890-abcd-ef1234567890/repairs \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "repairs": [
    {
      "id": "rep-00112233-4455-6677-8899-aabbccddeeff",
      "fix_type": "reentrancy_guard",
      "confidence": 0.95,
      "status": "pending",
      "explanation": "Applied checks-effects-interactions pattern and added nonReentrant modifier."
    }
  ],
  "total": 1
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
| `500`  | Internal server error     |

```json
{
  "detail": "Repair not found",
  "status_code": 404
}
```
