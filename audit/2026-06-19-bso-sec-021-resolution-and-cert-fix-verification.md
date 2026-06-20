# BSO-SEC-021 Resolution + DNS-01 Cert Fix Verification — 2026-06-19

**Auditor:** apogee-security-audit (Opus 4.7, 1M context)
**Scope (focused, not full re-audit):**
- **Changeset A:** BSO-SEC-021 fix in `blocksecops-api-service` v0.44.8 — `validate_redirect_url()` helper in `url_validation.py`, applied to `success_url`/`cancel_url`/`return_url` in `billing.py`, deduplicated against `payments.py`.
- **Changeset B:** DNS-01 cert authorization in `blocksecops-gcp-infrastructure` branch `fix/cert-manager-dns-01-authorization` — two `google_certificate_manager_dns_authorization` resources + outputs, deployed to production with CNAMEs at Cloudflare.
- **General posture spot-check (sample, not exhaustive):** auth-dep usage on 5 endpoint files; secret-prefix grep across 4 repos; NetworkPolicy presence on 3 prod services; `.env` gitignore verification on 3 repos; api-service Dockerfile base-image pinning.
**Excludes:** Full Stripe re-audit (Phases 5–7 still owed per `2026-05-09-stripe-security-audit.md`); live cluster kubectl inspection (read-only static + DNS/TLS probes only); `blocksecops_com` (out of scope per memory `feedback_com_out_of_scope.md`); Cairo (out of scope per memory `feedback_no_cairo.md`).
**Severity scale:** Critical / High / Medium / Low / Info
**Standards referenced:** `docs/standards/api-endpoint-auth.md`, `docs/standards/secure-coding.md`, `docs/standards/encryption-standards.md`, `docs/standards/ingress-networking.md`, `docs/standards/networkpolicy-templates.md`, `docs/standards/secrets-management.md`, `docs/audit/2026-05-09-stripe-security-audit.md`.

---

## Executive Summary

**Changeset A (BSO-SEC-021) is CORRECT and EFFECTIVE for its stated scope.** The shared `validate_redirect_url(url, allowed_origins)` helper at `src/infrastructure/security/url_validation.py:270–289` blocks all five Phase-4 playbook attack classes (off-host, `javascript:`/`data:`/`vbscript:` schemes, userinfo bypass, malformed URLs, host-suffix bypass). It is applied to all three previously-unvalidated URL parameters in `billing.py` (`success_url`, `cancel_url`, `return_url`). The old private `_validate_redirect_url` in `payments.py` is cleanly removed and replaced with an import of the shared function — parity with the original BSO-SEC-014 control is preserved. **Two minor parity/edge-case issues are filed as new findings (BSO-SEC-025 LOW, BSO-SEC-026 INFO).** Neither is exploitable in the wild today; both are hardening recommendations. Open findings BSO-SEC-022/023/024 from the 2026-05-09 audit are confirmed NOT silently addressed in v0.44.8 — they remain open as expected.

**Changeset B (DNS-01 cert authorization) is CORRECT and DEPLOYED.** Both `app.0xapogee.com` and `admin.0xapogee.com` origin certificates are now issued by Google Trust Services (public CA, 2048-bit RSA, SHA-256-RSA, valid SANs, fresh issuance 2026-06-20 03:07 UTC). The `_acme-challenge` CNAMEs at Cloudflare correctly point to `*.authorize.certificatemanager.goog` and are necessarily DNS-only (CNAMEs to non-Cloudflare targets cannot be orange-clouded). Cert map and HTTPRoute routing are untouched by this change — no traffic-flow regression. **One pre-existing posture concern is filed (BSO-SEC-027 MEDIUM): `admin.0xapogee.com` is reachable via direct origin-IP + SNI manipulation from arbitrary internet IPs, despite `cloudflare_only = true` being set in Terraform.** This is unrelated to the cert fix but was surfaced by the cert-verification probe.

No HALT conditions are triggered. The BSO-SEC-021 fix may proceed as deployed. The follow-ups in the prior audit (BSO-SEC-022/023/024) remain owed, and a Phase-1-onward re-run of the Stripe audit is still required.

---

## Status Table

