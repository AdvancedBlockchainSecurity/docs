# AI Economic Analysis Pipeline

AI-powered economic security analysis for DeFi smart contracts. Filters vulnerability findings to economic categories (flash loans, MEV, DeFi risks) and generates plain-English explanations with attack scenarios and remediation steps.

## Overview

```
Dashboard (Scan Results)     API Service (economic_analysis.py)                 External
────────────────────────     ─────────────────────────────────                 ────────
GET /summary           →     1. Authenticate (JWT)                              PostgreSQL
                             2. Validate tier (starter+)
                             3. Filter economic findings (BVD codes)
                             4. Calculate risk score (0-100)
                      ←      Return EconomicSummaryResponse (200)

POST /explain          →     5. Check AI explanation quota
                             6. Load economic findings
                             7. Call Anthropic Claude API
                             8. Decrement quota
                      ←      Return EconomicExplanationResponse (200)           Anthropic API
```

## Trigger

- **Dashboard**: User navigates to Economic Analysis tab on scan results
- **Summary**: Automatic load of economic risk overview
- **Explain**: User clicks "AI Explain" to generate detailed analysis

## Pipeline Steps

### Summary (Non-AI)

| # | Step | Component | Description |
|---|------|-----------|-------------|
| 1 | Authentication | `get_current_user` | JWT required |
| 2 | Tier gate | `require_tier("starter")` | Developer tier blocked |
| 3 | Filter findings | BVD pattern codes | Match `BVD-SOLIDITY-FLASH-*`, `BVD-SOLIDITY-MEV-*`, `BVD-SOLIDITY-DEFI-*` |
| 4 | Risk scoring | `EconomicSummaryService` | Aggregate risk score 0-100 based on severity distribution |

### AI Explanation

| # | Step | Component | Description |
|---|------|-----------|-------------|
| 5 | Quota check | `UserQuotaModel` | Check `monthly_ai_explanations_used` vs `monthly_ai_explanations_limit` |
| 6 | Load findings | Database query | Fetch economic findings for scan |
| 7 | Anthropic API call | `EconomicAIExplainer.explain_findings()` | Model: Claude Haiku, cost ~$0.012/request |
| 8 | Quota decrement | `UserQuotaModel` | Increment `monthly_ai_explanations_used` |

## Economic Finding Categories

| Category | BVD Pattern Prefix | Examples |
|----------|--------------------|----------|
| Flash Loan Attacks | `BVD-SOLIDITY-FLASH-*` | Unchecked flash loan callbacks, price manipulation |
| MEV Exploitation | `BVD-SOLIDITY-MEV-*` | Sandwich attacks, frontrunning, backrunning |
| DeFi Protocol Risks | `BVD-SOLIDITY-DEFI-*` | Oracle manipulation, liquidity pool attacks, reentrancy in DeFi |

## Quota Enforcement

| Tier | AI Explanations/Month | Cost to Platform |
|------|------------------------|------------------|
| Developer | 0 (blocked) | $0 |
| Team | 10 | ~$0.12 |
| Growth | 100 | ~$1.20 |
| Enterprise | Unlimited | Usage-based |

Returns **402 Payment Required** when quota is exhausted (not 429).

## Configuration

| Setting | Default | Source |
|---------|---------|--------|
| AI model | Claude Haiku 3.5 | `EconomicAIExplainer` |
| Cost per request | ~$0.012 | Anthropic pricing |
| `ai_features_enabled` | `true` | `config.py` |

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/economic-analysis/scans/{scan_id}/summary` | JWT + `require_tier("starter")` | Economic risk summary |
| GET | `/economic-analysis/projects/{project_id}/risk` | JWT + `require_tier("starter")` | Project-level economic risk |
| GET | `/economic-analysis/contracts/{contract_id}/findings` | JWT + `require_tier("starter")` | Economic findings for contract |
| POST | `/economic-analysis/scans/{scan_id}/explain` | JWT + `require_tier("starter")` + quota | AI explanation (quota-gated) |
| GET | `/economic-analysis/quota` | JWT | Current quota status |

## Files

| File | Role |
|------|------|
| `src/presentation/api/v1/endpoints/economic_analysis.py` | Endpoints, tier gating, quota checks |
| `src/application/services/economic_summary_service.py` | Risk scoring, finding aggregation |
| `src/application/services/economic_ai_explainer.py` | Anthropic API integration for explanations |

## Error Handling

| Error | HTTP | Response |
|-------|------|----------|
| No economic findings | 400 | No findings to explain |
| Tier insufficient | 403 | Tier gate rejection |
| Quota exhausted | 402 | Payment required with quota details |
| Scan not found | 404 | Standard not found |
| Anthropic API failure | 500 | Sanitized error |

### Slowapi Requirement

All endpoints in `economic_analysis.py` use `@limiter.limit()` for rate limiting. This requires `response: Response` in the function signature. Missing this parameter causes 500 errors. Fixed in v0.29.9 (February 23, 2026).

### Dashboard Error Handling

The `EconomicSecurityPanel.tsx` component uses `getErrorStatus()` from `client.ts` to detect 403 (tier gate) and 402 (quota exhausted) errors. This replaces the previous string-matching approach for security. Fixed in dashboard v0.46.2.
