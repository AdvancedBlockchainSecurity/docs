# Search

**Base URL:** `/api/v1/search`
**Auth:** Bearer JWT required

## Overview

The search API provides quick search across all resources (contracts, vulnerabilities, scans) and saved search management.

## Endpoints

### Quick Search

```
GET /api/v1/search/quick?q={query}
```

**Parameters:**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| q | string | Yes | Search query |

**Response (200):**
```json
{
  "query": "reentrancy",
  "results": [
    {
      "id": "96d51f58-...",
      "type": "contract",
      "title": "SemgrepTestContract",
      "subtitle": "Line 12: // Reentrancy vulnerability",
      "url": "/contracts/96d51f58-..."
    }
  ],
  "total": 1,
  "query_time_ms": 52.9
}
```

### Advanced Search

```
POST /api/v1/search
```

**Request Body:**
```json
{
  "query": "reentrancy",
  "filters": {
    "type": ["vulnerability", "contract"],
    "severity": ["critical", "high"],
    "scanner": ["slither"]
  },
  "page": 1,
  "page_size": 20
}
```

### Export Search Results

```
POST /api/v1/search/export
```

### List Saved Searches

```
GET /api/v1/search/saved
```

**Response (200):**
```json
{
  "saved_searches": [],
  "total": 0,
  "page": 1,
  "page_size": 50
}
```

### Create Saved Search

```
POST /api/v1/search/saved
```

### Delete Saved Search

```
DELETE /api/v1/search/saved/{search_id}
```

### Execute Saved Search

```
POST /api/v1/search/saved/{search_id}/execute
```

## Example Usage

```bash
# Quick search
curl -H "Authorization: Bearer $TOKEN" \
  "https://app.blocksecops.local/api/v1/search/quick?q=reentrancy"

# Advanced search
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"overflow","filters":{"severity":["critical"]}}' \
  https://app.blocksecops.local/api/v1/search
```

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /quick?q=reentrancy | 200 | 1 result, 52.9ms |
| GET /saved | 200 | 0 saved searches |
