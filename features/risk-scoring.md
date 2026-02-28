# Risk Scoring System

## Overview

Apogee uses an **unbounded risk scoring system** to quantify security risk across smart contracts and projects. Higher scores indicate higher risk, with no artificial cap. This allows users to accurately understand their risk exposure regardless of how many vulnerabilities are present.

## Key Principles

1. **Unbounded Scoring**: Scores can grow indefinitely based on the number and severity of vulnerabilities
2. **Higher = Riskier**: A score of 250 represents more risk than a score of 50
3. **Per-Contract Averaging**: Risk levels are determined by the average risk per contract, making comparisons fair across different-sized projects
4. **Intuitive Thresholds**: Risk levels (CRITICAL, HIGH, MEDIUM, LOW) are based on fixed thresholds

## Severity Weights

Each vulnerability contributes to the total risk score based on its severity:

| Severity | Weight | Description |
|----------|--------|-------------|
| Critical | 25 | Severe vulnerabilities that could lead to immediate fund loss |
| High | 15 | Significant security issues requiring prompt attention |
| Medium | 5 | Moderate issues that should be addressed |
| Low | 1 | Minor issues or code quality improvements |
| Info | 0 | Informational findings, no security impact |

## Risk Calculation

### Total Risk Score

The total risk score is calculated by summing the weighted values of all vulnerabilities:

```
Total Risk = (Critical × 25) + (High × 15) + (Medium × 5) + (Low × 1) + (Info × 0)
```

**Example:**
- 3 Critical + 5 High + 10 Medium + 20 Low vulnerabilities
- Score = (3 × 25) + (5 × 15) + (10 × 5) + (20 × 1) = 75 + 75 + 50 + 20 = **220**

### Average Per Contract

To compare risk across projects of different sizes:

```
Average Per Contract = Total Risk / Number of Contracts
```

**Example:**
- Project A: 500 total risk across 10 contracts = 50 avg/contract
- Project B: 200 total risk across 2 contracts = 100 avg/contract
- Project B is riskier despite lower total (higher concentration)

## Risk Levels

Risk levels are determined by the **average risk per contract**:

| Level | Threshold | Description |
|-------|-----------|-------------|
| **CRITICAL** | ≥ 50 points/contract | Severe risk - immediate attention required |
| **HIGH** | 25-49 points/contract | Significant risk - should be addressed soon |
| **MEDIUM** | 10-24 points/contract | Moderate risk - review recommended |
| **LOW** | < 10 points/contract | Acceptable risk level |

### Threshold Examples

| Scenario | Total Score | Contracts | Average | Risk Level |
|----------|-------------|-----------|---------|------------|
| 2 critical vulns, 1 contract | 50 | 1 | 50.0 | CRITICAL |
| 10 critical vulns, 5 contracts | 250 | 5 | 50.0 | CRITICAL |
| 1 critical + 2 high, 2 contracts | 55 | 2 | 27.5 | HIGH |
| 5 medium, 1 contract | 25 | 1 | 25.0 | HIGH |
| 2 medium + 5 low, 1 contract | 15 | 1 | 15.0 | MEDIUM |
| 3 low vulnerabilities, 1 contract | 3 | 1 | 3.0 | LOW |

## Score Adjustments

The ML risk scorer may apply adjustments based on additional context:

### Positive Adjustments (Increase Risk)

| Condition | Adjustment | Reason |
|-----------|------------|--------|
| Known exploit patterns detected | +10 | Vulnerabilities matching known exploit patterns are higher priority |
| High tool consensus (>80%) | +5 | Multiple scanners agreeing increases confidence in the finding |

### Negative Adjustments (Decrease Risk)

| Condition | Adjustment | Reason |
|-----------|------------|--------|
| All findings low confidence | -10 | Low confidence findings may be false positives |
| All findings in test files | -15 | Test file issues are less critical |

### False Positive Impact

Each vulnerability's weight is reduced by its false positive probability:

```
Effective Weight = Base Weight × (1 - False Positive Score)
```

**Example:**
- Critical vulnerability with 0.4 false positive probability
- Effective weight = 25 × (1 - 0.4) = 15

## API Endpoints

### Dashboard Statistics

```http
GET /api/v1/statistics/dashboard
```

Returns overall risk metrics including:
- `risk_metrics.overall_risk`: Total unbounded risk score
- `risk_metrics.average_per_contract`: Average risk per contract
- `risk_metrics.risk_level`: CRITICAL/HIGH/MEDIUM/LOW
- `risk_metrics.breakdown`: Vulnerability counts by severity
- `risk_metrics.contracts_scanned`: Number of contracts analyzed

### Detailed Risk Breakdown

```http
GET /api/v1/statistics/risk
```

Returns comprehensive risk analysis:
- Overall risk metrics across all user contracts
- Per-project risk breakdown
- Contract IDs associated with each project

## Display Guidelines

### Formatting Large Numbers

For display purposes, use abbreviations for large scores:
- Scores ≥ 10,000: Display as "10.5k"
- Scores ≥ 1,000: Use locale formatting "1,234"
- Scores < 1,000: Display as-is

### Color Coding

| Risk Level | Primary Color | Background | Use Case |
|------------|---------------|------------|----------|
| CRITICAL | Red (#dc2626) | Red-100 | Badges, icons, borders |
| HIGH | Orange (#ea580c) | Orange-100 | Badges, icons, borders |
| MEDIUM | Yellow (#ca8a04) | Yellow-100 | Badges, icons, borders |
| LOW | Green (#16a34a) | Green-100 | Badges, icons, borders |

## Backward Compatibility

### Deprecated Fields

The following fields are deprecated but maintained for backward compatibility:

| Field | Replacement | Notes |
|-------|-------------|-------|
| `average_risk_score` | `risk_metrics.average_per_contract` | Was capped at 100 |
| `health_score` | `risk_score` with `risk_level` | Inverse scale (100 = healthy) |

### Migration Path

1. Update frontend to use `risk_metrics` when available
2. Fall back to legacy fields if `risk_metrics` is null
3. Plan to remove legacy fields in future major version

## Implementation Files

| Layer | File | Purpose |
|-------|------|---------|
| Backend Schema | `src/presentation/schemas/statistics.py` | RiskMetrics, RiskLevel types |
| Backend Endpoint | `src/presentation/api/v1/endpoints/statistics.py` | /dashboard and /risk endpoints |
| Domain Entity | `src/domain/entities/project.py` | ProjectWithStats with risk methods |
| ML Scorer | `src/ml/risk_scorer.py` | Risk calculation with adjustments |
| Frontend Types | `src/lib/api/statistics.ts` | TypeScript interfaces |
| Frontend Utils | `src/lib/utils/risk.ts` | Display formatting helpers |
| Dashboard UI | `src/pages/Dashboard.tsx` | Risk score card display |
| Project Card | `src/components/projects/ProjectCard.tsx` | Per-project risk display |

## Best Practices

### For Users

1. **Focus on Risk Level**: Use CRITICAL/HIGH/MEDIUM/LOW as the primary indicator
2. **Compare Averages**: When comparing projects, use average per contract, not total
3. **Prioritize by Severity**: Address critical and high vulnerabilities first
4. **Monitor Trends**: Track risk score changes over time

### For Developers

1. **Always use risk_metrics**: Prefer the new fields over deprecated ones
2. **Handle null gracefully**: Check for null/undefined risk_metrics
3. **Format consistently**: Use the provided formatting utilities
4. **Test boundaries**: Verify behavior at threshold boundaries (10, 25, 50)