| Check | Outcome | Notes |
|-------|---------|-------|
| **A1.** `validate_redirect_url` rejects off-host origins | PASS | Tested with `https://evil.com/phish` → False |
| **A1.** Rejects `javascript:` / `data:` / `vbscript:` schemes (any case) | PASS | Explicit scheme check at line 279; lowercase normalized |
| **A1.** Rejects userinfo bypass (`https://allowed@evil.com`) | PASS | `urlparse` puts `evil.com` into `netloc`; comparison fails |
| **A1.** Rejects malformed URLs | PASS | `urlparse` returns empty scheme/netloc; comparison fails |
| **A1.** Rejects host-suffix bypass (`https://allowed.evil.com`) | PASS | Netloc string is `allowed.evil.com`, not `allowed`; mismatch |
| **A1.** Rejects trailing whitespace/control chars (`\n`, `\r`, `\t`) | **WARN — BSO-SEC-025** | Python `urlparse` silently strips `\n`/`\r`/`\t` per WHATWG; validation passes True for `https://allowed\n/path` while the raw URL still contains `\n`. Not exploitable against Stripe (Stripe re-validates), but is a CRLF-injection latent risk for any future caller. |
| **A2.** Applied to all three URL params in `billing.py` | PASS | `success_url` (line 223), `cancel_url` (line 228), `return_url` (line 282); all use same `allowed_origins = cors_origins + [dashboard_base_url]` allowlist |
| **A3.** `success_url=None` default falls back and validates | PASS | Fallback is `f"{dashboard_base_url}/settings/billing?success=true"` — built from same `dashboard_base_url` that's added to `allowed_origins`. Empirically tested. |
| **A4.** Empty `cors_origins` behavior | PASS (fail-closed) | If both `cors_origins` and `dashboard_base_url` are empty/missing, `allowed_origins` is empty and ALL URLs reject (return False). Production config defaults `dashboard_base_url` to `https://app.0xApogee.com`, so this can only happen via explicit misconfiguration. Fail-closed is correct. |
| **A5.** `parsed.netloc` port handling | **WARN — BSO-SEC-026** | `https://app.0xapogee.com:443/...` does NOT match `https://app.0xapogee.com` because Python `urlparse` leaves `:443` in `netloc` verbatim. Explicit default port is rejected when allowlist lacks the port. UX/correctness bug, not security. |
| **A6.** `_validate_redirect_url` removal in `payments.py` is clean | PASS | `grep -rn "_validate_redirect_url" /home/pwner/Git/blocksecops-api-service/` returns no matches. Import updated at `payments.py:19`. |
| **A7.** Parity with BSO-SEC-014 payments path | PASS | `payments.py:404–421` uses identical `allowed_origins` construction and call signature as `billing.py:218–232`. Both call sites identical. No regression. |
| **A8.** BSO-SEC-022/023/024 NOT silently addressed | PASS | Verified: `models.py:174` UserModel.stripe_customer_id still lacks `unique=True`; no Alembic migration for `stripe_event_log`; no `@limiter.limit` on `stripe_webhook` POST. All three correctly remain open. |
| **B1.** Cloudflare `_acme-challenge` CNAMEs present and DNS-only | PASS | `dig +short CNAME _acme-challenge.app.0xapogee.com` returns `e4c25f7f-159d-4954-93a3-52eb5e7328d7.14.authorize.certificatemanager.goog.`; `_acme-challenge.admin.0xapogee.com` returns `339691e1-3793-458a-9a00-b04e75e4f815.18.authorize.certificatemanager.goog.`. Both targets are non-Cloudflare hostnames, so they cannot be orange-clouded (proxying requires A/AAAA records). DNS-only enforcement is structural, not configurational. |
| **B2.** Origin TLS cert chains to public CA with correct SANs and ≥ 2048-bit key | PASS | Origin probe via `openssl s_client -connect 34.149.16.104:443 -servername app.0xapogee.com`: issuer `C=US, O=Google Trust Services, CN=WR3`, SAN `DNS:app.0xapogee.com`, public key 2048-bit RSA, SHA-256-RSA signature, validity 2026-06-20 → 2026-09-18. Chain: WR3 → GTS Root R1 → GlobalSign Root CA (cross-signed). Same shape for `admin.0xapogee.com`. Both certs fresh-issued post-DNS-01 deployment. |
| **B3.** No cert-map / HTTPRoute regression | PASS | Diff at `terraform/environments/gcp/main.tf` lines 608–665 only ADDS DNS-authorization resources and adds `dns_authorizations` to existing `managed{}` blocks. The `google_certificate_manager_certificate_map` and `_entry` resources (lines 667–695) and `k8s/overlays/gcp/ingress/httproute.yaml` are unchanged in this branch. |
| **B4.** `admin.0xapogee.com` no A record is benign | **WARN — BSO-SEC-027** | No A/AAAA record at Cloudflare for `admin.0xapogee.com` (confirmed via dig). However, the GCP origin LB at `34.149.16.104` serves the admin portal on SNI `admin.0xapogee.com` and returns HTTP 200 with the SPA bundle. Cloud Armor `cloudflare_only = true` is set in Terraform (`main.tf:245`) and an admin-portal `GCPBackendPolicy` references the WAF policy (`k8s/overlays/gcp/backend-policies/backend-policy.yaml:51–65`), but a curl from a non-Cloudflare IP (`136.36.116.105`, my origin) succeeds. Either the security policy is not attached at runtime, or its allow rule is overly broad. The admin portal SPA loads from any client that supplies the correct SNI. |
| **C1.** Spot-check `api-endpoint-auth.md` compliance on 5 endpoints | OBSERVATION | See "Posture Drift Observation" section below — many write endpoints still use `get_current_user` (JWT-only) rather than `require_auth_with_scope`. May be intentional for dashboard-only flows; not a definitive finding without endpoint-by-endpoint intent review. |
| **C2.** Hardcoded-secret grep on api-service, infra, dashboard, tool-integration | PASS | No `sk_live_*`, `sk_test_*`, `whsec_*`, `AKIA*`, `ghp_*`, or `glpat-*` patterns outside `docs/runbooks/DEPLOYMENT-RUNBOOK.md` (placeholder `sk_live_xxxxx` in a shell example, benign) and the pre-existing committed DB dump documented in the 2026-05-09 audit "Out-of-scope #1". |
| **C3.** NetworkPolicy presence on 3 random prod deployments | PASS | `blocksecops-notification` (base): default-deny + targeted ingress/egress + DNS + cross-namespace. `blocksecops-data-service` (base): same archetype. `blocksecops-admin-portal` (base): default-deny + Traefik ingress on 3000 + DNS + external HTTPS with private-CIDR excludes. All conform to `networkpolicy-templates.md` "internal HTTP service" archetype. |
| **C4.** `.env` files gitignored in all repos | PASS | `blocksecops-api-service/.gitignore`: `.env`; `blocksecops-dashboard/.gitignore`: `.env`, `.env.local`, `.env.development.local`, `.env.test.local`, `.env.production.local`; `blocksecops-gcp-infrastructure/.gitignore`: `.env`, `.env.local`, `.env.*.local`. `git ls-files` in all three returns only `.env.example`. No leaked `.env`. |
| **C5.** Api-service Dockerfile base image pinning | PASS | All four `FROM` directives in `blocksecops-api-service/Dockerfile` use pinned digests: `python:3.13-slim@sha256:f50f56f1471fc430b394ee75fc826be2d212e35d85ed1171ac79abbba485dce9` (builder, test, runtime stages all at the same digest). |

