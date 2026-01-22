# Feature Test: Economic Security Analysis

**Feature**: Economic Security Analysis Panel (Phase 5.5a)
**Version**: 0.10.0 (API), 0.28.0 (Dashboard)
**Date**: January 12, 2026
**Status**: Implemented

---

## Overview

The Economic Security Analysis feature aggregates and displays economic security findings from SolidityDefend scans. It detects and categorizes flash loan attacks, MEV exploitation, oracle manipulation, and DeFi protocol risks. AI-powered explanations are available based on tier quotas.

## Test Cases

### TC-39.1: Economic Security Panel Display

**Objective**: Verify the Economic Security Analysis panel displays in scan details

**Prerequisites**:
- User authenticated
- At least one contract with completed scan

**Steps**:
1. Navigate to Dashboard
2. Select a contract with a completed scan
3. Click on a scan result to view details
4. Locate the "Economic Security Analysis" panel

**Expected Results**:
- [ ] Economic Security Analysis panel visible in scan details
- [ ] Panel shows total economic findings count
- [ ] Panel shows economic risk score (0-100)
- [ ] Panel shows risk level badge (Critical/High/Medium/Low/None)
- [ ] Severity breakdown visible (critical, high, medium, low counts)

---

### TC-39.2: No Economic Vulnerabilities State

**Objective**: Verify clean state when no economic vulnerabilities detected

**Prerequisites**:
- Contract with scan containing no economic security findings

**Steps**:
1. Open scan details for a contract without economic issues
2. View Economic Security Analysis panel

**Expected Results**:
- [ ] Message displays: "No economic security vulnerabilities detected"
- [ ] Risk score shows 0
- [ ] Risk level shows "NONE"
- [ ] Panel does not show empty category lists

---

### TC-39.3: Flash Loan Findings Display

**Objective**: Verify flash loan attack findings are properly categorized

**Prerequisites**:
- Contract with scan containing flash loan vulnerabilities
- Pattern IDs starting with `BVD-SOLIDITY-FLASH-*` or title containing flash loan keywords

**Steps**:
1. Open scan with flash loan findings
2. Expand Flash Loan section in Economic Security panel

**Expected Results**:
- [ ] Flash Loan findings grouped separately
- [ ] Each finding shows:
  - Title
  - Severity badge
  - Contract name
  - Line number (if available)
  - Confidence score
- [ ] Click on finding navigates to code location

---

### TC-39.4: MEV Exploitation Findings Display

**Objective**: Verify MEV/oracle findings are properly categorized

**Prerequisites**:
- Contract with MEV-related vulnerabilities
- Pattern IDs containing `MEV` or titles with sandwich, frontrun, backrun keywords

**Steps**:
1. Open scan with MEV/oracle findings
2. Expand Oracle/MEV section in Economic Security panel

**Expected Results**:
- [ ] MEV findings grouped under "Oracle/MEV" section
- [ ] Sandwich attack patterns identified
- [ ] Frontrunning risks highlighted
- [ ] Each finding shows severity and confidence

---

### TC-39.5: DeFi Protocol Findings Display

**Objective**: Verify DeFi protocol risk findings are properly categorized

**Prerequisites**:
- Contract with DeFi-related vulnerabilities
- Pattern IDs with `DEFI` or titles containing oracle, liquidity, AMM keywords

**Steps**:
1. Open scan with DeFi protocol findings
2. Expand DeFi Risks section in Economic Security panel

**Expected Results**:
- [ ] DeFi findings grouped under "DeFi Risks" section
- [ ] Oracle manipulation risks identified
- [ ] Liquidity pool risks highlighted
- [ ] AMM-specific vulnerabilities shown

---

### TC-39.6: Economic Analysis API Response

**Objective**: Verify /scans/{id}/economic-analysis returns correct data

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
SCAN_ID="your-scan-uuid"
curl -s "http://localhost:8000/api/v1/scans/$SCAN_ID/economic-analysis" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] Response contains `scan_id`, `total_economic_findings`, `economic_risk_score`
- [ ] `flash_loan_findings` is array of EconomicFinding objects
- [ ] `oracle_mev_findings` is array of EconomicFinding objects
- [ ] `defi_findings` is array of EconomicFinding objects
- [ ] `risk_level` is one of: critical, high, medium, low, none
- [ ] `highest_severity` reflects most severe finding

