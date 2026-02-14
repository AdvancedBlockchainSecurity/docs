# AI Code Review API

Base URL: `/api/v1/review`

This module provides AI-powered code review suggestions for detected vulnerabilities, including severity assessment, confidence scoring, and a feedback loop for continuous improvement.

---

## Endpoints

### Generate AI Review Suggestion

Creates a new AI-generated review suggestion for a given vulnerability.

**`POST /api/v1/review/suggestions`**

#### Request Body

| Field              | Type   | Required | Description                          |
|--------------------|--------|----------|--------------------------------------|
| `vulnerability_id` | string | Yes      | UUID of the vulnerability to review  |
| `context`          | string | No       | Additional context for the AI model  |
| `language`         | string | No       | Programming language of the source   |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/review/suggestions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "context": "Solidity reentrancy in withdraw function",
    "language": "solidity"
  }'
```

#### Response `201 Created`

```json
{
  "id": "f8e7d6c5-b4a3-2190-fedc-ba0987654321",
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "type": "security_fix",
  "severity": "critical",
  "confidence": 0.92,
  "suggestion_text": "Add a reentrancy guard modifier to the withdraw function...",
  "risk_explanation": "Without a reentrancy guard, an attacker can recursively call withdraw() before the balance is updated.",
  "created_at": "2026-02-14T10:30:00Z"
}
```

---

### List All Review Suggestions

Returns a paginated list of all AI-generated review suggestions.

**`GET /api/v1/review/suggestions`**

#### Query Parameters

| Parameter | Type    | Default | Description                        |
|-----------|---------|---------|------------------------------------|
| `page`    | integer | 1       | Page number                        |
| `limit`   | integer | 20      | Results per page (max 100)         |
| `severity`| string  | —       | Filter by severity level           |
| `type`    | string  | —       | Filter by suggestion type          |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/review/suggestions?page=1&limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "suggestions": [
    {
      "id": "f8e7d6c5-b4a3-2190-fedc-ba0987654321",
      "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "type": "security_fix",
      "severity": "critical",
      "confidence": 0.92,
      "suggestion_text": "Add a reentrancy guard modifier to the withdraw function...",
      "risk_explanation": "Without a reentrancy guard, an attacker can recursively call withdraw() before the balance is updated."
    },
    {
      "id": "11223344-5566-7788-99aa-bbccddeeff00",
      "vulnerability_id": "deadbeef-cafe-1234-5678-abcdef012345",
      "type": "best_practice",
      "severity": "medium",
      "confidence": 0.87,
      "suggestion_text": "Use SafeMath for arithmetic operations to prevent overflow...",
      "risk_explanation": "Integer overflow can allow an attacker to manipulate token balances."
    }
  ],
  "total": 2
}
```

---

### Get Suggestions for a Specific Vulnerability

Retrieves all review suggestions associated with a particular vulnerability.

**`GET /api/v1/review/suggestions/{vulnerability_id}`**

#### Path Parameters

| Parameter          | Type   | Description                          |
|--------------------|--------|--------------------------------------|
| `vulnerability_id` | string | UUID of the target vulnerability     |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/review/suggestions/a1b2c3d4-e5f6-7890-abcd-ef1234567890 \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "suggestions": [
    {
      "id": "f8e7d6c5-b4a3-2190-fedc-ba0987654321",
      "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "type": "security_fix",
      "severity": "critical",
      "confidence": 0.92,
      "suggestion_text": "Add a reentrancy guard modifier to the withdraw function...",
      "risk_explanation": "Without a reentrancy guard, an attacker can recursively call withdraw() before the balance is updated."
    }
  ],
  "total": 1
}
```

---

### Get Review Statistics

Returns aggregate statistics for all AI review suggestions and feedback.

**`GET /api/v1/review/stats`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/review/stats \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "total_suggestions": 2,
  "total_feedback": 0,
  "tokens_used_total": 4314
}
```

#### Response Schema

| Field               | Type    | Description                              |
|---------------------|---------|------------------------------------------|
| `total_suggestions` | integer | Total number of suggestions generated    |
| `total_feedback`    | integer | Total feedback entries received           |
| `tokens_used_total` | integer | Cumulative LLM token usage across calls  |

---

### Submit Feedback on a Suggestion

Allows users to provide feedback on the quality or accuracy of a suggestion.

**`POST /api/v1/review/feedback`**

#### Request Body

| Field           | Type    | Required | Description                                  |
|-----------------|---------|----------|----------------------------------------------|
| `suggestion_id` | string  | Yes      | UUID of the suggestion being reviewed        |
| `rating`        | string  | Yes      | One of: `helpful`, `not_helpful`, `incorrect`|
| `comment`       | string  | No       | Free-text feedback from the reviewer         |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/review/feedback \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "suggestion_id": "f8e7d6c5-b4a3-2190-fedc-ba0987654321",
    "rating": "helpful",
    "comment": "Accurate suggestion, applied the fix successfully."
  }'
```

#### Response `201 Created`

```json
{
  "id": "aabbccdd-1122-3344-5566-778899001122",
  "suggestion_id": "f8e7d6c5-b4a3-2190-fedc-ba0987654321",
  "rating": "helpful",
  "comment": "Accurate suggestion, applied the fix successfully.",
  "created_at": "2026-02-14T11:00:00Z"
}
```

---

### Get Feedback for a Suggestion

Retrieves all feedback entries for a specific suggestion.

**`GET /api/v1/review/feedback/{suggestion_id}`**

#### Path Parameters

| Parameter       | Type   | Description                      |
|-----------------|--------|----------------------------------|
| `suggestion_id` | string | UUID of the target suggestion   |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/review/feedback/f8e7d6c5-b4a3-2190-fedc-ba0987654321 \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "feedback": [
    {
      "id": "aabbccdd-1122-3344-5566-778899001122",
      "suggestion_id": "f8e7d6c5-b4a3-2190-fedc-ba0987654321",
      "rating": "helpful",
      "comment": "Accurate suggestion, applied the fix successfully.",
      "created_at": "2026-02-14T11:00:00Z"
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
  "detail": "Vulnerability not found",
  "status_code": 404
}
```
