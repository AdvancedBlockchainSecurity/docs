# Stripe Security Audit Pipeline

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Sequenced technical/automation steps that the security audit playbook orchestrates — exact `grep` / `curl` / `kubectl` / `psql` commands for signature failure injection, replay, metadata fuzzing, redirect whitelist enumeration, secret-leak scan, audit-log query.
**Audience:** `apogee-security-audit` agent + operator
**Audit Type:** security (technical sequence)

---

## ⚠️ Mandatory End-to-End Execution

**This pipeline MUST be executed from beginning to end without skipping any step, even if it was run recently.** Each step's output feeds the next. Skipping invalidates the resulting findings. If a step fails or returns unexpected output, fix the underlying issue and re-run **from Phase 1** of `docs/audit-playbooks/stripe-security-audit-playbook.md`.

---

## Overview

This pipeline is the technical companion to `docs/audit-playbooks/stripe-security-audit-playbook.md`. The playbook describes *what* to test and *why*; this pipeline describes *how* — exact commands, expected output snippets, and where to capture evidence.

All commands are **read-only or test-mode adversarial**. No GitOps, no production writes. Local cluster only (per `feedback_local_not_gcp.md`). Replace `<ingress-host>` with the local ingress hostname and `<api-namespace>` with the API namespace per `docs/standards/service-availability.md`.

---

## Prerequisites

See `docs/audit-playbooks/stripe-security-audit-playbook.md` Prerequisites. Plus:

- [ ] `stripe-cli` authenticated to test mode
- [ ] `psql` access to local PostgreSQL `solidity_security` DB
- [ ] `kubectl` access to local cluster
- [ ] Bearer token / API key for the test account (session-only, not persisted)

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md`
- `docs/standards/secure-coding.md`
- `docs/standards/secrets-management.md`
- `docs/standards/encryption-standards.md`
- `docs/standards/service-availability.md` (no port-forward for primary access)
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-25-platform-security-audit.md`
- `docs/audits/2026-02-25-auth-x402-audit.md`
- `docs/audit/security-audit-fresh-2026-03-15.md`

---

## Phase 1 — Signature Verification

```bash
# 1.1.1 No signature header
curl -i -X POST "https://<ingress-host>/api/v1/webhooks/stripe" \
  -H "Content-Type: application/json" \
  --data '{"id":"evt_test","type":"checkout.session.completed","data":{"object":{}}}'
# Expected: HTTP/1.1 400; body indicates missing signature

# 1.1.2 Malformed signature header
curl -i -X POST "https://<ingress-host>/api/v1/webhooks/stripe" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: garbage" \
  --data '{"id":"evt_test","type":"checkout.session.completed","data":{"object":{}}}'
# Expected: HTTP/1.1 400

# 1.1.3 Wrong-secret signature (signed with rotated/old whsec)
# Use stripe CLI offline-signing or compute HMAC-SHA256 with a wrong secret, then
curl -i -X POST "https://<ingress-host>/api/v1/webhooks/stripe" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=<ts>,v1=<wrong-hmac>" \
  --data @evt.json
# Expected: HTTP/1.1 400

# 1.1.4 Audit-log evidence
psql "postgresql://blocksecops@<pg-host>/solidity_security?sslmode=prefer" -c "
  SELECT created_at, alert_type, source_ip, user_agent
  FROM audit_logs
  WHERE alert_type = 'STRIPE_SIGNATURE_FAILURE'
  ORDER BY created_at DESC
  LIMIT 20;
"
# Expected: One row per failed test above
```

**Capture:** HTTP responses + audit-log rows.

---

## Phase 2 — Webhook Idempotency

```bash
# 2.1.1 Replay a known good event
EVENT_ID=$(stripe events list --limit 1 --type checkout.session.completed -q | jq -r '.data[0].id')
stripe events resend "$EVENT_ID"

# Verify no double-credit / double-create
psql "postgresql://blocksecops@<pg-host>/solidity_security?sslmode=prefer" -c "
  SELECT COUNT(*) FROM payment_transactions
  WHERE stripe_session_id = (
    SELECT data->'object'->>'id' FROM stripe_event_log WHERE event_id = '$EVENT_ID'
  );
"
# Expected: count = 1 (not 2)

# 2.1.2 Subscription event replay
stripe events resend evt_<known_subscription_event>
psql "..." -c "SELECT updated_at FROM subscriptions WHERE stripe_subscription_id='sub_...';"
# Expected: updated_at unchanged from prior replay (idempotent no-op)
```

