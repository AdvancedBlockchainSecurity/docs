# Referral System Pipeline

Technical pipeline for the referral system implementation: database schema, API endpoints, admin configuration, Stripe reward integration, and dashboard UI.

## Overview

```
Database                    API Service                     Dashboard
────────                    ───────────                     ─────────
platform_settings    ←→     Admin settings endpoints   ←→   (Admin Portal)
referrals            ←      Apply/status endpoints     ←    ReferralCard, Signup
referral_rewards     ←      Reward creation logic      →    Stripe coupon
users.referral_code  ←→     Code generation endpoint   ←    ReferralCard
users.referred_by    ←      Apply endpoint             ←    Signup flow

Redis                       Middleware
─────                       ──────────
Rate limit keys      ←      slowapi (5/hour on /apply)
                             APICallTracker EXCLUDED_PREFIXES
```

---

## Database Schema

### Migration 078: `add_referral_system`

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `platform_settings` | Admin-configurable key-value store | `key` PK, `value`, `updated_by` FK |
| `referrals` | Referral event tracking | `referrer_user_id` FK, `referred_user_id` FK, `referral_code` |
| `referral_rewards` | Reward records | `referrer_user_id` FK, `status`, `stripe_coupon_id` |

### Users Table Extensions

| Column | Type | Purpose |
|--------|------|---------|
| `referral_code` | VARCHAR(20) UNIQUE | Personal shareable code |
| `referred_by_user_id` | UUID FK → users | Who referred this user |

### Seed Data

```sql
INSERT INTO platform_settings (key, value, description) VALUES
  ('referral_threshold', '3', 'Number of referrals needed to earn reward'),
  ('referral_reward_tier', 'team', 'Subscription tier granted as reward'),
  ('referral_reward_days', '30', 'Duration of reward in days'),
  ('referral_enabled', 'true', 'Whether referral system is active');
```

---

## API Endpoints

### User Endpoints (`src/presentation/api/v1/endpoints/referrals.py`)

| Endpoint | Method | Auth | Rate Limit | Response |
|----------|--------|------|------------|----------|
| `/api/v1/referrals/my-code` | GET | JWT | 10/min | `{ referral_code, share_url }` |
| `/api/v1/referrals/status` | GET | JWT | 10/min | `{ referral_count, referral_threshold, referrals[], rewards[] }` |
| `/api/v1/referrals/apply` | POST | JWT | 5/hour | `{ message, referral_id }` |

### Admin Endpoints (`src/presentation/api/v1/endpoints/admin/referrals.py`)

| Endpoint | Method | Auth | Rate Limit | Response |
|----------|--------|------|------------|----------|
| `/api/v1/admin/referrals/settings` | GET | Admin MFA | 10/min | `{ settings: { key: value } }` |
| `/api/v1/admin/referrals/settings` | PATCH | Admin MFA | 10/min | `{ settings: { key: value } }` |

### Schemas (`src/presentation/schemas/referrals.py`)

| Schema | Fields |
|--------|--------|
| `ReferralCodeResponse` | `referral_code`, `share_url` |
| `ReferralStatusResponse` | `referral_count`, `referral_threshold`, `referrals`, `rewards` |
| `ApplyReferralRequest` | `code` (validated: `^[A-Za-z0-9_-]{6,20}$`) |
| `ReferralSettingsResponse` | `referral_threshold`, `referral_reward_tier`, `referral_reward_days`, `referral_enabled` |
| `UpdateReferralSettingsRequest` | All settings optional |

---

## Stripe Integration

### Reward Application Flow

```
Referral threshold met
        │
        ├── Create referral_rewards record (status=pending, expires_at=+90d)
        │
        ├── Check: Does referrer have active Stripe subscription?
        │     │
        │     ├── YES → stripe.Coupon.create(percent_off=100, duration='once')
        │     │         stripe.Subscription.modify(sub_id, coupon=coupon.id)
        │     │         Update reward: status='applied', stripe_coupon_id=coupon.id
        │     │
        │     └── NO → Reward stays 'pending'
        │
        └── On future checkout.session.completed webhook:
              handle_checkout_session_completed() checks for pending rewards
              Auto-applies coupon if pending reward exists
```

### Webhook Integration

**File:** `src/presentation/api/v1/endpoints/stripe_webhook.py`

In `handle_checkout_session_completed()`:
1. After creating subscription record
2. Query `referral_rewards WHERE referrer_user_id = user.id AND status = 'pending'`
3. If found: create coupon, apply to subscription, update reward status

---

## Dashboard Components

### ReferralCard (`dashboard/src/components/referral/ReferralCard.tsx`)

**API Calls:**
- `GET /referrals/my-code` — on mount
- `GET /referrals/status` — on mount

**UI Elements:**
- Referral code display with copy button
- Share URL (copies `https://app.0xapogee.local/signup?ref=CODE`)
- Progress bar: `referral_count / referral_threshold`
- Reward status badges (pending = yellow, applied = green, expired = gray)

### API Client (`dashboard/src/lib/api/referrals.ts`)