---

### TC-39.7: AI Explanation - Tier Eligibility

**Objective**: Verify AI explanation respects tier-based quotas

**Tier Quotas (4-Tier Model)**:
| Tier | Price | Monthly AI Explanations |
|------|-------|------------------------|
| Developer | $0 | 0 (not available) |
| Team | $299/mo | 10 |
| Growth | $699/mo | 100 |
| Enterprise | $1,999+/mo | Unlimited (-1) |

**Steps for Developer Tier**:
1. Login as Developer tier user
2. Open scan with economic findings
3. Click "AI Explain" button

**Expected Results (Developer Tier)**:
- [ ] AI Explain button disabled or shows upgrade prompt
- [ ] Message: "AI explanations not available on Developer tier"
- [ ] Upgrade CTA visible

---

### TC-39.8: AI Explanation - Request and Response

**Objective**: Verify AI explanation endpoint works for eligible tiers

**Prerequisites**:
- User on Team tier or higher
- AI explanation quota not exhausted

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
SCAN_ID="your-scan-uuid"
curl -s "http://localhost:8000/api/v1/scans/$SCAN_ID/economic-analysis/explain" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] Response contains `explanation` (markdown text)
- [ ] Response contains `generated_at` timestamp
- [ ] Response contains `model` (e.g., "claude-3-haiku")
- [ ] Response contains `quota_remaining` (decremented count)
- [ ] Explanation covers all detected economic risks
- [ ] Explanation includes recommendations

---

### TC-39.9: AI Explanation - Quota Exhausted

**Objective**: Verify proper handling when AI quota is exceeded

**Prerequisites**:
- User on paid tier with quota exhausted

**Steps**:
1. Exhaust AI explanation quota
2. Attempt another AI explanation request

**Expected Results**:
- [ ] HTTP 402 Payment Required status
- [ ] Error message: "AI explanation quota exceeded"
- [ ] Response includes `quota_limit` and `quota_used`
- [ ] Response includes `upgrade_url`
- [ ] UI shows upgrade prompt

---

### TC-39.10: Contract Economic Findings API

**Objective**: Verify /contracts/{id}/economic-findings endpoint

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
CONTRACT_ID="your-contract-uuid"
curl -s "http://localhost:8000/api/v1/contracts/$CONTRACT_ID/economic-findings" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] Response contains `contract_id`
- [ ] `findings` is array of all economic findings for contract
- [ ] `total` reflects actual count
- [ ] Findings include all scans for the contract

---

### TC-39.11: Project Economic Risk API

**Objective**: Verify /projects/{id}/economic-risk aggregation endpoint

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
curl -s "http://localhost:8000/api/v1/projects/$PROJECT_ID/economic-risk" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] Response contains `project_id`
- [ ] `total_economic_findings` aggregates all scans
- [ ] `aggregate_risk_score` is capped at 100
- [ ] `scans_analyzed` shows count of completed scans
- [ ] `highest_severity` reflects worst finding across all scans

---

### TC-39.12: Economic Risk Score Calculation

**Objective**: Verify risk score calculation accuracy

**Severity Weights**:
| Severity | Base Weight | Pattern Multipliers |
|----------|-------------|---------------------|
| Critical | 40 | FLASH: 1.3x, DEFI: 1.2x, MEV: 1.0x |
| High | 25 | FLASH: 1.3x, DEFI: 1.2x, MEV: 1.0x |
| Medium | 10 | FLASH: 1.3x, DEFI: 1.2x, MEV: 1.0x |
| Low | 3 | FLASH: 1.3x, DEFI: 1.2x, MEV: 1.0x |
| Info | 0 | - |

**Test Data**:
Create a scan with:
- 1 Critical Flash Loan (40 × 1.3 = 52)
- 2 High DeFi (2 × 25 × 1.2 = 60)
- Expected: min(100, 52 + 60) = 100 (capped)

**Steps**:
1. Create scan with known economic vulnerabilities
2. Check economic analysis endpoint
3. Verify calculation