**Capture:** Row counts before/after each replay.

---

## Phase 3 — Metadata Whitelist Fuzzing

```bash
# 3.1.1 Tier escalation attempt: send Starter price ID with tier=enterprise metadata
stripe trigger checkout.session.completed \
  --add checkout_session:metadata.tier=enterprise \
  --add checkout_session:line_items[0].price=$STRIPE_PRICE_STARTER_MONTHLY

# Verify handler used price ID, not metadata
psql "..." -c "SELECT tier FROM subscriptions WHERE stripe_subscription_id='<new-sub>';"
# Expected: tier = 'starter' (NOT 'enterprise')

# 3.1.2 user_id forgery
stripe trigger checkout.session.completed \
  --add checkout_session:metadata.user_id=<other-user-uuid>

# Verify subscription assigned by customer ID, not metadata
psql "..." -c "SELECT user_id FROM subscriptions WHERE stripe_subscription_id='<new-sub>';"
# Expected: user_id = customer-derived owner, not the forged value

# 3.1.4 Invalid package_id
stripe trigger checkout.session.completed \
  --add checkout_session:metadata.package_id=fake_package \
  --add checkout_session:mode=payment
# Expected: handler rejects; no credit added; audit log entry

# 3.1.5 Oversize / control-char metadata
LONG=$(python -c "print('x'*600)")
stripe trigger checkout.session.completed --add checkout_session:metadata.note="$LONG"
# Expected: rejected
```

**Capture:** DB state per attempt; handler rejection codes.

---

## Phase 4 — Redirect Whitelist Enumeration

```bash
# 4.1.1 Off-host
curl -i -X POST "https://<ingress-host>/api/v1/payments/checkout/stripe" \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"package_id":"<valid>","success_url":"https://attacker.example/","cancel_url":"https://<ingress-host>/cancel"}'
# Expected: 400/422; rejected by _validate_redirect_url()

# 4.1.2 javascript: scheme
curl -i ... --data '{"package_id":"<valid>","success_url":"javascript:alert(1)","cancel_url":"https://<ingress-host>/cancel"}'
# Expected: 400/422

# 4.1.3 userinfo injection
curl -i ... --data '{"package_id":"<valid>","success_url":"https://attacker@<ingress-host>/","cancel_url":"https://<ingress-host>/cancel"}'
# Expected: 400/422

# 4.1.4 Path traversal
curl -i ... --data '{"package_id":"<valid>","success_url":"https://<ingress-host>/../../evil","cancel_url":"https://<ingress-host>/cancel"}'
# Expected: 400/422

# 4.1.5 Whitelisted URL (positive)
curl -i ... --data '{"package_id":"<valid>","success_url":"https://<ingress-host>/billing/success","cancel_url":"https://<ingress-host>/billing/cancel"}'
# Expected: 200 with session_url
```

**Capture:** Whitelist source (file:line of `_validate_redirect_url()` and the whitelist constant/config).

---

## Phase 5 — Secret-leak Scan

```bash
# 5.1.1 Live secret keys
grep -rEn "sk_live_[A-Za-z0-9]+" /home/pwner/Git/blocksecops-* /home/pwner/Git/docs/ 2>/dev/null
# Expected: zero matches

# 5.1.2 Test secret keys outside fixtures
grep -rEn "sk_test_[A-Za-z0-9]+" /home/pwner/Git/blocksecops-* /home/pwner/Git/docs/ \
  | grep -v "tests/fixtures\|/test_\|EXAMPLE\|<placeholder>"
# Expected: zero matches in production code

# 5.1.3 Webhook secrets
grep -rEn "whsec_[A-Za-z0-9]+" /home/pwner/Git/blocksecops-* /home/pwner/Git/docs/ 2>/dev/null
# Expected: zero matches outside docs that describe the variable name

# 5.1.4 .env files committed (per feedback_no_env_commits.md)
find /home/pwner/Git/blocksecops-* -name ".env" -o -name ".env.*" | grep -v ".env.example"
# Expected: zero non-example matches

# 5.1.5 ExternalSecret manifests resolve Stripe keys from Vault (not inline values)
grep -rEn "STRIPE_API_KEY\|STRIPE_WEBHOOK_SECRET" /home/pwner/Git/blocksecops-*/k8s/ \
  | grep -E "value:|stringData:"
# Expected: zero matches (only ExternalSecret refs allowed)

# 5.1.6 Publishable key is publishable
grep -rEn "VITE_STRIPE_PUBLISHABLE_KEY" /home/pwner/Git/blocksecops-dashboard/
# Expected: only pk_* values where literal values appear (none for prod)
```

