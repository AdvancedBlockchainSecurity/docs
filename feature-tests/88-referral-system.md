# Feature Test: Referral System

**Date:** 2026-03-01
**Version:** API Service v0.29.49, Dashboard v0.46.13
**Migration:** 078_add_referral_system

## Test Objective

Verify the referral system: code generation, sharing, applying codes, reward threshold logic, admin settings management, Stripe reward integration, and dashboard UI.

---

## TC-88-001: Referral Code Generation

**Priority:** High
**Endpoint:** `GET /api/v1/referrals/my-code`
**Auth:** JWT (any authenticated user)

### Steps

1. Authenticate as a user with no existing referral code
2. Call `GET /api/v1/referrals/my-code`
3. Verify response contains `referral_code` and `share_url`
4. Call endpoint again — verify same code is returned (idempotent)

### Expected

- [x] Returns 200 with `referral_code` (8 chars, alphanumeric + `_-`)
- [x] Returns `share_url` in format `https://app.0xapogee.com/signup?ref=CODE`
- [x] Subsequent calls return the same code
- [x] Returns 401 without authentication

### Verification

```bash
curl -s -k https://app.0xapogee.com/api/v1/referrals/my-code \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

**Result:** PASS

---

## TC-88-002: Referral Status Dashboard

**Priority:** High
**Endpoint:** `GET /api/v1/referrals/status`
**Auth:** JWT (any authenticated user)

### Steps

1. Authenticate as a user
2. Call `GET /api/v1/referrals/status`
3. Verify response contains referral count, threshold, and reward info

### Expected

- [x] Returns 200 with `referral_count`, `referral_threshold`, `referrals`, `rewards`
- [x] `referral_threshold` matches `platform_settings` value (default: 3)
- [x] `referral_count` reflects actual completed referrals
- [x] Returns 401 without authentication

### Verification

```bash
curl -s -k https://app.0xapogee.com/api/v1/referrals/status \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

**Result:** PASS

---

## TC-88-003: Apply Referral Code (Happy Path)

**Priority:** High
**Endpoint:** `POST /api/v1/referrals/apply`
**Auth:** JWT (any authenticated user)
**Rate Limit:** 5/hour

### Steps

1. User A generates a referral code
2. User B (new signup) calls `POST /api/v1/referrals/apply` with User A's code
3. Verify referral record created

### Expected

- [x] Returns 200 with success message
- [x] Referral record created in `referrals` table with status 'completed'
- [x] User B's `referred_by_user_id` set to User A's ID
- [x] Returns 401 without authentication

### Verification

```bash
curl -s -k -X POST https://app.0xapogee.com/api/v1/referrals/apply \
  -H "Authorization: Bearer $TOKEN_B" \
  -H "Content-Type: application/json" \
  -d '{"code": "USER_A_CODE"}' | jq '.'
```

**Result:** PASS

---

## TC-88-004: Self-Referral Blocked

**Priority:** High
**Endpoint:** `POST /api/v1/referrals/apply`

### Steps

1. User A generates a referral code
2. User A attempts to apply their own code

### Expected

- [x] Returns 400 with error "Cannot use your own referral code"
- [x] No referral record created

**Result:** PASS

---

## TC-88-005: Duplicate Referral Blocked

**Priority:** High
**Endpoint:** `POST /api/v1/referrals/apply`

### Steps

1. User B has already been referred by User A
2. User B attempts to apply any referral code again

### Expected

- [x] Returns 409 with error indicating user already referred
- [x] No duplicate referral record created

**Result:** PASS

---

## TC-88-006: Invalid Referral Code

**Priority:** Medium
**Endpoint:** `POST /api/v1/referrals/apply`

### Steps

1. User B calls apply with a nonexistent referral code

### Expected

- [x] Returns 404 with error "Referral code not found"

**Result:** PASS

---

## TC-88-007: Referral Code Validation

**Priority:** Medium
**Endpoint:** `POST /api/v1/referrals/apply`

### Steps

1. Send codes with invalid format (empty, too short, special chars, SQL injection, XSS)

### Expected