**Expected Results**:
- [ ] Score calculation matches formula
- [ ] Score capped at 100
- [ ] Confidence factor (1 - false_positive_score) applied

---

### TC-39.13: Risk Level Thresholds

**Objective**: Verify risk level assignment based on score

**Thresholds**:
| Risk Level | Condition |
|------------|-----------|
| CRITICAL | Any critical finding OR score >= 50 |
| HIGH | Score 25-49 |
| MEDIUM | Score 10-24 |
| LOW | Score 1-9 |
| NONE | Score = 0 |

**Steps**:
1. Test with various score ranges
2. Verify risk level assignment

**Expected Results**:
- [ ] CRITICAL assigned for any critical severity finding
- [ ] CRITICAL assigned for score >= 50
- [ ] Thresholds correctly applied
- [ ] Edge cases handled (exactly 25, 50, etc.)

---

### TC-39.14: Pattern Detection by Title Keywords

**Objective**: Verify fallback detection via title keywords when pattern_id missing

**Flash Loan Keywords**: flash, flashloan, flash-loan, flashmint
**MEV Keywords**: mev, sandwich, frontrun, backrun, priority-gas, toxic-flow
**DeFi Keywords**: defi, liquidity, oracle, amm, yield, pool, price-

**Steps**:
1. Create vulnerability with title "Sandwich Attack Vulnerability" (no pattern_id)
2. Check economic analysis categorization

**Expected Results**:
- [ ] Finding categorized as MEV based on "sandwich" keyword
- [ ] Keyword matching is case-insensitive
- [ ] All keyword lists properly checked

---

### TC-39.15: Authorization and Access Control

**Objective**: Verify users can only access their own data

**Steps**:
1. Get scan ID from User A
2. Attempt to access with User B's token

**Expected Results**:
- [ ] HTTP 403 Forbidden returned
- [ ] Error message: "Not authorized to access this scan"
- [ ] No data leaked

---

### TC-39.16: Dashboard Integration

**Objective**: Verify Economic Security panel integrates with dashboard stats

**Steps**:
1. Navigate to main dashboard
2. Check if economic risk summary is visible (if implemented in stats)

**Expected Results**:
- [ ] Economic findings count visible in dashboard overview (if implemented)
- [ ] Quick access to high-risk economic findings
- [ ] Proper loading states while data fetches

---

## API Reference

### GET /api/v1/scans/{scan_id}/economic-analysis
Returns economic security summary for a scan.

### GET /api/v1/scans/{scan_id}/economic-analysis/explain
Returns AI-generated explanation of economic risks (tier-gated).

### GET /api/v1/contracts/{contract_id}/economic-findings
Returns economic findings for a specific contract.

### GET /api/v1/projects/{project_id}/economic-risk
Returns aggregated economic risk across all project scans.

---

## Economic Pattern Categories

| Category | Pattern Prefix | Keywords |
|----------|---------------|----------|
| Flash Loan | BVD-SOLIDITY-FLASH-* | flash, flashloan, flashmint |
| MEV | BVD-SOLIDITY-MEV-* | mev, sandwich, frontrun, backrun |
| DeFi | BVD-SOLIDITY-DEFI-* | oracle, liquidity, amm, pool |

---

## Severity Weight Reference

| Severity | Weight | Flash Multiplier | DeFi Multiplier | MEV Multiplier |
|----------|--------|------------------|-----------------|----------------|
| Critical | 40 | 1.3x | 1.2x | 1.0x |
| High | 25 | 1.3x | 1.2x | 1.0x |
| Medium | 10 | 1.3x | 1.2x | 1.0x |
| Low | 3 | 1.3x | 1.2x | 1.0x |
| Info | 0 | - | - | - |

---

## AI Explanation Quota by Tier (4-Tier Model)

| Tier | Price | Monthly Quota | Reset |
|------|-------|--------------|-------|
| Developer | $0 | 0 | N/A |
| Team | $299/mo | 10 | Monthly |
| Growth | $699/mo | 100 | Monthly |
| Enterprise | $1,999+/mo | -1 (unlimited) | N/A |