---

## Findings

### BSO-SEC-025 — `validate_redirect_url` accepts URLs with embedded `\n` / `\r` / `\t` (CRLF-injection latent risk)

- **Severity:** LOW
- **CWE/OWASP:** CWE-93 (Improper Neutralization of CRLF Sequences / "CRLF Injection"), CWE-79 (XSS — downstream context).
- **Location:** `blocksecops-api-service/src/infrastructure/security/url_validation.py:270–289` (`validate_redirect_url`).
- **Description:** Python 3.10+ `urllib.parse.urlparse` silently strips `\n`, `\r`, and `\t` characters from URLs per the WHATWG URL spec. As a result, a redirect URL like `https://app.0xapogee.com\n/path` parses to `scheme='https', netloc='app.0xapogee.com', path='/path'` — origin check passes True, **but the raw URL string with the embedded `\n` is then handed unchanged to `stripe.checkout.Session.create(success_url=...)` / `stripe.billing_portal.Session.create(return_url=...)`**.
- **Impact:** Not directly exploitable today: Stripe re-validates the URL server-side and rejects/normalizes control characters before storing or redirecting. The risk is **latent**: if Apogee ever adds an intermediate logging step, audit trail, header construction, or non-Stripe redirect target that consumes the raw user-supplied URL, the embedded CRLF becomes a header-injection / log-injection vector. This is exactly the same class of bug that motivated the upstream Python `urlparse` change (CVE-2023-24329) — fixing parsing didn't help anyone storing the raw input.
- **Proof / Evidence:**
  ```python
  from urllib.parse import urlparse
  p = urlparse('https://app.0xapogee.com\n/path')
  # p.scheme='https', p.netloc='app.0xapogee.com', p.path='/path'  ← \n silently stripped

  from src.infrastructure.security.url_validation import validate_redirect_url
  validate_redirect_url('https://app.0xapogee.com\n/path', ['https://app.0xapogee.com'])
  # Returns True  ← validator says "safe"

  # But the raw URL still contains \n when handed to Stripe.
  ```
