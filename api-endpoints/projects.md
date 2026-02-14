# Projects

**Base URL:** `/api/v1/projects`
**Auth:** Bearer JWT required

## Overview

Projects group contracts and scans together for team collaboration, access control, and quality gate enforcement.

## Endpoints

### Create Project

```
POST /api/v1/projects
```

**Request Body:**
```json
{
  "name": "DeFi Protocol v2",
  "description": "Main DeFi protocol smart contracts",
  "language": "solidity",
  "visibility": "private"
}
```

### List Projects

```
GET /api/v1/projects
```

**Response (200):**
```json
{
  "projects": [],
  "total": 0,
  "page": 1,
  "page_size": 20
}
```

### Get Project

```
GET /api/v1/projects/{project_id}
```

### Update Project

```
PATCH /api/v1/projects/{project_id}
```

### Delete Project

```
DELETE /api/v1/projects/{project_id}
```

### Get Project Contracts

```
GET /api/v1/projects/{project_id}/contracts
```

### Add Contract to Project

```
POST /api/v1/projects/{project_id}/contracts
```

### Remove Contract from Project

```
DELETE /api/v1/projects/{project_id}/contracts/{contract_id}
```

### Get Project Scans

```
GET /api/v1/projects/{project_id}/scans
```

### Get Project Statistics

```
GET /api/v1/projects/{project_id}/stats
```

### Get Project Members

```
GET /api/v1/projects/{project_id}/members
```

### Add Project Member

```
POST /api/v1/projects/{project_id}/members
```

### Remove Project Member

```
DELETE /api/v1/projects/{project_id}/members/{user_id}
```

### Get Project Activity

```
GET /api/v1/projects/{project_id}/activity
```

### Get Project Settings

```
GET /api/v1/projects/{project_id}/settings
```

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /projects | 200 | 0 projects |
