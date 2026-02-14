# AI Code Review Pipeline

AI-powered vulnerability review and explanation. Generates risk analysis, attack scenarios, and fix suggestions for individual findings. Uses Claude Haiku for cost-effective analysis.

## Overview

```
Dashboard (Finding Detail)   API Service (code_review.py → CodeReviewService)   External
──────────────────────────   ────────────────────────────────────────────────   ────────
POST /review/suggestions →   1. Authenticate (JWT)                              PostgreSQL
                             2. Validate tier (team+)
                             3. Check feature flags
                             4. Rate limit check
                             5. Load vulnerability + contract context
                             6. Call Anthropic Claude API
                             7. Validate and store suggestion
                      ←      Return ReviewSuggestionResponse (201)              Anthropic API
```

## Trigger

- **Dashboard**: User clicks "AI Review" on a vulnerability finding
- **Input**: `vulnerability_id` with optional flags `include_fix` and `include_attack_scenario`

## Pipeline Steps

| # | Step | Component | Description |
|---|------|-----------|-------------|
| 1 | Authentication | `get_current_user` | JWT required |
| 2 | Tier gate | `require_tier("team")` | Developer tier blocked |
| 3 | Feature flags | `ai_features_enabled` + `ai_code_review_enabled` | Returns 503 if disabled |
| 4 | Rate limiting | `@limiter.limit(get_rate_limit_string("ai", "codeReview"))` | Per-tier rate limits (BSO-SEC-AI-003) |
| 5 | Load context | Database query | Fetch vulnerability, contract source, scan metadata |
| 6 | Anthropic API call | `CodeReviewService.generate_suggestion()` | Model: `claude-3-haiku-20240307`, max tokens: 2048 |
| 7 | Store result | Database INSERT | Save suggestion with risk explanation, fix code, attack scenario |

## Configuration

| Setting | Default | Source |
|---------|---------|--------|
| `anthropic_model_code_review` | `claude-3-haiku-20240307` | `config.py` |
| `anthropic_max_tokens_code_review` | 2048 | `config.py` |
| `ai_code_review_enabled` | `true` | `config.py` |

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/review/suggestions` | JWT + `require_tier("team")` + rate limit | Generate AI review |
| GET | `/review/suggestions/{vulnerability_id}` | JWT | List suggestions for finding |
| GET | `/review/suggestions` | JWT | List all user suggestions |
| POST | `/review/feedback` | JWT | Submit feedback on suggestion |
| GET | `/review/feedback/{suggestion_id}` | JWT | Get feedback for suggestion |
| GET | `/review/stats` | JWT | User review statistics |

## Dashboard Display (v0.45.3)

All review results are displayed **inline on the vulnerability detail page** — no separate `/code-review` page navigation required. Each review card shows:

- Type badge (security/gas_optimization/best_practice/code_quality) + severity badge + confidence %
- Full suggestion text and risk explanation
- Expandable `<details>` blocks for attack scenario, recommended fix, and code comparison
- Original code (red-tinted) vs suggested code (green-tinted) in side-by-side concept
- Footer with model used, generation date, and feedback rating

## Files

| File | Role |
|------|------|
| `src/presentation/api/v1/endpoints/code_review.py` | Endpoint definitions, tier gating, rate limiting |
| `src/application/services/code_review_service.py` | Anthropic API integration, context assembly |
| `src/infrastructure/config.py` | Model selection, token limits |

## Error Handling

| Error | HTTP | Response |
|-------|------|----------|
| Feature disabled | 503 | `{"detail": "AI Code Review is currently disabled"}` |
| Tier insufficient | 403 | Tier gate rejection |
| Rate limited | 429 | Too many requests |
| Vulnerability not found | 404 | Standard not found |
| Anthropic API failure | 500 | Sanitized error via `get_safe_error_detail()` |

## Tier Quotas

| Tier | Code Review Requests/Month |
|------|----------------------------|
| Developer | 0 (blocked) |
| Team | 25 |
| Growth | 100 |
| Enterprise | Unlimited |