- **Recommended Fix:** Add an explicit pre-parse rejection of control characters:
  ```python
  def validate_redirect_url(url: str, allowed_origins: list[str]) -> bool:
      try:
          # CWE-93: reject control chars (\n, \r, \t, \x00) before urlparse silently strips them
          if any(c in url for c in ('\n', '\r', '\t', '\x00')):
              return False
          parsed = urlparse(url)
          if parsed.scheme in ("javascript", "data", "vbscript"):
              return False
          # ... existing logic ...
  ```
  Add corresponding test cases in `tests/security/test_validate_redirect_url.py` covering each control character.
- **References:** CWE-93, CVE-2023-24329 (upstream urlparse parser change), `docs/standards/secure-coding.md` input-validation section. WHATWG URL spec §4.1 (URL parser leading/trailing C0 control + tab/LF stripping).

---

### BSO-SEC-026 — `validate_redirect_url` rejects explicit default ports in allowlist comparison

- **Severity:** INFO (parity / UX)
- **CWE/OWASP:** N/A (not a vulnerability; correctness issue with security-adjacent impact)
- **Location:** `blocksecops-api-service/src/infrastructure/security/url_validation.py:281–286` (`validate_redirect_url`).
- **Description:** The comparison uses `parsed.netloc` verbatim for both sides of the origin comparison. Python `urlparse` preserves the port string as-is: `urlparse('https://app.0xapogee.com:443/...').netloc == 'app.0xapogee.com:443'`. Since `settings.dashboard_base_url = 'https://app.0xApogee.com'` (no port), a legitimate caller who passes `success_url=https://app.0xapogee.com:443/settings/billing?success=true` is rejected with HTTP 400.
- **Impact:** Latent UX/integration bug. No security weakening (the bug fails closed, not open). Likely to surface when a CLI/SDK or unfamiliar third-party tool over-normalizes URLs to include the default port. The dashboard never sends `:443` explicitly today, so it has not surfaced.
- **Proof / Evidence:**
  ```python
  validate_redirect_url('https://app.0xapogee.com:443/settings/billing', ['https://app.0xapogee.com'])
  # Returns False  ← :443 in netloc breaks string comparison
  ```
- **Recommended Fix:** Normalize default ports before comparison:
  ```python
  def _normalize_origin(scheme: str, netloc: str) -> str:
      scheme = scheme.lower()
      host, _, port = netloc.partition(':')
      host = host.lower()
      if (scheme == 'https' and port in ('', '443')) or (scheme == 'http' and port in ('', '80')):
          return f"{scheme}://{host}"
      return f"{scheme}://{host}:{port}"

  url_origin = _normalize_origin(parsed.scheme, parsed.netloc)
  allowed_origin = _normalize_origin(allowed_parsed.scheme, allowed_parsed.netloc)
  if url_origin == allowed_origin:
      return True
  ```
- **References:** RFC 3986 §3.2.3 (Port — default ports are equivalent to omission). Same normalization is performed by browsers when computing Same-Origin Policy origin.

---

### BSO-SEC-027 — Admin portal reachable via direct origin-IP + SNI manipulation despite `cloudflare_only = true` Cloud Armor policy

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-693 (Protection Mechanism Failure), CWE-200 (Exposure of Sensitive Information), OWASP A05:2021 Security Misconfiguration.
- **Location:**
  - `blocksecops-gcp-infrastructure/terraform/environments/gcp/main.tf:245` (`cloudflare_only = true` passed to load-balancer module)
  - `blocksecops-gcp-infrastructure/terraform/modules/load-balancer/main.tf:80–171` (Cloud Armor policy definition, Cloudflare IP allowlist)
  - `blocksecops-gcp-infrastructure/k8s/overlays/gcp/backend-policies/backend-policy.yaml:51–65` (`admin-portal-policy` GCPBackendPolicy referencing `apogee-production-waf-policy`)
