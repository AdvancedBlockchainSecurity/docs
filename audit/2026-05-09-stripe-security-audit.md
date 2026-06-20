# Stripe Security Audit — 2026-05-09

**Auditor:** apogee-security-audit (Opus 4.7)
**Scope:** Stripe surface only — webhook handler (`stripe_webhook.py`), billing endpoints (`billing.py`), payment endpoints (`payments.py`), Stripe service (`stripe_service.py`), Stripe-related models (`UserModel`, `SubscriptionModel`, `PaymentTransactionModel`), Stripe secrets in Vault/ESO, Stripe-related audit logs (`TierSecurityAlert.STRIPE_SIGNATURE_FAILURE`).
**Excludes:** `blocksecops_com` (out of scope per memory), Cairo (out of scope per memory), live cluster execution (owner AFK, audit is static-source review only — not against running cluster).
**Severity scale:** Critical / High / Medium / Low / Info
**Standards referenced:** `docs/standards/api-endpoint-auth.md`, `docs/standards/secure-coding.md`, `docs/standards/secrets-management.md`, `docs/standards/encryption-standards.md`, `docs/standards/security-standards.md`, `docs/standards/tier-standards.md`, `docs/audit-playbooks/stripe-security-audit-playbook.md`, `docs/audit-pipelines/stripe-security-audit-pipeline.md`.

---

## ⛔ HALT CONDITION TRIGGERED — Phase 4 (Redirect Whitelist)

**Triggering finding:** **BSO-SEC-021 — Open redirect on `/billing/portal` and `/billing/checkout`** (HIGH).

Per `stripe-security-audit-playbook.md` "Failure Handling" rules and the operator's standing instructions, the audit halted at Phase 4 immediately after filing the HIGH finding. **Phases 5–7 were NOT formally executed** in this run, although static evidence accidentally gathered during scope reconnaissance is included below as informational notes (clearly labelled "not-formally-executed"). A re-run from Phase 1 is required after the halt-triggering finding is remediated.

> **BSO-SEC-021 RESOLVED — 2026-06-19.** Fixed in api-service v0.44.8. The private `_validate_redirect_url` helper was promoted to a public shared function in `src/infrastructure/security/url_validation.py` and applied to all three URL parameters in `billing.py` (`success_url`, `cancel_url`, `return_url`). See `docs/changelogs/API-SERVICE-V0.44.8-BSO-SEC-021-FIX-2026-06-19.md` for full details. BSO-SEC-022, BSO-SEC-023, and BSO-SEC-024 remain open. Audit re-run from Phase 1 is pending.

Two additional Phase-4-adjacent findings (BSO-SEC-022, BSO-SEC-023) and one Phase-2 Medium finding (BSO-SEC-024) discovered before the halt are also filed, since they were already reproduced from source.

---

## Executive Summary

The Stripe surface has a strong primary trust boundary — webhook signature verification using `stripe.Webhook.construct_event` is correctly implemented, fail-closed, and produces a `STRIPE_SIGNATURE_FAILURE` audit log on every failure (`stripe_webhook.py:870–901`). The credit-purchase pathway has solid defense-in-depth (server-side credit amount lookup, payment-intent-level idempotency, package whitelist). However, **two billing endpoints — `POST /api/v1/billing/portal` and `POST /api/v1/billing/checkout` — accept caller-supplied redirect URLs and pass them to Stripe with no whitelist validation**, recreating the exact class of bug that BSO-SEC-014 fixed in `POST /api/v1/payments/checkout/stripe`. A separate **tenant-isolation defense-in-depth gap** exists in `UserModel.stripe_customer_id` (no UNIQUE constraint at the DB layer, while `OrganizationModel.stripe_customer_id` correctly has one). Webhook event-level idempotency (on `event.id`) is also absent; only payment-intent-level idempotency exists for credit purchases.

---

## Findings

### BSO-SEC-021 — Open redirect on `/api/v1/billing/portal` and `/api/v1/billing/checkout`

