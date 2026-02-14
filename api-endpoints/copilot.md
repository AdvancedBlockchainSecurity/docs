# Copilot - AI Security Assistant

**Base URL:** `/api/v1/copilot`
**Auth:** Bearer JWT required
**Tier:** Enterprise

## Overview

The Copilot API provides conversational AI security assistance. Users can create conversations, send messages about vulnerabilities, and receive AI-generated security analysis.

## Endpoints

### List Conversations

```
GET /api/v1/copilot/conversations
```

**Response (200):**
```json
{
  "conversations": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "title": "Reentrancy Analysis",
      "message_count": 4,
      "total_tokens": 2500,
      "created_at": "2026-02-13T...",
      "updated_at": "2026-02-13T..."
    }
  ],
  "total": 5,
  "limit": 20,
  "offset": 0
}
```

### Create Conversation

```
POST /api/v1/copilot/conversations
```

**Request Body:**
```json
{
  "title": "Analyze reentrancy vulnerability"
}
```

### Get Conversation

```
GET /api/v1/copilot/conversations/{conversation_id}
```

### Update Conversation

```
PATCH /api/v1/copilot/conversations/{conversation_id}
```

### Delete Conversation

```
DELETE /api/v1/copilot/conversations/{conversation_id}
```

### Archive Conversation

```
POST /api/v1/copilot/conversations/{conversation_id}/archive
```

### Send Message

```
POST /api/v1/copilot/conversations/{conversation_id}/messages
```

**Request Body:**
```json
{
  "content": "Explain the reentrancy vulnerability in this contract",
  "vulnerability_id": "uuid (optional)",
  "contract_id": "uuid (optional)"
}
```

### Summarize Conversation

```
POST /api/v1/copilot/conversations/{conversation_id}/summarize
```

### Rate Message

```
POST /api/v1/copilot/messages/{message_id}/rate
```

**Request Body:**
```json
{
  "rating": 5,
  "feedback": "Very helpful analysis"
}
```

## Example Usage

```bash
# List conversations
curl -H "Authorization: Bearer $TOKEN" \
  https://app.blocksecops.local/api/v1/copilot/conversations

# Send a message
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content":"What is the impact of this reentrancy?"}' \
  https://app.blocksecops.local/api/v1/copilot/conversations/{id}/messages
```

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /conversations | 200 | 5 conversations found |
| POST /conversations | - | Not tested (write) |
| POST /.../messages | - | Not tested (write) |
