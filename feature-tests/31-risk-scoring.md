# Feature Test: Risk Scoring System

**Feature**: Unbounded Risk Scoring
**Version**: 0.7.0 (API), 0.20.0 (Dashboard)
**Date**: December 30, 2025
**Status**: Implemented

---

## Overview

The risk scoring system calculates security risk using weighted vulnerability counts. Higher scores indicate higher risk, with no arbitrary cap.

## Test Cases

### TC-31.1: Dashboard Security Status Display

**Objective**: Verify dashboard displays color-coded security status badge

**Prerequisites**:
- User authenticated
- At least one contract with vulnerabilities

**Steps**:
1. Navigate to Dashboard
2. Locate the "Security Status" card (4th card in stats grid)

**Expected Results**:
- [ ] Color-coded badge displays risk level text (e.g., "Critical Risk")
- [ ] Badge color matches risk level:
  - CRITICAL: Red background with white text, pulsing indicator
  - HIGH: Orange background with white text
  - MEDIUM: Yellow background with dark text
  - LOW: Green background with white text
- [ ] Circular icon on right matches risk level:
  - CRITICAL/HIGH: Warning triangle
  - MEDIUM: Info circle
  - LOW: Checkmark circle
- [ ] Subtitle shows "Based on X contracts analyzed"

---

### TC-31.2: Risk Metrics API Response

**Objective**: Verify /statistics/dashboard returns correct risk_metrics

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s "http://localhost:8000/api/v1/statistics/dashboard" \
  -H "Authorization: Bearer $TOKEN" | jq '.risk_metrics'
```

**Expected Results**:
- [ ] `overall_risk` is sum of weighted vulnerabilities
- [ ] `average_per_contract` = overall_risk / contracts_scanned
- [ ] `risk_level` matches thresholds:
  - >= 50 avg → CRITICAL
  - >= 25 avg → HIGH
  - >= 10 avg → MEDIUM
  - < 10 avg → LOW
- [ ] `breakdown` shows correct counts per severity
- [ ] `weights_applied` shows {critical: 25, high: 15, medium: 5, low: 1, info: 0}

---

### TC-31.3: Detailed Risk Endpoint

**Objective**: Verify /statistics/risk returns per-project breakdown

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s "http://localhost:8000/api/v1/statistics/risk" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] `overall` contains RiskMetrics for all user contracts
- [ ] `by_project` contains array of ProjectRiskMetrics
- [ ] Each project has: project_id, project_name, contract_ids
- [ ] Projects sorted by overall_risk descending
- [ ] `computed_at` is valid ISO timestamp

---

### TC-31.4: Project Card Risk Display

**Objective**: Verify ProjectCard shows risk level and score

**Prerequisites**:
- At least one project with contracts

**Steps**:
1. Navigate to Projects page
2. View any project card

**Expected Results**:
- [ ] Risk level badge visible (CRITICAL/HIGH/MEDIUM/LOW)
- [ ] Risk score displayed below badge
- [ ] Badge color matches risk level

---

### TC-31.5: Risk Calculation Accuracy

**Objective**: Verify risk score calculation is correct

**Test Data**:
Create a contract with known vulnerabilities:
- 2 Critical (2 × 25 = 50)
- 3 High (3 × 15 = 45)
- 5 Medium (5 × 5 = 25)
- 10 Low (10 × 1 = 10)
- Expected Total: 130

**Steps**:
1. Scan contract with known vulnerabilities
2. Check dashboard risk_metrics
3. Calculate manually and compare

**Expected Results**:
- [ ] overall_risk = 130 (for single contract)
- [ ] average_per_contract = 130.0
- [ ] risk_level = "CRITICAL" (130 >= 50)

---

### TC-31.6: Color Badge Visual Consistency

**Objective**: Verify color badges display consistently across risk levels

**Test Scenarios**:
| Risk Level | Badge Text | Background | Text Color |
|------------|------------|------------|------------|
| CRITICAL | "Critical Risk" | Red (bg-red-500) | White |
| HIGH | "High Risk" | Orange (bg-orange-500) | White |
| MEDIUM | "Medium Risk" | Yellow (bg-yellow-400) | Dark gray |
| LOW | "Low Risk" | Green (bg-green-500) | White |

**Steps**:
1. View dashboard with contracts at each risk level
2. Verify badge appearance

**Expected Results**:
- [ ] All badges use consistent padding and font weight
- [ ] Colors are distinct and accessible
- [ ] CRITICAL badge has pulsing indicator for attention

---

### TC-31.7: Zero Contracts Edge Case

**Objective**: Verify handling when no contracts scanned

**Steps**:
1. Create new user with no contracts
2. Check dashboard

**Expected Results**:
- [ ] Risk score shows 0
- [ ] average_per_contract shows 0
- [ ] risk_level shows "LOW"
- [ ] No division by zero errors

---

### TC-31.8: Backward Compatibility

**Objective**: Verify deprecated fields still work

**Steps**:
```bash
curl -s "http://localhost:8000/api/v1/statistics/dashboard" \
  -H "Authorization: Bearer $TOKEN" | jq '.average_risk_score'
```

**Expected Results**:
- [ ] `average_risk_score` field present (deprecated)
- [ ] Value capped at 100.0 for backward compatibility

---

## API Reference

### GET /api/v1/statistics/dashboard

Returns dashboard statistics including risk_metrics.

### GET /api/v1/statistics/risk

Returns detailed risk breakdown with per-project metrics.

---

## Severity Weights

| Severity | Weight |
|----------|--------|
| Critical | 25 |
| High | 15 |
| Medium | 5 |
| Low | 1 |
| Info | 0 |

## Risk Level Thresholds

| Level | Per-Contract Average |
|-------|---------------------|
| CRITICAL | >= 50 |
| HIGH | 25-49 |
| MEDIUM | 10-24 |
| LOW | < 10 |