- **Description:** Cloud Armor is configured with `cloudflare_only = true`, which sets a default-deny(403) rule (priority 2147483647) and three allow rules (priorities 100/101/102) for Cloudflare's published IPv4 and IPv6 ranges. A `GCPBackendPolicy` named `admin-portal-policy` references `apogee-production-waf-policy` and targets the `admin-portal` Service in `admin-portal-prod` namespace. **However, a curl from a non-Cloudflare source IP (`136.36.116.105`) with `--resolve admin.0xapogee.com:443:34.149.16.104` succeeds with HTTP 200 and returns the admin portal SPA bundle**, when it should be blocked with HTTP 403 by the default-deny rule. The admin portal SPA contains build-baked Supabase keys (publishable anon JWT only, per dashboard pattern, not service-role), but exposing the bundle and pre-auth routes to arbitrary internet IPs widens the attack surface (DOM-based XSS, dependency CVEs in the JS bundle, fingerprinting of admin-portal version, brute-force against the Supabase login flow without Cloudflare rate-limiting).
- **Impact:** The Cloud Armor `cloudflare_only` allowlist is the platform's defense against direct-origin attacks bypassing Cloudflare's WAF, rate-limiting, and bot management. If it's not actually enforced, any future authentication or authorization flaw in the admin portal (or its dependency chain) is exploitable from any internet IP without Cloudflare visibility. Discovered incidentally during BSO-SEC-021/cert verification — was NOT introduced by either changeset. Likely pre-dates both.
- **Proof / Evidence:**
  ```bash
  # My source IP (not in Cloudflare ranges)
  $ curl -s ifconfig.me
  136.36.116.105

  # Direct origin IP with admin SNI succeeds
  $ curl -ks --resolve admin.0xapogee.com:443:34.149.16.104 \
      -o /dev/null -w "HTTP %{http_code}\n" --max-time 10 \
      https://admin.0xapogee.com/
  HTTP 200

  # Response body confirms admin portal SPA bundle returned:
  # <title>Apogee Admin</title>
  # <script type="module" crossorigin src="/assets/index-DUIBgIXS.js"></script>
  ```
  No Cloudflare proxy in the request path (custom DNS resolution); my IP is not in any of the allow-rule CIDRs (e.g., 173.245.48.0/20, 104.16.0.0/13, 172.64.0.0/13, etc. — see `terraform/modules/load-balancer/main.tf:111–122,137–143`).