- [x] Returns 422 for codes not matching `^[A-Za-z0-9_-]{6,20}$`
- [x] XSS/SQL payloads rejected by input validation
- [x] All text sanitized via `sanitize_user_text`

**Result:** PASS

---

## TC-88-008: Rate Limiting on Apply Endpoint

**Priority:** Medium
**Endpoint:** `POST /api/v1/referrals/apply`

### Steps

1. Send 6 requests to `/referrals/apply` within 1 hour from the same IP

### Expected

- [x] First 5 requests processed normally
- [x] 6th request returns 429 Too Many Requests
- [x] Rate limit header shows remaining attempts

**Result:** PASS

---

## TC-88-009: Reward Threshold Logic

**Priority:** Critical
**Endpoint:** `POST /api/v1/referrals/apply`

### Steps

1. Set referral threshold to 3 (default)
2. User A generates referral code
3. Users B, C, D each apply User A's code
4. After 3rd referral, check for reward creation

### Expected

- [x] After 1st and 2nd referral: no reward created
- [x] After 3rd referral: `referral_rewards` record created
- [x] Reward has `status='pending'`, `reward_type='free_month'`, `plan_tier='starter'`
- [x] `qualifying_referral_count=3`
- [x] `expires_at` set to 90 days from creation

**Result:** PASS

---

## TC-88-010: Admin Get Referral Settings

**Priority:** High
**Endpoint:** `GET /api/v1/admin/referrals/settings`
**Auth:** Platform admin (MFA session)

### Steps

1. Authenticate as platform admin
2. Call `GET /api/v1/admin/referrals/settings`

### Expected

- [x] Returns 200 with all 4 settings: `referral_threshold`, `referral_reward_tier`, `referral_reward_days`, `referral_enabled`
- [x] Returns 401/403 for non-admin users

### Verification

```bash
curl -s -k https://app.0xapogee.com/api/v1/admin/referrals/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'
```

**Result:** PASS

---

## TC-88-011: Admin Update Referral Settings

**Priority:** High
**Endpoint:** `PATCH /api/v1/admin/referrals/settings`
**Auth:** Platform admin (MFA session)

### Steps

1. Authenticate as platform admin
2. Update `referral_threshold` from 3 to 5
3. Verify setting persisted
4. Verify `GET /referrals/status` reflects new threshold for regular users

### Expected

- [x] Returns 200 with updated settings
- [x] `updated_by` set to admin user ID
- [x] `updated_at` reflects current timestamp
- [x] Regular user's status endpoint shows new threshold
- [x] Returns 401/403 for non-admin users

**Result:** PASS

---

## TC-88-012: Referral System Disabled

**Priority:** Medium
**Endpoint:** `PATCH /api/v1/admin/referrals/settings`

### Steps

1. Admin sets `referral_enabled` to `false`
2. User attempts to generate/apply referral codes

### Expected

- [x] Code generation returns 403 "Referral program is currently disabled"
- [x] Apply endpoint returns 403 when disabled
- [x] Status endpoint returns `referral_enabled: false`

**Result:** PASS

---

## TC-88-013: Dashboard Referral Card

**Priority:** Medium
**Component:** `ReferralCard.tsx` in Settings page

### Steps

1. Navigate to Settings page in dashboard
2. Verify ReferralCard component renders

### Expected

- [x] Personal referral code displayed
- [x] Copy button copies share URL to clipboard
- [x] Progress bar shows X/3 referrals
- [x] Reward status badge displayed when applicable
- [x] Dashboard bundle contains referral components (verified via source inspection)

**Result:** PASS

---

## TC-88-014: Dashboard Signup Referral Flow

**Priority:** Medium
**Component:** Signup page with `?ref=` parameter

### Steps

1. Navigate to signup URL with `?ref=CODE` parameter
2. Complete signup
3. Verify code is applied after authentication

### Expected

- [x] `ref` parameter stored in localStorage during signup
- [x] After successful auth, `POST /referrals/apply` called with stored code
- [x] Referral applied successfully

**Result:** PASS

---

## TC-88-015: Stripe Reward Application

**Priority:** High
**Component:** `stripe_webhook.py` → `handle_checkout_session_completed()`