**Capture:** Each grep result; Vault path for each Stripe secret (from ExternalSecret manifests).

---

## Phase 6 — Tenant Isolation

```bash
# 6.1.1 Cross-user GET /billing/subscription
curl -i -H "Authorization: Bearer $USER_A_TOKEN" \
  "https://<ingress-host>/api/v1/billing/subscription"
# Note user A's subscription ID

curl -i -H "Authorization: Bearer $USER_B_TOKEN" \
  "https://<ingress-host>/api/v1/billing/subscription"
# Verify B's response does NOT contain A's subscription ID

# 6.1.2 Cross-user invoice fetch
curl -i -H "Authorization: Bearer $USER_A_TOKEN" \
  "https://<ingress-host>/api/v1/billing/invoices/<USER_B_INVOICE_ID>/pdf"
# Expected: 404 or 403

# 6.1.4 Cross-org billing details
curl -i -H "Authorization: Bearer $ORG_A_ADMIN" \
  "https://<ingress-host>/api/v1/orgs/<ORG_B_ID>/billing/details"
# Expected: 403

# 6.1.5 Service-account API key cross-org
curl -i -H "X-API-Key: $ORG_A_API_KEY" \
  "https://<ingress-host>/api/v1/orgs/<ORG_B_ID>/billing/subscription"
# Expected: 403
```

**Capture:** HTTP response bodies; query-layer scoping file:line.

---

## Phase 7 — Audit-log Review

```bash
# 7.1.1 Recent signature failures
psql "postgresql://blocksecops@<pg-host>/solidity_security?sslmode=prefer" -c "
  SELECT date_trunc('day', created_at) AS day, COUNT(*)
  FROM audit_logs
  WHERE alert_type = 'STRIPE_SIGNATURE_FAILURE'
    AND created_at > NOW() - INTERVAL '30 days'
  GROUP BY day
  ORDER BY day DESC;
"
# Expected: review for spikes

# 7.1.2 Source pattern
psql "..." -c "
  SELECT source_ip, user_agent, COUNT(*)
  FROM audit_logs
  WHERE alert_type = 'STRIPE_SIGNATURE_FAILURE'
    AND created_at > NOW() - INTERVAL '30 days'
  GROUP BY source_ip, user_agent
  ORDER BY COUNT(*) DESC
  LIMIT 20;
"
# Expected: explain top sources (Stripe retry from same IP block) or file finding

# 7.1.4 Stripe dashboard delivery log
# (Review in Stripe test+live dashboards; no CLI command)
echo "Manual review: https://dashboard.stripe.com/<env>/webhooks/<endpoint>/events"
```

**Capture:** Per-day failure counts; top failure sources; dashboard delivery review notes.

---

## Output

This pipeline does not produce its own report. Evidence captured here is consumed by `stripe-security-audit-playbook.md` and embedded in `docs/audit/YYYY-MM-DD-stripe-security-audit.md` per the security agent's output format.

---

## Failure Handling

If any command produces unexpected output (positive grep match, unexpected HTTP 200 on adversarial input, missing audit-log row):
1. Stop the pipeline.
2. Record the unexpected output as a finding (BSO-SEC-NNN).
3. Route to `stripe-security-audit-playbook.md` Failure Handling.

---

## Related Docs

- `docs/audit-playbooks/stripe-security-audit-playbook.md`
- `docs/audit-workflows/stripe-webhook-event-audit-workflow.md`
- `docs/.claude/agents/apogee-security-audit.md`
- `docs/standards/secure-coding.md`
- `docs/standards/secrets-management.md`
