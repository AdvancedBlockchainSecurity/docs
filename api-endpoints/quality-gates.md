# Quality Gates

**Base URL:** `/api/v1/quality-gates`
**Auth:** Bearer JWT required
**Tier:** Growth+

## Overview

Quality gates provide CI/CD integration for enforcing security standards. Projects can define thresholds for vulnerability counts by severity, and scans are evaluated against these gates to produce pass/fail results.

## Endpoints

### Get Project Quality Gate

```
GET /api/v1/quality-gates/projects/{project_id}
```

Returns the quality gate configuration for a project.

**Response (404 if project not found):**
```json
{
  "detail": "Project not found or unauthorized"
}
```

### Update Quality Gate

```
PUT /api/v1/quality-gates/projects/{project_id}
```

**Request Body:**
```json
{
  "name": "Production Gate",
  "critical_threshold": 0,
  "high_threshold": 0,
  "medium_threshold": 5,
  "low_threshold": -1,
  "is_active": true
}
```

### Patch Quality Gate

```
PATCH /api/v1/quality-gates/projects/{project_id}
```

Partial update of quality gate settings.

### Get Build Status Badge

```
GET /api/v1/quality-gates/projects/{project_id}/badge.svg
```

Returns an SVG badge showing pass/fail status. Can be embedded in README files.

### Get Build Status

```
GET /api/v1/quality-gates/projects/{project_id}/build-status
```

**Response (200):**
```json
{
  "project_id": "uuid",
  "status": "pass",
  "quality_gate_name": "Production Gate",
  "last_scan_id": "uuid",
  "critical_count": 0,
  "high_count": 0,
  "medium_count": 2,
  "low_count": 15
}
```

### Evaluate Quality Gate

```
POST /api/v1/quality-gates/projects/{project_id}/evaluate
```

Triggers evaluation of the latest scan against the quality gate.

### Get Evaluation History

```
GET /api/v1/quality-gates/projects/{project_id}/history
```

Returns history of quality gate evaluations.

## CI/CD Integration

```bash
# Check build status in CI pipeline
STATUS=$(curl -s -H "Authorization: Bearer $API_KEY" \
  https://app.blocksecops.local/api/v1/quality-gates/projects/$PROJECT_ID/build-status \
  | jq -r '.status')

if [ "$STATUS" != "pass" ]; then
  echo "Quality gate failed!"
  exit 1
fi
```

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /projects/{id} | 404 | No projects exist in test env |