- **Severity:** HIGH
- **CWE/OWASP:** CWE-601 (URL Redirection to Untrusted Site / "Open Redirect"), OWASP A01:2021 Broken Access Control / A03:2021 Injection (URL-context).
- **Location:**
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/billing.py:236–271` (`create_portal_session` — `return_url` query parameter, unvalidated)
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/billing.py:183–233` (`create_checkout_session` — `success_url` and `cancel_url` body fields, unvalidated)
- **Description:** Both endpoints accept user-supplied URL parameters and forward them directly to Stripe (`stripe.billing_portal.Session.create(return_url=...)` and `stripe.checkout.Session.create(success_url=..., cancel_url=...)`). Stripe will redirect the authenticated user's browser to whatever URL is provided after the portal/checkout flow completes. Neither endpoint applies the `_validate_redirect_url()` whitelist that `payments.py:375–407` uses for `/api/v1/payments/checkout/stripe` — the fix that BSO-SEC-014 introduced was never propagated to the parallel billing endpoints.
- **Impact:** An authenticated victim can be tricked (via a phishing email, malicious link, or CSRF-protected POST from an XSS chain) into invoking these endpoints with `return_url=https://attacker.example/...` or `success_url=https://attacker.example/...`. Stripe will host the legitimate billing/checkout page (so the URL bar shows `checkout.stripe.com` / `billing.stripe.com`), then redirect the victim post-flow to the attacker site — which can phish the victim's credentials, deliver malware, or reuse the freshly-issued session. The attack works even with strong CSRF/SameSite protections because the request body / query parameter is the attacker-controlled data, not the cookie. The `cancel_url` variant is even easier to exploit: the victim only needs to click "cancel" on the Stripe-hosted page.
- **Proof / Evidence:**
  ```python
  # billing.py:236–271 — create_portal_session
  @router.post("/portal", response_model=PortalResponse)
  async def create_portal_session(
      request: Request,
      return_url: Optional[str] = Query(None, description="URL to return to after portal"),
      current_user: UserModel = Depends(get_current_user),
      response: Response = None,
  ):
      ...
      base_url = settings.dashboard_base_url
      return_url = return_url or f"{base_url}/settings/billing"   # falls back to default

      try:
          portal_url = await stripe_service.create_customer_portal_session(
              user=current_user,
              return_url=return_url,        # <-- unvalidated, user-supplied
          )
  ```
  ```python
  # billing.py:183–233 — create_checkout_session
  base_url = settings.dashboard_base_url
  success_url = checkout_request.success_url or f"{base_url}/settings/billing?success=true"
  cancel_url = checkout_request.cancel_url or f"{base_url}/settings/billing?canceled=true"

  try:
      checkout_url = await stripe_service.create_checkout_session(
          user=current_user,
          plan_tier=checkout_request.plan_tier,
          billing_interval=checkout_request.billing_interval,
          db=db,
          success_url=success_url,        # <-- unvalidated, user-supplied
          cancel_url=cancel_url,          # <-- unvalidated, user-supplied
      )
  ```
  Compare with the BSO-SEC-014 fix in `payments.py:436–453`:
  ```python
  allowed_origins = list(settings.cors_origins)
  if settings.dashboard_base_url:
      allowed_origins.append(settings.dashboard_base_url)
  if not _validate_redirect_url(checkout_request.success_url, allowed_origins):
      raise HTTPException(status_code=400, detail="Invalid success_url: origin not allowed")
  if not _validate_redirect_url(checkout_request.cancel_url, allowed_origins):
      raise HTTPException(status_code=400, detail="Invalid cancel_url: origin not allowed")
  ```
- **Recommended Fix:**
  1. Promote `_validate_redirect_url()` from `payments.py:375` into a shared helper (e.g., `src/infrastructure/security/redirect_validator.py`) with a clear docstring.
  2. Apply the same `allowed_origins = settings.cors_origins + [settings.dashboard_base_url]` whitelist enforcement to all three URL parameters in `billing.py`:
     - `create_portal_session.return_url`
     - `create_checkout_session.success_url`
     - `create_checkout_session.cancel_url`
  3. Add a Pydantic `field_validator` on `CheckoutRequest.success_url` / `cancel_url` to reject `javascript:` / `data:` / `vbscript:` schemes at parse time (matching `StripeCheckoutRequest` in `presentation/schemas/payments.py:383–396`).
  4. Add regression tests under `tests/security/test_billing_redirect_whitelist.py` covering the same five cases the playbook Phase 4 enumerates (off-host, javascript:, userinfo, path traversal, whitelisted positive).
- **References:**
  - Prior fix that established this control: `BSO-SEC-014` (committed in `_validate_redirect_url` in `payments.py`).
  - `docs/standards/secure-coding.md` — A01/A03 redirect handling.
  - CWE-601: https://cwe.mitre.org/data/definitions/601.html

---

