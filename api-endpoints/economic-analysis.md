# Economic Analysis

**Base URL:** `/api/v1/economic-analysis`
**Auth:** Bearer JWT required
**Tier:** Growth+

## Overview

Economic analysis endpoints provide financial risk assessment for smart contract vulnerabilities, including potential loss estimates and risk scoring.

## Endpoints

### Get Quota

```
GET /api/v1/economic-analysis/quota
```

**Response (200):**
```json
{
  "monthly_limit": -1,
  "monthly_used": 0,
  "remaining": -1,
  "reset_at": "2026-03-01T00:00:00+00:00",
  "tier": "enterprise"
}
```

Enterprise tier has unlimited quota (`monthly_limit: -1`).

### Explain Scan Findings

```
POST /api/v1/economic-analysis/scans/{scan_id}/explain
```

Generates an AI-powered economic explanation of scan findings including potential financial impact.

### Get Scan Summary

```
GET /api/v1/economic-analysis/scans/{scan_id}/summary
```

Returns economic summary of a scan's findings.

### Get Contract Findings

```
GET /api/v1/economic-analysis/contracts/{contract_id}/findings
```

Returns economically-analyzed findings for a contract.

### Get Project Risk

```
GET /api/v1/economic-analysis/projects/{project_id}/risk
```

Returns overall risk assessment for a project.

## Example Usage

```bash
# Check quota
curl -H "Authorization: Bearer $TOKEN" \
  https://app.blocksecops.local/api/v1/economic-analysis/quota

# Get scan economic summary
curl -H "Authorization: Bearer $TOKEN" \
  https://app.blocksecops.local/api/v1/economic-analysis/scans/{scan_id}/summary
```

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /quota | 200 | Enterprise: unlimited |
