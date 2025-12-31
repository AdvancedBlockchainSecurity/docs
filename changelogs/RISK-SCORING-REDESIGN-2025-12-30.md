# Risk Scoring System Redesign

**Date**: December 30, 2025
**Phase**: 3.2 - Risk Analytics Enhancement
**Status**: Complete

---

## Summary

Redesigned the risk scoring system to be intuitive (higher = riskier), unbounded (no arbitrary caps), and provide multiple views including overall risk, average per contract, and per-project breakdown.

### Key Changes

- **Removed 100 cap**: Scores now accurately reflect total risk
- **Higher = Riskier**: Intuitive scoring (previously inverted as "health score")
- **Multiple Views**: Overall risk, average per contract, per-project breakdown
- **Risk Levels**: CRITICAL/HIGH/MEDIUM/LOW based on per-contract thresholds

---

## Technical Details

### Severity Weights

| Severity | Weight |
|----------|--------|
| Critical | 25 |
| High | 15 |
| Medium | 5 |
| Low | 1 |
| Info | 0 |

### Risk Level Thresholds (Per-Contract Average)

| Level | Threshold |
|-------|-----------|
| CRITICAL | >= 50 points/contract |
| HIGH | 25-49 points/contract |
| MEDIUM | 10-24 points/contract |
| LOW | < 10 points/contract |

---

## Files Modified

### Backend (blocksecops-api-service)

| File | Change |
|------|--------|
| `src/presentation/schemas/statistics.py` | Added RiskLevel, SeverityBreakdown, RiskMetrics, ProjectRiskMetrics, DetailedRiskResponse schemas |
| `src/presentation/api/v1/endpoints/statistics.py` | Updated /dashboard endpoint, added /risk endpoint |
| `src/domain/entities/project.py` | Added risk_score, average_risk_per_contract, risk_level to ProjectWithStats |
| `src/infrastructure/repositories/sqlalchemy_project_repository.py` | Populate new risk fields |
| `src/ml/risk_scorer.py` | Removed 100 cap, updated thresholds |

### Frontend (blocksecops-dashboard)

| File | Change |
|------|--------|
| `src/lib/api/statistics.ts` | Added RiskMetrics TypeScript types |
| `src/lib/api/projects.ts` | Added risk fields to ProjectWithStats |
| `src/lib/utils/risk.ts` | NEW - Risk display utilities |
| `src/pages/Dashboard.tsx` | Updated risk card to show unbounded score with risk level badge |
| `src/components/projects/ProjectCard.tsx` | Replaced health_score with risk display |

### Documentation (blocksecops-docs)

| File | Change |
|------|--------|
| `features/risk-scoring.md` | NEW - Comprehensive risk scoring documentation |

---

## API Changes

### Updated Endpoint: GET /api/v1/statistics/dashboard

Response now includes `risk_metrics`:

```json
{
  "total_scans": 150,
  "total_vulnerabilities": 5302,
  "critical_vulnerabilities": 847,
  "high_vulnerabilities": 1203,
  "medium_vulnerabilities": 2156,
  "low_vulnerabilities": 1096,
  "contracts_scanned": 57,
  "risk_metrics": {
    "overall_risk": 25031.0,
    "average_per_contract": 439.14,
    "contracts_scanned": 57,
    "risk_level": "CRITICAL",
    "breakdown": {
      "critical": 847,
      "high": 1203,
      "medium": 2156,
      "low": 1096,
      "info": 0
    },
    "weights_applied": {
      "critical": 25,
      "high": 15,
      "medium": 5,
      "low": 1,
      "info": 0
    }
  },
  "average_risk_score": 100.0  // DEPRECATED
}
```

### New Endpoint: GET /api/v1/statistics/risk

Returns detailed risk breakdown with per-project metrics:

```json
{
  "overall": { /* RiskMetrics */ },
  "by_project": [
    {
      "project_id": "uuid",
      "project_name": "My Project",
      "contract_ids": ["uuid1", "uuid2"],
      "overall_risk": 500.0,
      "average_per_contract": 250.0,
      "risk_level": "CRITICAL",
      "breakdown": { /* SeverityBreakdown */ },
      "weights_applied": { /* weights */ }
    }
  ],
  "computed_at": "2025-12-30T12:00:00Z"
}
```

---

## Image Versions

| Service | Previous | New |
|---------|----------|-----|
| blocksecops-api-service | 0.6.0 | 0.7.0 |
| blocksecops-dashboard | 0.19.0 | 0.21.0 |

---

## UI Update (v0.21.0) - Color Badge Display

Following user feedback that numerical scores like "60.8k" were confusing, the dashboard now uses **color-coded status badges** instead of numbers:

| Risk Level | Badge Display | Color | Icon |
|------------|---------------|-------|------|
| CRITICAL | "Critical Risk" | Red (bg-red-500) | Warning triangle (pulsing) |
| HIGH | "High Risk" | Orange (bg-orange-500) | Warning triangle |
| MEDIUM | "Medium Risk" | Yellow (bg-yellow-400) | Info circle |
| LOW | "Low Risk" | Green (bg-green-500) | Checkmark circle |

**Benefits:**
- Instantly understandable without reading documentation
- Color communicates severity at a glance
- Consistent with industry security dashboards
- No confusing numbers to interpret

---

## Backward Compatibility

- `average_risk_score` field retained but deprecated (capped at 100)
- `health_score` field retained but deprecated (inverse scale)
- Frontend gracefully falls back if `risk_metrics` is null

---

## Testing

### API Testing

```bash
# Get token
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)

# Test dashboard endpoint
curl -s "http://localhost:8000/api/v1/statistics/dashboard" \
  -H "Authorization: Bearer $TOKEN" | jq '.risk_metrics'

# Test risk endpoint
curl -s "http://localhost:8000/api/v1/statistics/risk" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### UI Testing

1. Navigate to Dashboard
2. Verify Risk Score card shows:
   - Unbounded total score (not capped at 100)
   - Average per contract subtitle
   - Risk level badge (CRITICAL/HIGH/MEDIUM/LOW)
3. Navigate to Projects
4. Verify ProjectCard shows risk_level badge and risk_score

---

## Related Documentation

- [Risk Scoring System](/Users/pwner/Git/ABS/blocksecops-docs/features/risk-scoring.md)
- [Statistics API](/Users/pwner/Git/ABS/blocksecops-docs/api/endpoints-reference.md)
