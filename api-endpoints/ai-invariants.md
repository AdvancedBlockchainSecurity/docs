# AI Invariants

**Base URL:** `/api/v1/invariants`
**Auth:** Bearer JWT required
**Tier:** Growth+

## Overview

The invariants API generates formal invariant properties for smart contracts that can be used with fuzzing and formal verification tools. Invariants define conditions that must always hold true.

## Endpoints

### List Invariants

```
GET /api/v1/invariants
```

**Response (200):**
```json
{
  "invariants": [],
  "total": 0,
  "limit": 20,
  "offset": 0
}
```

### Generate Invariants

```
POST /api/v1/invariants/generate
```

**Request Body:**
```json
{
  "vulnerability_id": "uuid",
  "contract_id": "uuid"
}
```

### Get Invariant

```
GET /api/v1/invariants/{invariant_id}
```

### Delete Invariant

```
DELETE /api/v1/invariants/{invariant_id}
```

### Apply Invariant

```
POST /api/v1/invariants/{invariant_id}/apply
```

Marks an invariant as applied to the codebase.

### Submit Feedback

```
POST /api/v1/invariants/{invariant_id}/feedback
```

### Get Invariants for Contract

```
GET /api/v1/invariants/contracts/{contract_id}
```

### List Templates

```
GET /api/v1/invariants/templates
```

**Status: 500** - Route conflict: "templates" is being parsed as a UUID path parameter.

### Get Template

```
GET /api/v1/invariants/templates/{template_id}
```

### Get User Quota

```
GET /api/v1/invariants/user/quota
```

**Status: 500** - `AttributeError: 'Tier' object has no attribute 'get'`

### Get User Statistics

```
GET /api/v1/invariants/user/statistics
```

**Response (200):**
```json
{
  "total_invariants": 0,
  "applied_invariants": 0,
  "helpful_invariants": 0,
  "valid_invariants": 0,
  "application_rate": 0.0,
  "validity_rate": 0.0,
  "average_confidence": 0.0,
  "average_rating": null,
  "by_type": {}
}
```

## Known Issues

| Issue | Endpoint | Description |
|-------|----------|-------------|
| Route conflict | GET /templates | "templates" interpreted as UUID path param; returns 500 with SQL error |
| Tier attribute error | GET /user/quota | Tier enum/object lacks `.get()` method; returns 500 |

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /invariants | 200 | 0 invariants |
| GET /templates | 500 | Route conflict bug |
| GET /user/quota | 500 | Tier attribute bug |
| GET /user/statistics | 200 | Empty stats |
