# Analytics Endpoints

Base URL: `/api/v1/analytics`

These endpoints provide security analytics, vulnerability trends, tool effectiveness metrics, and project comparisons. All endpoints require authentication.

## Endpoints

| Method | Path | Auth Required | Description |
|--------|------|---------------|-------------|
| GET | `/api/v1/analytics/summary` | Yes | Composite analytics summary |
| GET | `/api/v1/analytics/trends` | Yes | Vulnerability trends over time |
| GET | `/api/v1/analytics/tools` | Yes | Tool effectiveness metrics |
| GET | `/api/v1/analytics/projects` | Yes | Project comparison data |
| GET | `/api/v1/analytics/scanner-effectiveness` | Yes | Scanner overlap analysis with recommendations |
| POST | `/api/v1/analytics/scanner-comparison` | Yes | Compare specific scanners |

---

## GET `/api/v1/analytics/summary`

Returns a composite analytics summary combining tool effectiveness, vulnerability trends, and project comparison data.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/analytics/summary \
  -H "Authorization: Bearer <token>"
```

### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `range` | string | No | `30d` | Time range (`7d`, `30d`, `90d`) |

### Response `200 OK`

```json
{
  "tool_effectiveness": {
    "tools": [
      {
        "tool_id": "slither",
        "total_findings": 42,
        "confirmed_findings": 38,
        "false_positive_rate": 0.095
      }
    ]
  },
  "vulnerability_trends": {
    "data": [
      {
        "date": "2026-02-01",
        "critical": 0,
        "high": 2,
        "medium": 5,
        "low": 12
      }
    ],
    "range": "30d"
  },
  "project_comparison": {
    "projects": [
      {
        "project_id": "proj_abc123",
        "name": "DeFi Protocol",
        "total_findings": 19,
        "critical": 0,
        "high": 1,
        "risk_score": 3.2
      }
    ]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `tool_effectiveness` | object | Tool-level finding stats and false positive rates |
| `vulnerability_trends` | object | Time-series vulnerability data by severity |
| `project_comparison` | object | Cross-project comparison with risk scores |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/analytics/trends`

Returns vulnerability trend data over a specified time range.

### Example Request

```bash
curl -X GET "https://api.blocksecops.example.com/api/v1/analytics/trends?range=30d" \
  -H "Authorization: Bearer <token>"
```

### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `range` | string | No | `30d` | Time range (`7d`, `30d`, `90d`) |

### Response `200 OK`

```json
{
  "data": [
    {
      "date": "2026-02-01",
      "critical": 0,
      "high": 2,
      "medium": 5,
      "low": 12
    },
    {
      "date": "2026-02-02",
      "critical": 1,
      "high": 3,
      "medium": 4,
      "low": 10
    }
  ],
  "range": "30d",
  "new_vulns": 7,
  "avg_per_day": 2.3
}
```

| Field | Type | Description |
|-------|------|-------------|
| `data` | array | Daily vulnerability counts by severity |
| `data[].date` | string | Date in ISO 8601 format |
| `data[].critical` | integer | Critical severity count |
| `data[].high` | integer | High severity count |
| `data[].medium` | integer | Medium severity count |
| `data[].low` | integer | Low severity count |
| `range` | string | Requested time range |
| `new_vulns` | integer | New vulnerabilities discovered in the range |
| `avg_per_day` | number | Average new vulnerabilities per day |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/analytics/tools`

Returns effectiveness metrics for each security tool/scanner.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/analytics/tools \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "tools": [
    {
      "tool_id": "slither",
      "name": "Slither",
      "total_findings": 42,
      "confirmed_findings": 38,
      "false_positive_rate": 0.095,
      "avg_scan_duration_seconds": 28,
      "unique_finding_rate": 0.45
    },
    {
      "tool_id": "aderyn",
      "name": "Aderyn",
      "total_findings": 35,
      "confirmed_findings": 31,
      "false_positive_rate": 0.114,
      "avg_scan_duration_seconds": 15,
      "unique_finding_rate": 0.22
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `tools` | array | List of tool effectiveness records |
| `tools[].tool_id` | string | Scanner identifier |
| `tools[].name` | string | Scanner display name |
| `tools[].total_findings` | integer | Total findings reported |
| `tools[].confirmed_findings` | integer | Findings confirmed as true positives |
| `tools[].false_positive_rate` | number | Ratio of false positives (0.0 to 1.0) |
| `tools[].avg_scan_duration_seconds` | integer | Average scan duration in seconds |
| `tools[].unique_finding_rate` | number | Rate of findings unique to this tool |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/analytics/projects`

Returns comparison data across all projects.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/analytics/projects \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "projects": [
    {
      "project_id": "proj_abc123",
      "name": "DeFi Protocol",
      "total_findings": 19,
      "critical": 0,
      "high": 1,
      "medium": 7,
      "low": 11,
      "risk_score": 3.2,
      "last_scan": "2026-02-13T15:30:00.000Z"
    }
  ],
  "total_projects": 1
}
```

| Field | Type | Description |
|-------|------|-------------|
| `projects` | array | List of project comparison records |
| `projects[].project_id` | string | Project identifier |
| `projects[].name` | string | Project name |
| `projects[].total_findings` | integer | Total findings across all scans |
| `projects[].critical` | integer | Critical severity findings |
| `projects[].high` | integer | High severity findings |
| `projects[].medium` | integer | Medium severity findings |
| `projects[].low` | integer | Low severity findings |
| `projects[].risk_score` | number | Computed risk score |
| `projects[].last_scan` | string | Timestamp of the most recent scan |
| `total_projects` | integer | Total number of projects |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/analytics/scanner-effectiveness`

Returns scanner overlap analysis showing which scanners find unique vulnerabilities versus duplicates, along with recommendations for optimal scanner combinations.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/analytics/scanner-effectiveness \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "overlap_matrix": {
    "slither_aderyn": 0.62,
    "slither_mythril": 0.18,
    "aderyn_semgrep": 0.34
  },
  "unique_findings_by_scanner": {
    "slither": 14,
    "mythril": 8,
    "echidna": 6,
    "halmos": 4
  },
  "recommendations": [
    {
      "combination": ["slither", "mythril", "echidna"],
      "estimated_coverage": 0.89,
      "estimated_duration_seconds": 320,
      "rationale": "Combines static analysis, symbolic execution, and fuzzing for maximum coverage with minimal overlap"
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `overlap_matrix` | object | Pairwise overlap ratios between scanners |
| `unique_findings_by_scanner` | object | Count of findings unique to each scanner |
| `recommendations` | array | Suggested scanner combinations |
| `recommendations[].combination` | array | List of scanner IDs |
| `recommendations[].estimated_coverage` | number | Estimated vulnerability coverage (0.0 to 1.0) |
| `recommendations[].estimated_duration_seconds` | integer | Estimated total scan time |
| `recommendations[].rationale` | string | Explanation for the recommendation |

### Audit Status

- **Pass** — No issues identified.

---

## POST `/api/v1/analytics/scanner-comparison`

Compares specific scanners against each other based on historical scan data.

### Example Request

```bash
curl -X POST https://api.blocksecops.example.com/api/v1/analytics/scanner-comparison \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "scanner_ids": ["slither", "mythril", "aderyn"],
    "project_id": "proj_abc123",
    "range": "30d"
  }'
```

### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `scanner_ids` | array | Yes | List of scanner IDs to compare (min 2) |
| `project_id` | string | No | Limit comparison to a specific project |
| `range` | string | No | Time range for the comparison (`7d`, `30d`, `90d`) |

### Response `200 OK`

```json
{
  "comparison": {
    "scanners": [
      {
        "scanner_id": "slither",
        "total_findings": 42,
        "unique_findings": 14,
        "overlap_with_others": 28,
        "false_positive_rate": 0.095,
        "avg_duration_seconds": 28
      },
      {
        "scanner_id": "mythril",
        "total_findings": 22,
        "unique_findings": 8,
        "overlap_with_others": 14,
        "false_positive_rate": 0.136,
        "avg_duration_seconds": 180
      },
      {
        "scanner_id": "aderyn",
        "total_findings": 35,
        "unique_findings": 5,
        "overlap_with_others": 30,
        "false_positive_rate": 0.114,
        "avg_duration_seconds": 15
      }
    ],
    "combined_unique_findings": 27,
    "total_overlap_findings": 45,
    "range": "30d"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `comparison.scanners` | array | Per-scanner comparison data |
| `comparison.scanners[].scanner_id` | string | Scanner identifier |
| `comparison.scanners[].total_findings` | integer | Total findings from this scanner |
| `comparison.scanners[].unique_findings` | integer | Findings only this scanner detected |
| `comparison.scanners[].overlap_with_others` | integer | Findings also detected by other scanners |
| `comparison.scanners[].false_positive_rate` | number | False positive ratio |
| `comparison.scanners[].avg_duration_seconds` | integer | Average scan duration |
| `comparison.combined_unique_findings` | integer | Total unique findings across all compared scanners |
| `comparison.total_overlap_findings` | integer | Total overlapping findings |
| `comparison.range` | string | Time range used for the comparison |

### Audit Status

- **Pass** — No issues identified.
