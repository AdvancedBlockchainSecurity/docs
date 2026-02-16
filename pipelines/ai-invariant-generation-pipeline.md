# AI Invariant Generation Pipeline

AI-powered Foundry invariant test generation for smart contracts. Generates formal verification properties with tier-based quotas, daily caps, and cooldown enforcement. Uses Claude Sonnet for quality output.

## Overview

```
Dashboard (Vulnerability Detail)  API Service (invariants.py → InvariantService)     External
────────────────────────────────  ──────────────────────────────────────────────     ────────
POST /invariants/generate →       1. Authenticate (JWT)                              PostgreSQL
                                  2. Validate tier (growth+)
                                  3. Check feature flag
                                  4. Check monthly + daily quota
                                  5. Check cooldown (5s between requests)
                                  6. Validate contract size (50KB max)
                                  7. Detect prompt injection
                                  8. Call Anthropic Claude API
                                  9. Validate AI output
                                  10. Store invariants
                           ←      Return InvariantGenerationResponse (201)           Anthropic API
```

## Trigger

- **Dashboard**: User clicks "Generate Invariants" in the AI Actions panel on the Vulnerability Detail page (`/vulnerabilities/:id`)
- **Input**: `contract_id` and `contract_code` are auto-populated from the vulnerability's associated contract. Default `invariant_types`: `['state', 'access', 'arithmetic', 'reentrancy']`
- **Note**: Standalone invariant generation pages (`/invariants`) have been removed. Invariants are now part of the vulnerability analysis workflow alongside Code Review, Code Repair, and PoC Exploit generation.

## Pipeline Steps

| # | Step | Component | Description |
|---|------|-----------|-------------|
| 1 | Authentication | `get_current_user` | JWT required |
| 2 | Tier gate | `require_tier("growth")` | Developer and Team tiers blocked with upgrade message |
| 3 | Feature flag | `settings.ai_features_enabled` | Returns 503 if disabled |
| 4 | Quota check | Monthly (tier-based) + daily (500 enterprise cap) | Returns 429 with quota details |
| 5 | Cooldown check | 5-second minimum between requests | Returns 429 with `Retry-After` header |
| 6 | Size validation | 50KB max contract size | Returns 400 if exceeded |
| 7 | Injection detection | Pattern matching on input | Returns 400 if injection detected |
| 8 | Rate limiting | `@limiter.limit(get_rate_limit_string("ai", "invariants"))` | Per-tier rate limits (BSO-SEC-AI-003) |
| 9 | Anthropic API call | `InvariantService.generate_invariants()` | Model: `claude-sonnet-4-20250514`, max tokens: 4096 |
| 10 | Output validation | Pattern checks on AI response | Detect injection relay |
| 11 | Store result | Database INSERT | Save invariants with type, test code, explanation |

## Quota Enforcement

| Tier | Monthly Limit | Daily Limit | Cooldown |
|------|---------------|-------------|----------|
| Developer | 0 (blocked) | N/A | N/A |
| Team | 10 | N/A | 5 seconds |
| Growth | 50 | N/A | 5 seconds |
| Enterprise | Unlimited | 500/day | 5 seconds |

Error responses for quota exhaustion:

- `InvariantTierError` → **403** with tier info and upgrade URL
- `InvariantQuotaError` → **429** with `monthly_limit`, `monthly_used`, `resets_at`
- `InvariantCooldownError` → **429** with `Retry-After` header

## Configuration

| Setting | Default | Source |
|---------|---------|--------|
| `anthropic_model_invariant` | `claude-sonnet-4-20250514` | `config.py` |
| `anthropic_max_tokens_invariant` | 4096 | `config.py` |
| `invariant_token_budget_per_request` | 8000 | `config.py` |
| `invariant_cooldown_seconds` | 5 | `config.py` |
| `invariant_daily_limit_enterprise` | 500 | `config.py` |
| `ai_invariant_enabled` | `true` | `config.py` |

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/invariants/generate` | JWT + `require_tier("team")` + rate limit + quota | Generate invariants |
| GET | `/invariants/{invariant_id}` | JWT | Get specific invariant |
| GET | `/invariants` | JWT | List user invariants (filtered) |
| GET | `/invariants/contracts/{contract_id}` | JWT | List invariants for contract |
| POST | `/invariants/{invariant_id}/apply` | JWT | Mark as applied |
| POST | `/invariants/{invariant_id}/feedback` | JWT | Submit feedback |
| DELETE | `/invariants/{invariant_id}` | JWT | Delete invariant |
| GET | `/invariants/user/statistics` | JWT | Usage statistics |
| GET | `/invariants/user/quota` | JWT | Current quota status |
| GET | `/invariants/templates` | JWT | List invariant templates |
| GET | `/invariants/templates/{template_id}` | JWT | Get specific template |

## Invariant Types

| Type | Description | Default |
|------|-------------|---------|
| `state` | State variable invariants (e.g., "total supply never exceeds cap") | Yes |
| `access` | Permission and role invariants | Yes |
| `arithmetic` | Overflow/underflow guards | Yes |
| `economic` | Economic/DeFi property invariants | No |
| `reentrancy` | Reentrancy protection invariants | Yes |
| `custom` | User-defined custom invariants | No |

**Note:** When triggered from the Vulnerability Detail page, the default types are `state`, `access`, `arithmetic`, and `reentrancy`.

## Files

| File | Repo | Role |
|------|------|------|
| `src/presentation/api/v1/endpoints/invariants.py` | api-service | Endpoints, tier gating, quota checks, rate limiting |
| `src/application/services/invariant_service.py` | api-service | Anthropic API integration, quota enforcement, template management |
| `src/infrastructure/config.py` | api-service | Model selection, token limits, cooldown settings |
| `src/pages/VulnerabilityDetail.tsx` | dashboard | "Generate Invariants" button in AI Actions panel |
| `src/hooks/useInvariants.ts` | dashboard | `useGenerateInvariants`, `useContractInvariants` React Query hooks |
| `src/lib/api/invariants.ts` | dashboard | API client methods |

## Error Handling

| Error | HTTP | Response |
|-------|------|----------|
| Feature disabled | 503 | Service unavailable |
| Developer tier | 403 | `InvariantTierError` with upgrade info |
| Quota exhausted | 429 | `InvariantQuotaError` with quota details |
| Cooldown active | 429 | `Retry-After` header |
| Contract too large | 400 | Size limit exceeded |
| Injection detected | 400 | Validation error |
| Rate limited | 429 | Too many requests |
| Anthropic API failure | 500 | Sanitized error |
