# Playbook: Referral System Management

**Version:** 1.0.0
**Last Updated:** March 1, 2026
**Status:** Active

## Overview

Operational procedures for managing the Apogee referral system, including threshold adjustments, reward processing, troubleshooting, and monitoring.

## Prerequisites

- Access to API service (admin JWT or platform admin MFA session)
- Access to PostgreSQL database (for direct queries)
- Access to Stripe Dashboard (for reward coupon management)

---

## Part 1: Referral Configuration

### 1.1 View Current Settings

```bash
# Via API (requires platform_admin auth)
curl -s -k https://app.0xapogee.local/api/v1/admin/referrals/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Direct database query
kubectl exec postgresql-0 -n postgresql-local -- psql -U blocksecops -d solidity_security \
  -c "SELECT key, value, description, updated_at FROM platform_settings ORDER BY key;"
```

### 1.2 Update Referral Threshold

Change the number of referrals needed to earn a reward:

```bash
curl -s -k -X PATCH https://app.0xapogee.local/api/v1/admin/referrals/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"referral_threshold": 5}' | jq '.'
```

### 1.3 Update Reward Configuration

```bash
# Change reward tier (e.g., from starter to growth)
curl -s -k -X PATCH https://app.0xapogee.local/api/v1/admin/referrals/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"referral_reward_tier": "growth", "referral_reward_days": 60}' | jq '.'
```

### 1.4 Enable/Disable Referral System

```bash
# Disable referrals
curl -s -k -X PATCH https://app.0xapogee.local/api/v1/admin/referrals/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"referral_enabled": false}' | jq '.'
```

---

## Part 2: Monitoring Referrals

### 2.1 Referral Statistics

```sql
-- Total referrals by status
SELECT status, COUNT(*) FROM referrals GROUP BY status;

-- Top referrers
SELECT u.email, COUNT(r.id) as referral_count
FROM referrals r
JOIN users u ON u.id = r.referrer_user_id
GROUP BY u.email
ORDER BY referral_count DESC
LIMIT 10;

-- Referrals by day
SELECT DATE(created_at) as day, COUNT(*) as referrals
FROM referrals
GROUP BY DATE(created_at)
ORDER BY day DESC
LIMIT 30;
```

### 2.2 Reward Statistics

```sql
-- Rewards by status
SELECT status, COUNT(*) FROM referral_rewards GROUP BY status;

-- Pending rewards needing attention
SELECT rr.id, u.email, rr.status, rr.qualifying_referral_count, rr.created_at, rr.expires_at
FROM referral_rewards rr
JOIN users u ON u.id = rr.referrer_user_id
WHERE rr.status = 'pending'
ORDER BY rr.created_at;

-- Expired rewards
SELECT COUNT(*) FROM referral_rewards
WHERE status = 'pending' AND expires_at < NOW();
```

---

## Part 3: Reward Processing

### 3.1 Manual Reward Application (Stripe)

If automatic Stripe coupon application fails:

1. **Find the pending reward:**
   ```sql
   SELECT rr.id, u.email, rr.plan_tier, rr.qualifying_referral_count
   FROM referral_rewards rr
   JOIN users u ON u.id = rr.referrer_user_id
   WHERE rr.status = 'pending' AND u.email = 'user@example.com';
   ```

2. **Create Stripe coupon manually:**
   ```bash
   # In Stripe Dashboard: Coupons → Create → 100% off → Once → Apply to customer
   ```

3. **Update reward record:**
   ```sql
   UPDATE referral_rewards
   SET status = 'applied',
       applied_at = NOW(),
       stripe_coupon_id = 'coupon_xxx'
   WHERE id = 'reward-uuid';
   ```

### 3.2 Expire Stale Rewards

```sql
-- Mark expired rewards
UPDATE referral_rewards
SET status = 'expired'
WHERE status = 'pending'
  AND expires_at < NOW();
```

---

## Part 4: Troubleshooting

### 4.1 User Cannot Generate Referral Code

**Symptoms:** 500 error on `GET /referrals/my-code`

**Check:**
1. Verify user is authenticated (valid JWT)
2. Check API service logs: `kubectl logs -n api-service-local -l app.kubernetes.io/name=api-service --tail=50`
3. Verify `users` table has `referral_code` column: `\d users`

### 4.2 Apply Endpoint Returns 429

**Symptoms:** Rate limit exceeded on `/referrals/apply`

**Check:**
1. Rate limit is 5/hour per IP
2. Clear rate limit in Redis:
   ```bash
   kubectl exec -n redis-local $(kubectl get pod -n redis-local -l app=redis -o jsonpath='{.items[0].metadata.name}') \
     -- redis-cli -a "blocksecops-redis-password" KEYS "LIMITS:LIMITER/*/referrals*"
   ```
3. Delete specific key to reset:
   ```bash
   kubectl exec -n redis-local $(kubectl get pod -n redis-local -l app=redis -o jsonpath='{.items[0].metadata.name}') \
     -- redis-cli -a "blocksecops-redis-password" DEL "LIMITS:LIMITER/{ip}//api/v1/referrals/apply/5/1/hour"
   ```

### 4.3 Reward Not Created After Threshold

**Symptoms:** User has 3+ referrals but no reward record

**Check:**
1. Verify referral count:
   ```sql
   SELECT COUNT(*) FROM referrals
   WHERE referrer_user_id = 'user-uuid' AND status = 'completed';
   ```
2. Verify current threshold:
   ```sql
   SELECT value FROM platform_settings WHERE key = 'referral_threshold';
   ```
3. Check if reward already exists:
   ```sql
   SELECT * FROM referral_rewards WHERE referrer_user_id = 'user-uuid';
   ```

### 4.4 APICallTrackerMiddleware Blocking Referral Endpoints

**Symptoms:** 429 "API call limit exceeded" (not rate limit)

**Check:** Referral endpoints must be in `EXCLUDED_PREFIXES` in `api_call_tracker.py`:
```python
EXCLUDED_PREFIXES = (
    "/api/v1/auth/",
    "/api/v1/referrals/",  # Must be present
    ...
)
```

---

## Part 5: Verification Checklist

After any changes to the referral system:

- [ ] `GET /referrals/my-code` returns 200 with code
- [ ] `GET /referrals/status` returns correct threshold
- [ ] `POST /referrals/apply` with valid code returns 200
- [ ] `POST /referrals/apply` with own code returns 400
- [ ] `GET /admin/referrals/settings` returns all 4 settings
- [ ] `PATCH /admin/referrals/settings` updates successfully
- [ ] Platform settings seed data intact (4 rows)
- [ ] Dashboard ReferralCard renders in Settings page

---

## Related Documentation

- [Referral System Feature Test](../feature-tests/88-referral-system.md)
- [Referral System Workflow](../workflows/referral-system-workflow.md)
- [Referral System Pipeline](../pipelines/referral-system-pipeline.md)
- [Database Schema — Referral System](../database/SCHEMA.md#referral-system-march-2026)
- [Stripe Payment Setup Playbook](./stripe-payment-setup.md)
