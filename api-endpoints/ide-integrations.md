# IDE Integrations

**Base URL:** `/api/v1/ide-integrations`
**Auth:** Bearer JWT required

## Overview

IDE integration endpoints manage tokens for connecting IDEs (VS Code, IntelliJ, etc.) to the BlockSecOps platform for inline security scanning.

## Endpoints

### Create Integration Token

```
POST /api/v1/ide-integrations
```

**Request Body:**
```json
{
  "name": "VS Code - Main",
  "ide_type": "vscode",
  "permissions": ["scan:create", "scan:read", "contracts:read"]
}
```

### List Integration Tokens

```
GET /api/v1/ide-integrations
```

**Response (200):**
```json
{
  "tokens": [],
  "total": 0
}
```

### Get Available Permissions

```
GET /api/v1/ide-integrations/permissions
```

**Response (200):**
```json
["scan:create", "scan:read", "contracts:read", "contracts:write"]
```

### Get Setup Instructions

```
GET /api/v1/ide-integrations/setup/{ide_type}
```

Returns setup instructions for the specified IDE type (vscode, intellij, vim, etc.).

### Get Token

```
GET /api/v1/ide-integrations/{token_id}
```

### Update Token

```
PATCH /api/v1/ide-integrations/{token_id}
```

### Delete Token

```
DELETE /api/v1/ide-integrations/{token_id}
```

### Regenerate Token

```
POST /api/v1/ide-integrations/{token_id}/regenerate
```

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /ide-integrations | 200 | 0 tokens |
| GET /permissions | 200 | 4 permissions |