### BSO-SEC-022 — `UserModel.stripe_customer_id` lacks UNIQUE constraint (tenant-isolation defense-in-depth)

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-345 (Insufficient Verification of Data Authenticity), OWASP A04:2021 Insecure Design.
- **Location:** `blocksecops-api-service/src/infrastructure/database/models.py:174` (UserModel) vs `models.py:1511` (OrganizationModel — has `unique=True`).
- **Description:** `OrganizationModel.stripe_customer_id` is correctly declared `unique=True`, but `UserModel.stripe_customer_id` is **not unique** at the database level:
  ```python
  # UserModel — line 174 (NO unique=True)
  stripe_customer_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

  # OrganizationModel — line 1511 (correct)
  stripe_customer_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, unique=True)
  ```
  The webhook handler `get_user_by_stripe_customer()` (`stripe_webhook.py:181–189`) uses `scalar_one_or_none()`, which raises `MultipleResultsFound` if two users somehow share a customer ID. More importantly, application code creates Stripe customers with `metadata={"user_id": str(user.id)}` (`stripe_service.py:130–134`), but the DB has no defense if a future code path or admin-portal patch accidentally writes the same `stripe_customer_id` to two users.
- **Impact:** If two `UserModel` rows ever end up with the same `stripe_customer_id` (via a buggy migration, manual SQL fix, support tooling, or a data-import script), webhook dispatch becomes ambiguous and *the wrong user could be billed/credited/upgraded* on any subsequent webhook event for that customer. The race condition during customer creation in `get_or_create_customer` (`stripe_service.py:106–145`) is currently single-user-scoped, so this is defense-in-depth, not actively exploitable — but a single bug in any future code path that touches `UserModel.stripe_customer_id` becomes a silent cross-tenant data corruption.
- **Proof / Evidence:** Direct comparison of the two model definitions cited above. `get_user_by_stripe_customer` returns `scalar_one_or_none` which raises on duplicates rather than returning the wrong user, but this only converts a stealth issue into a noisy failure — it does not prevent the underlying data corruption.
- **Recommended Fix:**
  1. Add `unique=True` to `UserModel.stripe_customer_id` and write an Alembic migration that creates `UNIQUE INDEX users_stripe_customer_id_uniq ON users(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL` (partial unique index — preserves NULL semantics).
  2. Pre-migration: run `SELECT stripe_customer_id, COUNT(*) FROM users WHERE stripe_customer_id IS NOT NULL GROUP BY stripe_customer_id HAVING COUNT(*) > 1` to detect any existing duplicates and remediate before applying the constraint.
  3. Update `docs/database/SCHEMA.md` per `docs/standards/database-management.md` Rule 4.
- **References:** `docs/standards/database-management.md` (Schema docs Rule 4); `docs/standards/secure-coding.md` (data integrity).

---

### BSO-SEC-023 — Stripe webhook endpoint has no rate limit; signature failures cause unbounded `audit_logs` writes

- **Severity:** LOW
- **CWE/OWASP:** CWE-770 (Allocation of Resources Without Limits or Throttling), CWE-779 (Logging of Excessive Data), OWASP A04:2021.
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/stripe_webhook.py:843–921` — the `@router.post("")` handler has **no `@limiter.limit(...)`** decorator (every other write endpoint in the same service uses `@limiter.limit(get_rate_limit_string(...))`).
- **Description:** Each invalid-signature POST writes a `TierSecurityAlert.STRIPE_SIGNATURE_FAILURE` row to `audit_logs` (`tier_audit.py:236–306`) with severity = "CRITICAL". Without rate-limiting, an unauthenticated attacker who reaches the ingress can flood the endpoint and:
  - inflate the `audit_logs` table (PG growth, backup time, log-noise),
  - drown legitimate signature failures and security signals,
  - generate excessive CRITICAL log lines that may page on-call.
- **Impact:** Audit-log denial of service / on-call paging amplification. The webhook is reachable at `https://app.0xapogee.com/api/v1/webhooks/stripe` — discoverable, no auth required (signature is the gate). Stripe's published IP ranges are well-known, so an attacker cannot easily forge `X-Forwarded-For`; however IP-based rate-limiting at the application layer would still reduce log/DB pressure from any one source.
- **Proof / Evidence:** No `limiter.limit` decorator on the endpoint; signature-failure path executes `await log_security_event(...)` + `await db.commit()` on every failed request (`stripe_webhook.py:881–897`).
- **Recommended Fix:**
  1. Add a permissive rate limit suitable for legitimate Stripe traffic (Stripe sends bursts during catch-up retries — recommend `200/minute` per IP, but tune to observed legitimate volume).
  2. Or: rate-limit the audit-log *write* (not the HTTP response) — drop duplicate signature-failure log writes from the same source IP within a short window (e.g., 1 minute) using a Redis-backed counter, so the HTTP behaviour stays unchanged but log noise is bounded.
  3. Either approach: keep returning 400 to genuine signature failures so Stripe's own retry/back-off does the right thing.