### Steps

1. User earns a referral reward (status=pending)
2. User subscribes via Stripe checkout

### Expected

- [ ] On `checkout.session.completed`, pending reward is detected
- [ ] Stripe coupon created (100% off, duration=once)
- [ ] Coupon applied to subscription
- [ ] Reward status updated to 'applied'
- [ ] `stripe_coupon_id` stored on reward record

**Result:** PENDING (requires live Stripe webhook in production)

---

## TC-88-016: Database Integrity

**Priority:** High

### Steps

1. Verify all referral tables exist
2. Verify foreign key constraints
3. Verify indexes
4. Verify seed data

### Expected

- [x] `platform_settings` table exists with 4 seed rows
- [x] `referrals` table exists with proper FK constraints
- [x] `referral_rewards` table exists with proper FK constraints
- [x] `users.referral_code` column exists with UNIQUE constraint
- [x] `users.referred_by_user_id` column exists with FK to users
- [x] All indexes created (7 indexes total)

### Verification

```bash
# Check tables
kubectl exec postgresql-0 -n postgresql-local -- psql -U blocksecops -d solidity_security \
  -c "SELECT table_name FROM information_schema.tables WHERE table_name IN ('platform_settings', 'referrals', 'referral_rewards');"

# Check seed data
kubectl exec postgresql-0 -n postgresql-local -- psql -U blocksecops -d solidity_security \
  -c "SELECT key, value FROM platform_settings ORDER BY key;"

# Check user columns
kubectl exec postgresql-0 -n postgresql-local -- psql -U blocksecops -d solidity_security \
  -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='users' AND column_name IN ('referral_code', 'referred_by_user_id');"
```

**Result:** PASS

---

## Summary

| Test | Status | Notes |
|------|--------|-------|
| TC-88-001 Code Generation | PASS | Idempotent, 8-char codes |
| TC-88-002 Status Dashboard | PASS | Correct count and threshold |
| TC-88-003 Apply Code | PASS | Creates referral record |
| TC-88-004 Self-Referral | PASS | 400 error |
| TC-88-005 Duplicate Referral | PASS | 409 error |
| TC-88-006 Invalid Code | PASS | 404 error |
| TC-88-007 Code Validation | PASS | Input sanitization working |
| TC-88-008 Rate Limiting | PASS | 5/hour enforced |
| TC-88-009 Reward Threshold | PASS | Reward created at threshold |
| TC-88-010 Admin Get Settings | PASS | 4 settings returned |
| TC-88-011 Admin Update Settings | PASS | Threshold change reflected |
| TC-88-012 System Disabled | PASS | All endpoints return 403 when disabled |
| TC-88-013 Dashboard Card | PASS | UI renders correctly |
| TC-88-014 Signup Flow | PASS | ref param captured |
| TC-88-015 Stripe Reward | PENDING | Requires live Stripe webhook |
| TC-88-016 Database Integrity | PASS | All tables, indexes, seed data verified |

**Overall: 15/16 PASS, 1 PENDING** (Stripe webhook requires live Stripe environment)

---

## Issues Found During Testing

### Bug #1: Missing `response: Response` Parameter (Fixed)
- **Severity:** Critical
- **File:** `referrals.py`, `admin/referrals.py`
- **Issue:** slowapi rate limiter requires `response: Response` in endpoint signatures
- **Fix:** Added parameter to all 5 endpoints
- **Version:** Fixed in v0.29.48

### Bug #2: APICallTrackerMiddleware Blocking Dashboard Endpoints (Fixed)
- **Severity:** Critical
- **File:** `api_call_tracker.py`
- **Issue:** Dashboard-facing endpoints (referrals, users, billing, etc.) were tracked by API call quota middleware, causing 429 errors for developer/team tier users
- **Fix:** Added `/api/v1/referrals/`, `/api/v1/users/`, `/api/v1/payments/`, `/api/v1/billing/`, `/api/v1/organizations/`, `/api/v1/feedback/`, `/api/v1/admin/` to `EXCLUDED_PREFIXES`
- **Version:** Fixed in v0.29.49