```typescript
getReferralCode(): Promise<{ referral_code: string; share_url: string }>
getReferralStatus(): Promise<ReferralStatus>
applyReferralCode(code: string): Promise<{ message: string }>
```

### Signup Flow

**File:** `dashboard/src/pages/Signup.tsx` (or auth callback)

1. On page load: check `URLSearchParams` for `ref` param
2. Store in `localStorage.setItem('referral_code', code)`
3. After successful Supabase auth: `applyReferralCode(localStorage.getItem('referral_code'))`
4. On success: `localStorage.removeItem('referral_code')`

---

## Router Registration

**File:** `src/main.py`

```python
from src.presentation.api.v1.endpoints.referrals import router as referrals_router
from src.presentation.api.v1.endpoints.admin.referrals import router as admin_referrals_router

app.include_router(referrals_router, prefix="/api/v1")
app.include_router(admin_referrals_router, prefix="/api/v1")
```

---

## Middleware Configuration

### APICallTrackerMiddleware

**File:** `src/infrastructure/middleware/api_call_tracker.py`

Referral endpoints added to `EXCLUDED_PREFIXES` to prevent API call quota tracking for dashboard-facing endpoints:

```python
EXCLUDED_PREFIXES = (
    "/api/v1/auth/",
    "/api/v1/referrals/",
    "/api/v1/users/",
    "/api/v1/payments/",
    "/api/v1/billing/",
    "/api/v1/organizations/",
    "/api/v1/feedback/",
    "/api/v1/admin/",
    "/static/",
)
```

---

## Build and Deploy

### Version History

| Version | Changes |
|---------|---------|
| 0.29.47 | Initial referral system implementation |
| 0.29.48 | Fix: Add `response: Response` to rate-limited endpoints |
| 0.29.49 | Fix: Add dashboard-facing paths to APICallTracker EXCLUDED_PREFIXES |

### Deploy Commands

```bash
# API Service
cd /home/pwner/Git/blocksecops-api-service
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
docker build -t harbor.blocksecops.local/blocksecops/api-service:${VERSION} .
docker push harbor.blocksecops.local/blocksecops/api-service:${VERSION}
kubectl apply -k k8s/overlays/local/api-service/

# Dashboard
cd /home/pwner/Git
VERSION=$(grep '"version"' blocksecops-dashboard/package.json | head -1 | cut -d'"' -f4)
docker build -f blocksecops-dashboard/Dockerfile \
  --build-arg VITE_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  -t harbor.blocksecops.local/blocksecops/dashboard:${VERSION} .
docker push harbor.blocksecops.local/blocksecops/dashboard:${VERSION}
kubectl apply -k blocksecops-dashboard/k8s/overlays/local/
```

### Verification

```bash
# Health check
curl -s -k https://app.0xapogee.local/api/v1/health/ready | jq '.status'

# Referral endpoints responding
curl -s -k https://app.0xapogee.local/api/v1/referrals/my-code -w '%{http_code}' -o /dev/null
# Expected: 401 (unauthenticated) or 200 (authenticated)

# Database tables
kubectl exec postgresql-0 -n postgresql-local -- psql -U blocksecops -d solidity_security \
  -c "SELECT COUNT(*) FROM platform_settings;"
# Expected: 4

# Image versions
kubectl get deploy api-service -n api-service-local -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get deploy dashboard -n dashboard-local -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Files Involved

| File | Service | Action |
|------|---------|--------|
| `alembic/versions/20260301_1400-078_add_referral_system.py` | API | CREATE — migration |
| `src/infrastructure/database/models.py` | API | EDIT — 3 new models + 2 user columns |
| `src/presentation/api/v1/endpoints/referrals.py` | API | CREATE — user endpoints |
| `src/presentation/schemas/referrals.py` | API | CREATE — request/response schemas |
| `src/presentation/api/v1/endpoints/admin/referrals.py` | API | CREATE — admin endpoints |
| `src/presentation/api/v1/endpoints/stripe_webhook.py` | API | EDIT — pending reward check |
| `src/infrastructure/middleware/api_call_tracker.py` | API | EDIT — EXCLUDED_PREFIXES |
| `src/main.py` | API | EDIT — register routers |
| `pyproject.toml` | API | EDIT — 0.29.44 → 0.29.49 |
| `k8s/overlays/local/api-service/kustomization.yaml` | API | EDIT — newTag |
| `src/lib/api/referrals.ts` | Dashboard | CREATE — API client |
| `src/components/referral/ReferralCard.tsx` | Dashboard | CREATE — UI component |
| `src/pages/Settings.tsx` | Dashboard | EDIT — mount ReferralCard |
| `package.json` | Dashboard | EDIT — 0.46.12 → 0.46.13 |
| `k8s/overlays/local/kustomization.yaml` | Dashboard | EDIT — newTag |

---

## Related Documentation

- [Referral System Feature Test](../feature-tests/88-referral-system.md)
- [Referral System Playbook](../playbooks/referral-system.md)
- [Referral System Workflow](../workflows/referral-system-workflow.md)
- [Database Schema — Referral System](../database/SCHEMA.md#referral-system-march-2026)
- [Subscription Pipeline](./subscription-pipeline.md)
