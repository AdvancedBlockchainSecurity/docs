# Referral System Workflow

**Version:** 1.0.0
**Last Updated:** March 1, 2026

## Overview

Documents the end-to-end referral flow from code generation through reward application, including all services involved and data transformations.

## Services Involved

| Service | Role | Version |
|---------|------|---------|
| API Service | Referral endpoints, reward logic, Stripe integration | v0.29.49 |
| Dashboard | ReferralCard UI, signup `?ref=` capture | v0.46.13 |
| PostgreSQL | platform_settings, referrals, referral_rewards tables | Migration 078 |
| Redis | Rate limiting for `/referrals/apply` (5/hour) | — |
| Stripe | Coupon creation, subscription discount | — |

## Referral Lifecycle

```
Phase 1: Code Generation
─────────────────────────
User → Settings page → GET /referrals/my-code
                              │
                              ├── User has code? → Return existing
                              └── No code? → secrets.token_urlsafe(6)
                                              → Save to users.referral_code
                                              → Return code + share_url

Phase 2: Sharing
────────────────
User copies share URL: https://app.0xapogee.local/signup?ref=CODE
                              │
                              └── Shares via email, social, etc.

Phase 3: Signup + Apply
───────────────────────
New user → Signup page (?ref=CODE)
                │
                ├── localStorage.setItem('referral_code', CODE)
                └── Complete Supabase auth
                        │
                        └── POST /referrals/apply { code: CODE }
                                │
                                ├── Validate: code matches ^[A-Za-z0-9_-]{6,20}$
                                ├── Validate: code exists in users.referral_code
                                ├── Validate: referrer != current_user (no self-referral)
                                ├── Validate: current_user.referred_by_user_id IS NULL (not already referred)
                                ├── Create referral record (status='completed')
                                ├── Set current_user.referred_by_user_id = referrer.id
                                └── Check threshold → Phase 4 if met

Phase 4: Reward Evaluation
──────────────────────────
After each successful referral:
                │
                ├── COUNT referrals WHERE referrer_user_id = ? AND status = 'completed'
                ├── SELECT value FROM platform_settings WHERE key = 'referral_threshold'
                │
                ├── count < threshold → No action
                └── count >= threshold → Create referral_reward
                        │
                        ├── reward_type = 'free_month'
                        ├── plan_tier = platform_settings['referral_reward_tier']
                        ├── status = 'pending'
                        ├── qualifying_referral_count = count
                        └── expires_at = NOW() + 90 days

Phase 5: Reward Application (Stripe)
─────────────────────────────────────
Option A: Referrer has active subscription
                │
                ├── stripe.Coupon.create(percent_off=100, duration='once')
                ├── stripe.Subscription.modify(sub_id, coupon=coupon.id)
                ├── Update reward: status='applied', applied_at=NOW()
                └── Store stripe_coupon_id on reward

Option B: Referrer subscribes later
                │
                ├── Stripe webhook: checkout.session.completed
                ├── handle_checkout_session_completed() checks for pending rewards
                ├── If pending reward found → apply coupon (same as Option A)
                └── Update reward status
```

## API Summary

| Method | Path | Auth | Rate Limit | Purpose |
|--------|------|------|------------|---------|
| GET | `/api/v1/referrals/my-code` | JWT | 10/min | Get/generate personal referral code |
| GET | `/api/v1/referrals/status` | JWT | 10/min | Referral dashboard with count, threshold, rewards |
| POST | `/api/v1/referrals/apply` | JWT | 5/hour | Apply a referral code after signup |
| GET | `/api/v1/admin/referrals/settings` | Admin MFA | 10/min | Get referral system configuration |
| PATCH | `/api/v1/admin/referrals/settings` | Admin MFA | 10/min | Update referral thresholds and settings |

## Dashboard Integration

### ReferralCard Component

**Location:** `dashboard/src/components/referral/ReferralCard.tsx`
**Mounted in:** Settings page (`dashboard/src/pages/Settings.tsx`)

**Features:**
- Personal referral code display
- Copy-to-clipboard button with share URL
- Progress bar: X / threshold referrals
- Reward status badge (pending/applied/expired)

### Signup Referral Capture

**Flow:**
1. URL parameter: `?ref=CODE` on signup page
2. `localStorage.setItem('referral_code', code)`
3. After successful Supabase auth, frontend calls `POST /referrals/apply`
4. `localStorage.removeItem('referral_code')` on success

## Security Controls

| Control | Implementation |
|---------|----------------|
| Self-referral prevention | API checks `referrer_user_id != current_user.id` |
| Duplicate referral prevention | `referred_by_user_id` set once, checked before apply |
| Rate limiting | 5/hour on `/apply` via slowapi + Redis |
| Input validation | Regex `^[A-Za-z0-9_-]{6,20}$` on referral codes |
| Text sanitization | `sanitize_user_text()` on all string inputs |
| Admin authorization | Platform admin MFA session required for settings |
| Cryptographic codes | `secrets.token_urlsafe(6)` — 8 chars, URL-safe |

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| 429 on referral endpoints | APICallTrackerMiddleware | Ensure `/api/v1/referrals/` in EXCLUDED_PREFIXES |
| 500 on rate-limited endpoints | Missing `response: Response` param | Add parameter to endpoint function signature |
| Reward not created | Threshold not met or already rewarded | Check referral count vs threshold |
| Coupon not applied | No active subscription | Reward stays pending; applied on checkout |

## Related Documentation

- [Referral System Feature Test](../feature-tests/88-referral-system.md)
- [Referral System Playbook](../playbooks/referral-system.md)
- [Referral System Pipeline](../pipelines/referral-system-pipeline.md)
- [Stripe Payment Setup](../playbooks/stripe-payment-setup.md)
- [Billing & Subscription Workflow](./billing-subscription-workflow.md)
