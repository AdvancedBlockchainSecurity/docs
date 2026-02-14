# Tags

**Base URL:** `/api/v1/tags`
**Auth:** Bearer JWT required

## Overview

Tags provide a flexible labeling system for organizing contracts, scans, and vulnerabilities. Tags support filtering, search, and batch operations.

## Endpoints

### Create Tag

```
POST /api/v1/tags
```

**Request Body:**
```json
{
  "name": "production",
  "color": "#22c55e",
  "description": "Production-deployed contracts"
}
```

### List Tags

```
GET /api/v1/tags
```

**Response (200):**
```json
{
  "tags": [],
  "total": 0
}
```

### Get Tag

```
GET /api/v1/tags/{tag_id}
```

### Update Tag

```
PATCH /api/v1/tags/{tag_id}
```

### Delete Tag

```
DELETE /api/v1/tags/{tag_id}
```

### Apply Tag to Entity

```
POST /api/v1/tags/{tag_id}/apply
```

**Request Body:**
```json
{
  "entity_type": "contract",
  "entity_id": "uuid"
}
```

### Remove Tag from Entity

```
DELETE /api/v1/tags/{tag_id}/entities/{entity_type}/{entity_id}
```

### Get Entities by Tag

```
GET /api/v1/tags/{tag_id}/entities
```

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /tags | 200 | 0 tags |