- **References:** `docs/standards/secure-coding.md` (rate limiting); CWE-770.

---

### BSO-SEC-024 — No event-level idempotency for Stripe webhook subscription events

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-352 (related — replay handling), CWE-841 (Improper Enforcement of Behavioral Workflow), OWASP A04:2021 Insecure Design.
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/stripe_webhook.py:843–921` (`stripe_webhook` dispatcher) and event handlers `handle_subscription_updated` (line 597), `handle_subscription_deleted` (line 712), `handle_invoice_payment_succeeded` (line 756), `handle_invoice_payment_failed` (line 782).
- **Description:** The credit-purchase pathway (`_handle_credit_purchase_completed`) has **payment-intent-level** idempotency (line 484–494): it checks `PaymentTransactionModel.x402_payment_id == f"stripe:{payment_intent}"` before crediting. However, **subscription event handlers do not check `event.id`** — a Stripe retry of the same `customer.subscription.deleted` event will:
  - call `handle_tier_change` again (creates a duplicate audit-log row, fires a duplicate session-invalidation and notification — `tier_change_handler.py`)
  - re-set `subscription.status = CANCELED` and `subscription.canceled_at = utcnow()` (the second call clobbers the first canceled_at, losing the original timestamp)
  
  The pipeline at `docs/audit-pipelines/stripe-security-audit-pipeline.md:103–108` references a `stripe_event_log` table for idempotency lookup, but **that table does not exist in the codebase** — no Alembic migration creates it, no model defines it, no INSERT writes to it. The pipeline's SQL would error.
- **Impact:** A malicious actor cannot exploit this without compromising the `whsec_*` (signature verification still gates), so the threat model is **legitimate Stripe retry duplication**, not adversarial replay. Consequences:
  - Duplicate `tier_change_handler` audit rows distort security analytics / on-call dashboards
  - Incorrect `canceled_at` timestamps for billing reconciliation
  - Multiple session-invalidation / notification fan-outs per retry
- **Proof / Evidence:** Source-grep shows no `stripe_event_log`, no `event_id` lookup in any handler, and no Alembic migration creates such a table. Compare line 484 (`PaymentTransactionModel.x402_payment_id`) where the credit purchase path correctly de-duplicates.
- **Recommended Fix:**
  1. Create a `stripe_event_log` table (or `webhook_processed_events`) with `event_id VARCHAR(255) PRIMARY KEY`, `event_type VARCHAR(100)`, `processed_at TIMESTAMPTZ`, `received_at TIMESTAMPTZ`. Index on `(event_type, received_at)` for analytics.
  2. In `stripe_webhook` (after signature verification, before dispatch), `INSERT … ON CONFLICT (event_id) DO NOTHING RETURNING event_id`. If the INSERT returns 0 rows, the event is a replay → return `200 {"received": True, "duplicate": True}` and skip the handler.
  3. TTL the table (e.g., periodic cleanup of rows older than 30 days) — Stripe never retries beyond `~3 days` per their docs, so 30 days is comfortable.
  4. Update `docs/audit-pipelines/stripe-security-audit-pipeline.md` Phase 2 commands to reference the new table name once it exists.
- **References:** Stripe webhook idempotency guidance: https://stripe.com/docs/webhooks#handle-duplicate-events; OWASP A04 Insecure Design.

---

## Positive Observations

- **Webhook signature verification is fail-closed and audit-logged** (`stripe_webhook.py:861–901`). The `stripe.Webhook.construct_event(...)` call is wrapped in correct try/except for `ValueError` (malformed payload → 400) and `stripe.SignatureVerificationError` (bad signature → 400 + `STRIPE_SIGNATURE_FAILURE` security event with IP and User-Agent). Severity is correctly classified as CRITICAL in `tier_audit.py:312`.
- **Stripe secrets are correctly externalized.** No `STRIPE_API_KEY` / `STRIPE_WEBHOOK_SECRET` inline values in any Kubernetes manifest under `k8s/overlays/local/` or `k8s/overlays/gcp/`. Both ExternalSecrets reference Vault (`secret/local/api-service/stripe`) and GCP Secret Manager (`apogee-gcp-stripe-api-key`, `apogee-gcp-stripe-webhook-secret`) respectively.
- **Credit purchase has strong defense-in-depth** (`_handle_credit_purchase_completed`, `stripe_webhook.py:430–594`):
  - Server-side `credit_packages` lookup — never trusts `metadata.credits`
  - Payment-intent-level idempotency check (`x402_payment_id == f"stripe:{payment_intent}"`)
  - Package whitelist via `get_credit_packages()` — unknown package_id → security alert (BSO-SEC-015)
  - User existence verified before crediting
  - Audit trail via `PaymentTransactionModel` row with full session/intent context
- **Metadata whitelist enforced** in both webhook ingestion (`parse_subscription_metadata` — `ALLOWED_METADATA_KEYS = {"plan_tier", "billing_interval", "user_id", "payment_type", "package_id"}`) and outgoing checkout-session creation (`_sanitize_metadata_value`, `VALID_TIERS`, `VALID_BILLING_INTERVALS`).
- **Tier resolution prefers price_id over metadata** in `handle_subscription_updated` (`stripe_webhook.py:632–656`) — `get_tier_by_stripe_price_id()` is checked first, with metadata as fallback only.
- **Redirect whitelist correctly implemented for the credit-purchase pathway** (`payments.py:375–407`, `_validate_redirect_url`) — the BSO-SEC-014 fix is sound; the bug in this audit (BSO-SEC-021) is that the same fix wasn't propagated to the sibling `billing.py` endpoints.
- **No live Stripe secrets in Git.** `grep -rE "sk_live_[A-Za-z0-9]+"` against `/home/pwner/Git/blocksecops-*` and `/home/pwner/Git/docs/` returned only documentation strings (`sk_live_YOUR_KEY` placeholders) in `docs/playbooks/`. No `sk_test_*` secrets in production code outside test fixtures. No committed `.env` files containing Stripe values (per `git ls-files .env` and `git ls-files .env.local`).
- **Production validation in config.py:475** correctly enforces `stripe_webhook_secret` is set when `stripe_api_key` is set (BSO-SEC-012).
- **Admin endpoints use proper RBAC** — `admin/purchases.py` uses `require_admin_role("support_admin")` consistently across all 7 endpoints and calls `log_admin_action(...)` for every read, including search inputs and filters.

---

## Phase-by-phase Status

| Phase | Outcome | Evidence Path |
|-------|---------|---------------|
| 1 — Signature verification | PASS (static review) | `stripe_webhook.py:843–921`, `tier_audit.py:236–306,309–321` |
| 2 — Webhook idempotency | **FAIL** — BSO-SEC-024 (Medium) — event-id idempotency missing for subscription events; pipeline references nonexistent `stripe_event_log` table | `stripe_webhook.py:597–803`; absence verified via `grep -rn "stripe_event_log\|StripeEventLog\|webhook_event"` returning no Python source matches |
| 3 — Metadata whitelist | PASS — both ingestion (`parse_subscription_metadata`) and outgoing checkout-session creation (`_sanitize_metadata_value`) enforce whitelists; defense-in-depth note: `handle_checkout_session_completed` doesn't cross-check metadata.plan_tier against the actual price_id (Low, not filed — only exploitable post-`whsec_` compromise) | `stripe_webhook.py:204–245,295–331`; `stripe_service.py:43–61,224–245,547–600` |
| 4 — Redirect whitelist | **FAIL — HALT** — BSO-SEC-021 (High, **RESOLVED 2026-06-19 in v0.44.8**); BSO-SEC-022 (Medium, tenant isolation, found in same review pass, **still open**) | `billing.py:236–271,183–233` vs `payments.py:436–453,375–407`; `models.py:174` vs `models.py:1511` |
| 5 — Secret hygiene | **NOT FORMALLY EXECUTED** (halted at Phase 4). Reconnaissance evidence: `sk_live_*` grep clean (only doc placeholders in `docs/playbooks/`); `whsec_*` matches all benign (test fixtures + a separate non-Stripe-scope leak in `docs/database/solidity_security_20260127_162115_pre_phase2_migrations.sql`, see Out-of-scope below); `STRIPE_API_KEY`/`STRIPE_WEBHOOK_SECRET` are externalized via Vault/GCP-SM ExternalSecrets; `VITE_STRIPE_PUBLISHABLE_KEY` is `pk_test_*` (publishable, intentionally per playbook prereq). To be re-run from Phase 1 after halt remediation. | n/a |
| 6 — Tenant isolation | **NOT FORMALLY EXECUTED** (halted at Phase 4). One DB-layer issue (BSO-SEC-022) was found incidentally in Phase 4 model review. Live cross-tenant probes (6.1.1–6.1.5) require live cluster; deferred to re-run. | n/a |
| 7 — Audit log review | **NOT FORMALLY EXECUTED** (halted at Phase 4). Requires `kubectl exec postgresql-0 -- psql` and Stripe-dashboard delivery-log read; owner is AFK so no live cluster access available in this run regardless. | n/a |

---

## Out-of-Scope Issues Discovered (filed for follow-up, NOT counted in BSO-SEC-NNN sequence)

These were noticed during Stripe scope reconnaissance but belong to other features:

1. **Committed PostgreSQL dump contains real platform-webhook signing secrets.** `blocksecops-api-service/docs/database/solidity_security_20260127_162115_pre_phase2_migrations.sql` is a tracked file (commit `044dc83 — docs: Add Phase 2 documentation and unit tests`) that contains real `webhook_endpoints.secret` rows with `whsec_*` values (lines 22054–22055). These are the platform's *outgoing* webhook signing secrets (used to sign payloads sent FROM Apogee TO customer URLs like `https://webhook.site/test`) — they share the `whsec_` prefix with Stripe but are unrelated to the Stripe surface. Severity: HIGH for the Webhooks feature owner. **Recommendation:** rotate any `whsec_*` from those rows, BFG-or-`git filter-repo` the dump out of Git history, ensure DB dumps are excluded from Git via `.gitignore`. Filed out-of-scope; track under a separate finding ID for the webhooks/notifications surface.