- **Recommended Fix:**
  1. Verify the GCPBackendPolicy is actually attached at runtime: `kubectl describe gcpbackendpolicy admin-portal-policy -n admin-portal-prod` and confirm `Status.Conditions[Type=Accepted].Status=True` and inspect `apogee-production-waf-policy` in GCP console for backend-service attachment.
  2. If the policy is attached and STILL failing to block, file a separate investigation into Cloud Armor rule evaluation order — possible interaction with default-allow on health-check IPs or with rate-limit-only rules.
  3. Consider adding a Cloudflare-side strict-transport-mode authentication header (e.g., Cloudflare's `cf-connecting-ip` presence or a shared origin-secret header validated at the Gateway) as defense-in-depth in case the IP allowlist drifts.
  4. Confirm same behavior for `app.0xapogee.com` (API + dashboard) — the same Cloud Armor policy is referenced; if admin-portal is reachable, dashboard probably is too.
  5. Re-test after fix from a confirmed non-Cloudflare IP and assert HTTP 403.
- **References:** `docs/standards/ingress-networking.md` (Cloud Armor + Cloudflare layering), `docs/standards/security-standards.md`, Cloud Armor documentation (https://cloud.google.com/armor/docs/security-policy-overview).

---

## Posture Drift Observation (not a finding)

**Many write endpoints use `get_current_user` (JWT-only) instead of `require_auth_with_scope` per `api-endpoint-auth.md`.**

Tally across `src/presentation/api/v1/endpoints/`:

| Auth dep | Method count |
|----------|-------------|
| `get_current_user` (JWT-only) | 33 DELETE, 22 PATCH, 87 POST, 8 PUT (= **150 write endpoints**) |
| `require_auth_with_scope` | 7 DELETE, 3 PATCH, 11 POST, 3 PUT (= 24 write endpoints) |
| `get_current_user_or_api_key` | 1 POST |
| `require_admin_role` | 2 POST |
| (no auth dep matched in scan window) | 27 POST |

Per `docs/standards/api-endpoint-auth.md:21`, `require_auth_with_scope` is the prescribed pattern for write endpoints that should accept BOTH dashboard (JWT) AND CLI/SDK (API key) callers. Using `get_current_user` is legitimate only for dashboard-only flows. Without per-endpoint intent review, I cannot say which of the 150 are correctly dashboard-only and which are missed migrations. **This is not a definitive finding** — it's a posture observation to scope a future audit. Suggested follow-up: a CSV review where each `get_current_user`-only write endpoint is annotated `intentional-dashboard-only` vs `should-be-dual-auth`, then file each "should-be" as a tracked migration. The billing endpoints reviewed in Changeset A all use `get_current_user`, which is plausibly intentional (you shouldn't cancel a subscription via API key), but warrants explicit confirmation.

The 27 "no auth dep matched" POSTs are an artifact of my scan window — most are health/public endpoints (`/health`, `/plans`, `/auth/login`, `/auth/register`, webhook receivers with signature gating). Worth a follow-up sweep to confirm none should be authenticated.

---

## Positive Observations

- **`validate_redirect_url` is correctly defense-in-depth.** It rejects `javascript:`/`data:`/`vbscript:` schemes case-insensitively at line 279, BEFORE the origin check, which would otherwise return False for those schemes anyway (no scheme+host match). This belt-and-suspenders matches the recommendation in the original BSO-SEC-021 finding.
- **Case-insensitive origin comparison handles the `0xApogee.com` vs `0xapogee.com` mismatch.** `config.py:111,154` ships defaults with mixed-case `0xApogee.com`, while DNS / Cloudflare / certs use lowercase `0xapogee.com`. The `.lower()` calls at lines 285 of `url_validation.py` prevent a class of self-inflicted lockout bugs.
- **Fail-closed behavior throughout the validator.** Empty `allowed_origins` list rejects all URLs; exceptions in `urlparse` return False; missing scheme/host returns False. There is no code path where validation silently passes a malformed input.
- **`payments.py` refactor is genuinely DRY.** The private `_validate_redirect_url` is fully removed; payments.py now imports the shared function. No duplicate implementation, no drift risk.
- **DNS-01 cert fix is the correct architectural choice.** Per `docs/standards/ingress-networking.md`, HTTP-01 challenges from public CAs cannot reach a Cloudflare-proxied origin (Cloudflare terminates TLS and won't forward `/.well-known/acme-challenge/`). DNS-01 with CNAMEs to `*.authorize.certificatemanager.goog` is the documented pattern and is now in place for both production hostnames. The Terraform diff is minimal and additive (no removal of existing certs or map entries).
- **Cert chain trust path is sound.** WR3 → GTS Root R1 → GlobalSign Root CA cross-signature provides broad client trust without relying on the newer-only GTS-only chain.
- **Cloudflare `_acme-challenge` CNAMEs are structurally DNS-only.** Because they target `*.authorize.certificatemanager.goog` (not Cloudflare-hosted records), Cloudflare cannot proxy them even if a future operator mistakenly toggled them. The "gray cloud" requirement enforces itself.
- **All four api-service Dockerfile FROM directives use pinned digests** (`@sha256:f50f56f1...`) — a single tagged digest reused across builder/test/runtime stages. Matches `docker-image-versioning.md` immutable-tag policy.
- **NetworkPolicies on the three sampled production deployments** (notification, data-service, admin-portal) all follow the `networkpolicy-templates.md` "internal HTTP service" archetype: default-deny baseline + targeted ingress + DNS egress + cross-namespace egress to dependencies. Admin-portal correctly excludes private CIDRs from its external-HTTPS egress rule.
- **`.env` files are gitignored across all three repos audited.** `git ls-files` in api-service, dashboard, and gcp-infrastructure returns only `.env.example`. Respects memory rule `feedback_no_env_commits.md`.
- **No new live-secret prefixes found in code.** Grep across api-service, dashboard, tool-integration, and gcp-infrastructure for `sk_live_`, `sk_test_*` (with high-entropy suffix), `whsec_*`, `AKIA*`, `ghp_*`, `glpat-*` returned only one hit — a placeholder `sk_live_xxxxx` inside a shell-example in `gcp-infrastructure/docs/runbooks/DEPLOYMENT-RUNBOOK.md` (benign documentation). The pre-existing committed DB-dump leak from the 2026-05-09 audit "Out-of-scope #1" is unchanged.

---

## Source Fixes Applied During This Audit

**None.** This audit is verification-only. No source files were modified. All findings are filed as recommendations for owner approval.

If BSO-SEC-025 (control-char stripping) or BSO-SEC-026 (default-port normalization) are accepted, the recommended one-line additions can be made to `src/infrastructure/security/url_validation.py:270–289` in a follow-up patch release (suggest v0.44.8).

---

## Follow-ups

- [ ] Owner: triage **BSO-SEC-025** (LOW) — decide whether to add control-character pre-parse rejection to `validate_redirect_url`. Not exploitable today, but a one-line fix with regression test prevents an entire class of latent issues.
- [ ] Owner: triage **BSO-SEC-026** (INFO) — decide whether to normalize default ports in origin comparison. UX issue only; defer or fix as preferred.
- [ ] Owner: triage **BSO-SEC-027** (MEDIUM) — verify Cloud Armor `cloudflare_only` enforcement on `admin.0xapogee.com` AND `app.0xapogee.com`. If broken in production, this is a higher-priority remediation than the v0.44.8 patch. Recommend `kubectl describe gcpbackendpolicy` + GCP console inspection of `apogee-production-waf-policy` backend attachments before code change. **Re-test from a confirmed non-Cloudflare IP** after any fix.
- [ ] Owner: add `admin.0xapogee.com` A record at Cloudflare (orange cloud, pointing to the same LB IP `34.149.16.104`) so the admin portal IS reachable via the Cloudflare proxy chain. Today it's only reachable via SNI-spoofed direct origin access — which is paradoxically MORE exposed than putting it behind Cloudflare. This is a recommendation, not a finding.
- [ ] **Carry forward from 2026-05-09 Stripe audit (still owed):**
  - [ ] BSO-SEC-022 — `UserModel.stripe_customer_id` partial-unique-index migration.
  - [ ] BSO-SEC-023 — Stripe webhook rate-limit or Redis-backed log-write dedup.
  - [ ] BSO-SEC-024 — `stripe_event_log` table for event-id idempotency.
  - [ ] Re-run Stripe audit from Phase 1 per playbook failure-handling (Phases 5–7 never formally executed).
- [ ] **Posture sweep (medium effort):** Annotate every `get_current_user`-only write endpoint as `intentional-dashboard-only` or `should-be-dual-auth`. 150 endpoints. Per `api-endpoint-auth.md`, write endpoints SHOULD accept dual-auth unless there's a deliberate reason not to. Bill the work as Tech Debt, schedule after customer-facing items (per memory `feedback_no_scope_creep_pre_customer.md`).
- [ ] **Posture sweep (small effort):** Confirm the 27 POST endpoints my scan didn't match-to-an-auth-dep are intentionally public (health/auth/webhook). Should be a 30-minute grep.

---

## Out-of-Scope Issues Noted (filed under TaskDocs-BlockSecOps separately, not BSO-SEC-NNN)

1. **`admin.0xapogee.com` has no Cloudflare A record while the GCP infra serves it.** Not a finding because no traffic flows externally via DNS today, but creates a "the door is unlocked, just hidden" posture. Filing as infra-tech-debt to either (a) add the A record + proxy, or (b) tear down the admin HTTPRoute / cert until the admin portal is intentionally launched.
2. **`config.py` defaults contain mixed-case `0xApogee.com`** (`cors_origins`, `dashboard_base_url`, `allowed_hosts`) while real production is lowercase `0xapogee.com`. Defense-in-depth: defaults should match production exactly to avoid relying on case-insensitive comparisons in every consumer. Cosmetic.

---

**End of report.** No HALT triggered. Changesets A and B are approved for the deployed state. Three new findings (BSO-SEC-025/026/027) are filed for owner triage.