2. **Dashboard `Dockerfile` hardcodes `VITE_*` ENV instead of using `ARG` build-args** (`blocksecops-dashboard/Dockerfile:12–16`). Per `docs/standards/docker-image-versioning.md` and `docs/standards/frontend-build-env.md`, all `VITE_*` values should be passed as `--build-arg` and assigned to `ENV` from `ARG`. Currently they're hardcoded. Values themselves are publishable (Stripe `pk_test_*`, Supabase anon JWT) so it's not a secret leak — it's a standards drift. Severity: Info. File under blocksecops-dashboard tech-debt.

3. **Public webhook health-check leaks configuration state.** `GET /api/v1/webhooks/stripe/health` (`stripe_webhook.py:924–934`) is unauthenticated and returns `{"webhook_configured": bool(settings.stripe_webhook_secret)}`. Reveals to any internet caller whether the endpoint will accept events. Severity: Info. Recommend either authenticating the health check or returning only `{"status": "healthy"}`.

---

## Follow-ups

- [x] **BSO-SEC-021 RESOLVED (2026-06-19)** — Fixed in api-service v0.44.8. See `docs/changelogs/API-SERVICE-V0.44.8-BSO-SEC-021-FIX-2026-06-19.md`.
- [ ] Owner: review BSO-SEC-022 — schedule the partial-unique-index migration on `users.stripe_customer_id` after pre-migration duplicate-detection query.
- [ ] Owner: review BSO-SEC-024 — schedule `stripe_event_log` table migration; once deployed, update `docs/audit-pipelines/stripe-security-audit-pipeline.md` Phase 2 SQL to match the actual table name (current pipeline references a table that doesn't exist).
- [ ] Owner: review BSO-SEC-023 — decide between HTTP rate-limit vs Redis-backed log-write deduplication.
- [ ] **Re-run the audit from Phase 1** after the HIGH finding (BSO-SEC-021) is remediated, per `stripe-security-audit-playbook.md` "Failure Handling".
- [ ] **Phases 5–7 must be formally executed** in the re-run, against the live local cluster: signature-failure injection via `stripe-cli`, replay tests (once `stripe_event_log` exists), tenant-isolation cross-user probes, and audit-log spike review.
- [ ] Out-of-scope follow-up: file separate finding for the platform-webhook secrets in the committed DB dump (see Out-of-Scope #1).
- [ ] Out-of-scope follow-up: file dashboard Dockerfile standards drift (see Out-of-Scope #2).
- [ ] Out-of-scope follow-up: tighten public `/webhooks/stripe/health` (see Out-of-Scope #3).
