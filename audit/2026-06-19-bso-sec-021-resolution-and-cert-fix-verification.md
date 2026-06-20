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

---

# Follow-Up Audit — 2026-06-20 — Five Uncommitted Changesets (A–E)

**Auditor:** apogee-security-audit (Opus 4.7)
**Scope (light pass, security only):**
- **Changeset A:** `blocksecops-admin-portal/src/test/setup.ts` — Supabase `vi.stubEnv` for vitest
- **Changeset B:** `blocksecops-contract-parser/.env.example` — Cairo env-key removal
- **Changeset C:** `blocksecops-docs/` — 12 modified files (Cairo cleanup + scanner-count + occurrence-badge docs)
- **Changeset D:** `blocksecops-orchestration/` — v0.13.0 → v0.13.1, `poll-scan-queue` Beat schedule entry removed
- **Changeset E:** `blocksecops-dashboard/` — Migration 091 frontend (OccurrenceBadge + `with_artifacts` upload + ScannerSelector warning + 3 test files)
**Severity scale:** Critical / High / Medium / Low / Info
**Standards referenced:** `docs/standards/api-endpoint-auth.md`, `docs/standards/secure-coding.md`, memory `feedback_no_env_commits.md`, `feedback_no_cairo.md`, `feedback_no_auto_scan_on_sync.md`.

## Follow-Up Status Table

| Check | Outcome | Notes |
|-------|---------|-------|
| **A.1** Test setup file is test-only (not imported by app code) | PASS | `setupFiles: ['./src/test/setup.ts']` only referenced in `vite.config.ts` test block. Production build (`build:` block) does NOT include test directory. |
| **A.2** Stub values are obviously-fake placeholders, not real secrets | PASS | URL is `https://test.supabase.co`; key is `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test-anon-key` (truncated JWT shape, no signature payload). No risk of accidental production credential commit. |
| **A.3** No `.env` file accompanies the change | PASS | Only `src/test/setup.ts` is in the working tree. Memory `feedback_no_env_commits.md` upheld. |
| **B.1** `.env.example` removed Cairo vars; no Rust code references them | PASS | `grep -rn "CAIRO_\|SUPPORTED_EXTENSIONS" src/` returns zero hits. Rust code does not load these env vars, so removal cannot crash the parser at runtime. |
| **B.2** SUPPORTED_EXTENSIONS removal does not break runtime dispatcher | PASS | No Rust code reads `SUPPORTED_EXTENSIONS` from env. Variable was documentation-only in `.env.example`. |
| **B.3** Memory `feedback_no_cairo.md` upheld | PASS | All active Cairo config keys removed from `.env.example`. Comment retained as deprecation marker. |
| **C.1** Cairo removed from all user-facing public docs | PASS-with-WARN | 12 of 14 references removed cleanly. **Two historical references remain** in `resources/release-notes/2025/december.md:164,195` ("Cairo support in development" and "Move and Cairo language support"). These are December-2025 release notes that describe the platform state at that time; historically accurate. See follow-up note below. |
| **C.2** New scanner count (13) is verifiable against deployed ConfigMap | **FAIL — BSO-SEC-028** | Docs claim **13 scanners** in `platform/admin/scanner-management.md:33`, but `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` ships **17 distinct `SCANNER_IMAGE_*` entries**. Worse, the docs list and the ConfigMap list don't even overlap consistently. See finding below. |
| **C.3** Docs match dashboard E (OccurrenceBadge) | PASS | `platform/findings/reading-findings.md` + `platform/findings/vulnerability-overview.md` + `platform/scanning/re-scanning.md` correctly document the badge labels and tooltip behavior that Changeset E implements. |
| **D.1** Removing `poll-scan-queue` Beat task does not silently break the canonical scan path | PASS | api-service POST `/scans/batch` (`src/presentation/api/v1/endpoints/scans.py:1083-1170`) directly dispatches to tool-integration via `service_url_tool_integration` after the DB row is committed. Does not rely on Celery Beat. Production deployment is already running this image and working — confirmed by user. |
| **D.2** `poll_scan_queue` callable still exists but is now dead code | INFO (cleanup) | `src/blocksecops_orchestration/tasks/scan_tasks_sync.py:33-111` is no longer scheduled and no other code path calls it. It remains a registered Celery task (importable, dispatchable by name) so external triggers theoretically still work, but no caller in this monorepo invokes it. Recommend removing in a follow-up patch or leaving with a `# DEPRECATED` comment. |
| **D.3** Stale comment at api-service `scans.py:84` says "Celery Beat will pick this up" | **WARN — BSO-SEC-029** | Misleading comment in production code. Same stale-comment pattern at `blocksecops-orchestration/src/blocksecops_orchestration/api/routes/scans.py:59,84` (`Celery Beat will poll the database`). Not a security vulnerability but creates a debugging hazard. |
| **D.4** Admin retry endpoint (`scan_monitoring.py:285-329`) re-dispatches retried scans | **WARN — BSO-SEC-030** | The admin retry endpoint only resets `scan.status = "queued"` and commits; it does **not** re-dispatch to tool-integration. Pre-changeset-D, the orchestration `poll_scan_queue` Celery beat would have picked these up. Post-changeset-D, **manually-retried scans will sit in "queued" until `check_stale_scans` marks them failed**. Functional bug, not a security issue, but the admin-retry feature is now silently broken. |
| **D.5** Orchestration POST `/scans` endpoint orphaned | INFO | `blocksecops-orchestration/src/blocksecops_orchestration/api/routes/scans.py:46-105` is guarded by `verify_internal_service` and creates `status="queued"` rows. No caller in the monorepo invokes it (`grep` returns zero callers across api-service, dashboard, tool-integration, CLI). With `poll_scan_queue` removed, any new caller would create orphaned-then-failed scans. Safe today; latent risk if reintroduced. |
| **D.6** Version bump is consistent across pyproject.toml and 5 kustomize overlays | PASS | `pyproject.toml` and all 5 kustomization.yaml files moved 0.13.0 → 0.13.1 in lockstep. `app.kubernetes.io/version` labels also synced per `docker-image-versioning.md`. |
| **E.1** OccurrenceBadge.tsx has no XSS sinks | PASS | No `dangerouslySetInnerHTML`, no `eval`, no `innerHTML`. All user-controlled strings (`firstSeen`/`lastSeen`/`label`) interpolate as React text children or `title`/`aria-label` attributes — React auto-escapes. SVG icon is static literal markup. |
| **E.2** API surface additions are read-only or write-with-existing-auth | PASS | `include_duplicates` is a GET query param on existing `listVulnerabilitiesByScan` — read-only and the server (`scans.py:2158,2264`) honors it. `with_artifacts` is a new form field on the EXISTING `POST /upload` endpoint, which already uses `require_auth_with_scope(["contracts:write"])` (`upload.py:189`) per `api-endpoint-auth.md`. No new endpoints created. |
| **E.3** No new external network calls / new origins / new secrets | PASS | All new calls hit existing `apiClient` (api-service base URL). No new env vars, no new fetch destinations, no allowlist changes. |
| **E.4** Scope/tier expansion check on contracts API client + ScannerSelector | PASS | `uploadContractFile` gained a 4th positional arg defaulting to `false` — existing callers unchanged. ScannerSelector gains a soft-warning UI only; no tier-check bypass, no scope expansion. The `FUZZER_LIKE_SCANNERS_REQUIRING_ARTIFACTS` set is purely cosmetic (it drives a warning, not enforcement — enforcement is server-side). |
| **E.5** Three new test files do not commit secrets or hit real services | PASS | Tests are component-level (Vitest + Testing Library), mocked. No `fetch` to real URLs, no real Supabase keys, no `.env` reads. |
| **E.6** Dashboard changeset scope matches description | PARTIAL — see note | **The user's description undercounted the change.** Described as "OccurrenceBadge + field additions", but actually delivers full Migration 091 dashboard frontend (artifact-aware upload modal + fuzzer warning + 3 test files). Server-side support already exists (`upload.py:176,238,402`, `scans.py:2158,2264`), so this is the dashboard side of a feature whose backend is already deployed. Scope mismatch worth flagging but not a security issue. |

---

## Follow-Up Findings

### BSO-SEC-028 — Scanner count / inventory drift between docs and deployed ConfigMap

- **Severity:** LOW (documentation/security-posture; not exploitable)
- **CWE/OWASP:** CWE-1059 (Insufficient Technical Documentation), OWASP A05:2021 Security Misconfiguration (information mismatch class)
- **Location:**
  - `blocksecops-docs/platform/admin/scanner-management.md:33` ("13 security scanners")
  - `blocksecops-docs/billing/pricing-tiers.md:42,73,115` ("All 25+ scanners")
  - `blocksecops-docs/support/faq/README.md:28` ("Solidity (full support, 11+ scanners)")
  - `blocksecops-docs/platform/intelligence/deduplication.md:13` ("Without deduplication, running 17 scanners")
  - `blocksecops-docs/README.md:104-106` ("Solidity 12 scanners / Vyper 2 scanners / Rust 4 scanners" = 18)
  - `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` — **17 `SCANNER_IMAGE_*` entries** deployed
- **Description:** The deployed ConfigMap ships 17 scanner images: slither, aderyn, semgrep, solhint, vyper, halmos, echidna, medusa, moccasin, wake, soliditydefend, mythril, sol-azy, sec3-xray, trident, cargo-fuzz-solana, rustdefend. The user-facing scanner-management doc lists only 13, omitting wake, moccasin, sol-azy, sec3-xray, trident, cargo-fuzz-solana, rustdefend AND including SolidityBOM, Rustle, Cargo Audit which are not in the ConfigMap. Marketing/billing copy says "25+ scanners" everywhere. **None of these four numbers (13, 17, 25+, sum-by-language=18) agree.**
- **Impact:** Customer confusion about what they're paying for. More importantly: if a customer files a support ticket "Wake didn't run", support staff reading the published scanner list will say "Wake isn't supported" when in fact it's deployed. This is the bug that motivated `docs/standards/secure-coding.md` documentation-truthfulness rule.
- **Proof / Evidence:**
  ```
  ConfigMap (deployed, 17): slither, aderyn, semgrep, solhint, vyper, halmos, echidna, medusa,
                            moccasin, wake, soliditydefend, mythril, sol-azy, sec3-xray, trident,
                            cargo-fuzz-solana, rustdefend
  scanner-management.md (13): SolidityDefend, Slither, Aderyn, Mythril, Semgrep, Solhint,
                               Echidna, Medusa, Halmos, SolidityBOM, Vyper Analyzer, Rustle,
                               Cargo Audit
  Mismatches:
    - Docs claim but ConfigMap missing: SolidityBOM, Rustle, Cargo Audit
    - ConfigMap has but docs omit: wake, moccasin, sol-azy, sec3-xray, trident,
                                   cargo-fuzz-solana, rustdefend
  ```
- **Recommended Fix:**
  1. Treat the ConfigMap as source-of-truth (it's what runs).
  2. Reconcile `platform/admin/scanner-management.md` to list exactly the 17 deployed scanners with their languages and types.
  3. Decide whether SolidityBOM/Rustle/Cargo Audit are: (a) production scanners that need deployment, (b) planned scanners that need a "Coming Soon" row, or (c) historical scanners that should be removed from docs.
  4. Settle the headline number: pick one ("17 scanners" or "25+ when counting detector variants") and use it consistently across `README.md`, `pricing-tiers.md`, `x402-credits.md`, `support/faq/`.
  5. The bumped 14→13 in this changeset is therefore **moving in the wrong direction** — Cairo was never in the ConfigMap to begin with, so removing it from the docs is correct, but the underlying number should be 17 not 13.
- **References:** `docs/standards/secure-coding.md` (documentation truthfulness), feedback memory `feedback_verify_against_standards.md` (read source-of-truth files before proposing fixes), prior audit posture-drift observation in this same file.

---

### BSO-SEC-029 — Stale "Celery Beat will pick this up" comments at scan-creation sites

- **Severity:** INFO (debugging hazard, not a vulnerability)
- **CWE/OWASP:** CWE-1059 (Insufficient Technical Documentation)
- **Location:**
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:84` — "Celery Beat will pick this up via poll_scan_queue task"
  - `blocksecops-orchestration/src/blocksecops_orchestration/api/routes/scans.py:59,84` — "Celery Beat will poll the database and dispatch to workers for execution"
- **Description:** Three inline comments still describe the removed `poll_scan_queue` Beat-driven dispatch path. With Changeset D, scans are created with `status="queued"` and immediately dispatched via direct HTTP to tool-integration (api-service path) or are orphaned (orchestration path).
- **Impact:** A future engineer debugging a "scan stuck in queued" issue will follow the comment trail to a Celery task that's no longer scheduled, wasting time. Higher risk: someone may "fix" the issue by re-enabling the Beat task without realizing the K8s Job path now handles dispatch — reintroducing the dual-path race that motivated Changeset D.
- **Proof / Evidence:** see Location.
- **Recommended Fix:** Update the three comments to describe the new dispatch path. Example for `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:84`:
  ```python
  # Scan dispatch: this endpoint commits status="queued", then
  # immediately POSTs to tool-integration which creates a K8s Job
  # that transitions the scan to "running". The previous
  # poll_scan_queue Celery Beat path was removed in orchestration
  # v0.13.1 to eliminate dual-path racing.
  ```
- **References:** `docs/standards/core-development-rules.md` Rule 1 (codebase-first — code comments are part of the codebase).

---

### BSO-SEC-030 — Admin scan-retry endpoint silently broken by `poll_scan_queue` removal

- **Severity:** MEDIUM (operational/functional regression, not a direct vulnerability — but blocks an admin recovery path that may be needed during incidents)
- **CWE/OWASP:** CWE-440 (Expected Behavior Violation), OWASP A05:2021 Security Misconfiguration
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/admin/scan_monitoring.py:255-329` (`retry_scan` admin endpoint)
- **Description:** The admin retry endpoint resets a stuck scan's status to `"queued"` and commits, returning HTTP 200 with message "Scan has been requeued for retry". Pre-changeset-D, the orchestration `poll_scan_queue` Celery Beat would pick up the requeued scan within `scan_poll_interval` seconds and dispatch it. Post-changeset-D, with `poll_scan_queue` removed from the Beat schedule:
  1. The retried scan sits in `"queued"` state with no dispatcher.
  2. After `scan_stale_timeout` seconds, `check_stale_scans` (still scheduled) finds the queued-too-long row.
  3. Because `was_queued=True`, the scan is marked `"failed"` with reason `"Scan stuck in queued state — never picked up by worker"` (see `scan_tasks_sync.py:212-228`).
  4. The admin gets no error feedback; they see "requeued" then later "failed" with a generic message.
- **Impact:** An admin trying to recover a stuck scan during an incident (e.g., scanner Job evicted by Spot VM preemption) will retry, see success, then later find the scan dead-failed with no indication that the retry mechanism itself is broken. This delays incident response. Not a security boundary violation, but degrades incident-recovery capability. The user's note acknowledges the K8s Job dispatch path is the new canonical path; the admin retry endpoint was not updated to use it.
- **Proof / Evidence:**
  ```python
  # scan_monitoring.py:291-300 — only resets status, no dispatch:
  previous_status = scan.status
  scan.status = "queued"
  scan.retry_count = (scan.retry_count or 0) + 1
  # ... other field resets ...
  await db.commit()
  # No call to tool-integration to actually re-dispatch.
  ```
  And in `scan_tasks_sync.py:212-228` (still scheduled every 30s):
  ```python
  else:  # was_queued = True
      reason = "Scan stuck in queued state — never picked up by worker"
      scan.status = "failed"
      # ...
  ```
- **Recommended Fix:** Two viable approaches:
  1. **Preferred:** Update `retry_scan` to additionally POST to `service_url_tool_integration` after the commit, mirroring the dispatch loop at `scans.py:1155-1170`. Refactor that dispatch loop into a helper (`_dispatch_scan_to_tool_integration(scan_id, contract, scanner_ids)`) and call it from both batch-create and admin-retry.
  2. **Alternative:** Keep a thin "manual re-dispatch only" Celery task that the admin retry endpoint enqueues directly (not Beat-driven), so the dispatch path is owned by Celery but only fired on explicit admin action.
  Add a regression test in `tests/unit/admin/test_scan_monitoring.py` that asserts the tool-integration mock receives a POST after `/scans/{id}/retry`.
- **References:** Changeset-D removal context, feedback memory `feedback_no_unilateral_scope_exclusion.md` (changes to dispatch path should consider all callers).

---

## Follow-Up Positive Observations

- **Changeset A** is a textbook test-only env stub: gated by `setupFiles` in vite.config.ts, uses obviously-fake values, mirrors the same pattern already used in `blocksecops-dashboard/src/test/setup.ts`. No risk of production credential leakage.
- **Changeset B** correctly tied `SUPPORTED_EXTENSIONS` removal to verified absence of Rust callers — no runtime crash risk. The deprecation comment is retained as a tombstone.
- **Changeset E's `OccurrenceBadge.tsx`** is well-written defensively: nullable inputs are typed and explicitly handled, the `formatTs` helper try/catches invalid dates, and the component renders nothing (returns `null`) when neither display condition applies. React's automatic escaping protects every dynamic string.
- **Changeset E's API client additions** all flow through the existing `apiClient` (no bypass of auth/CSRF middleware), and the server-side `with_artifacts` and `include_duplicates` handlers were verified to exist and use `require_auth_with_scope(["contracts:write"])` (matches `api-endpoint-auth.md`).
- **Changeset D's removed-comment block** is unusually detailed for the kind of change it is, capturing the root cause (`dual-path racing`, `missing solc in the orchestration pod`) inline so the next engineer to look here understands why the task was removed. This is the kind of in-code documentation that prevents BSO-SEC-029-style regressions.

---

## Out-of-Scope Issues Noted (filed under TaskDocs-BlockSecOps separately)

1. **`resources/release-notes/2025/december.md:164,195` still mentions Cairo.** These are historical release notes describing the December 2025 state of the platform. Per memory `feedback_no_cairo.md` ("all Cairo references should be removed"), the strict reading is to remove them. Pragmatic reading: release notes are historical artifacts and rewriting them is revisionist. Recommend an editorial note ("Cairo support was discontinued in December 2025; see Q1 2026 release notes for details") rather than redacting history.
2. **Orchestration POST `/scans` endpoint is dead code.** No caller in any of the 17 audited repos invokes it. Recommend either deleting the endpoint or annotating it as `@deprecated` with a sunset date.
3. **Dashboard changeset description undercounted scope.** Future audit briefs should `git diff --stat` and `git status` first, rather than relying on the bullet description, to catch full scope of "small" changes.

---

## Follow-Up Section Conclusion

**No HALT triggered.** All five changesets are safe to ship from a security standpoint. The three new findings are:

- **BSO-SEC-028 (LOW)** — scanner inventory drift; documentation accuracy concern, not exploitable.
- **BSO-SEC-029 (INFO)** — stale code comments; debugging hazard, not exploitable.
- **BSO-SEC-030 (MEDIUM)** — admin retry endpoint functionally broken by Changeset D's Beat removal; operational regression, not a security boundary violation.

**Recommended ordering:**
1. Ship Changesets A, B, C, E as-is (each independent; no security blockers).
2. Ship Changeset D as-is (the production cluster is already running this version per user's note — codebase-first reconciliation per Rule 1).
3. Immediately follow Changeset D with a patch addressing BSO-SEC-030 (admin-retry dispatch). This is the only one with a real user-impact tail.
4. Triage BSO-SEC-028 and BSO-SEC-029 as documentation/tech-debt for the next docs sprint.

**No source files were modified during this audit.** All findings are advisory.

---

# Investigation: BSO-SEC-027 — 2026-06-20

**Auditor:** apogee-security-audit (Opus 4.7)
**Scope:** Reproduce BSO-SEC-027 (admin portal reachable via direct origin-IP bypass) and determine root cause via live runtime inspection. Read-only — no code or runtime mutation.
**Method:** (1) Re-curl from non-Cloudflare IP with SNI manipulation. (2) `kubectl describe` GCPBackendPolicy + HTTPRoute. (3) `gcloud compute` describe Cloud Armor policy + backend services. (4) WAF rule semantics validation against vendor docs.

## Reproduction Result: TRUE POSITIVE (confirmed and broader than originally filed)

The finding is real, the WAF rules are misordered, and the issue is **NOT admin-portal-specific** — it affects every backend behind the gateway (`admin.0xapogee.com`, `app.0xapogee.com` dashboard, `/api/v1/*` API). The "Cloudflare-only" enforcement is functionally non-existent at the IP-allowlist layer, although the preconfigured OWASP rules (SQLi/XSS/scanner detection) still fire correctly.

### Direct-Origin Probe Evidence (source IP `136.36.116.105`, NOT in any Cloudflare CIDR)

```bash
# Admin portal — should be 403 (default deny), got 200
$ curl -sk --resolve admin.0xapogee.com:443:34.149.16.104 \
    https://admin.0xapogee.com/ -D - -o /dev/null
HTTP/2 200
content-disposition: inline; filename="index.html"
via: 1.1 google           ← proves request hit GCP LB front-end (not Cloudflare)

# Dashboard — same story
$ curl -sk --resolve app.0xapogee.com:443:34.149.16.104 \
    https://app.0xapogee.com/ -o /dev/null -w "%{http_code}\n"
200

# API health — same story
$ curl -sk --resolve app.0xapogee.com:443:34.149.16.104 \
    https://app.0xapogee.com/api/v1/health/live -o /dev/null -w "%{http_code}\n"
200

# WAF preconfigured rules ARE evaluating (proves policy is attached and "working"):
$ curl -sk --resolve admin.0xapogee.com:443:34.149.16.104 \
    "https://admin.0xapogee.com/?id=1%20UNION%20SELECT%20password%20FROM%20users--" \
    -o /dev/null -w "%{http_code}\n"
403   ← sqli-v33-stable rule (priority 1001) fires

$ curl -sk -H "User-Agent: nikto" --resolve admin.0xapogee.com:443:34.149.16.104 \
    https://admin.0xapogee.com/ -o /dev/null -w "%{http_code}\n"
403   ← scannerdetection-v33-stable rule (priority 1005) fires
```

So: WAF policy attached and evaluating, OWASP rules firing, but the Cloudflare IP allowlist is silently bypassed.

## Runtime Evidence

### 1. GCPBackendPolicy is properly attached at runtime

```
$ kubectl describe gcpbackendpolicy admin-portal-policy -n admin-portal-prod
Spec:
  Default:
    Security Policy: apogee-production-waf-policy
    Timeout Sec:     30
  Target Ref:
    Kind: Service
    Name: admin-portal
Status:
  Conditions:
    Reason: Attached
    Status: True
    Type:   Attached
Events:
  Normal  SYNC  3m57s (x941 over 23h)  sc-gateway-controller
    Application of GCPBackendPolicy "admin-portal-prod/admin-portal-policy" was a success
```

All four backend policies (`admin-portal-policy`, `dashboard-policy`, `api-service-policy`, `notification-policy`) report `Status.Conditions[Attached]=True`.

### 2. GCP backend services confirm attachment

```
$ gcloud compute backend-services describe \
    gkegw1-crnq-admin-portal-prod-admin-portal-3000-xp2utdv9rk38 --global
SecurityPolicy: .../securityPolicies/apogee-production-waf-policy
EdgeSecurityPolicy: None
LoadBalancingScheme: EXTERNAL_MANAGED
LogConfig: { enable: false, sampleRate: 0.0 }   ← logging disabled (separate issue)
```

All four production backend services (admin-portal, api-service, dashboard, notification) have `SecurityPolicy: apogee-production-waf-policy` attached. `EdgeSecurityPolicy` is `None` for all (acceptable — backend-level enforcement is the design here).

### 3. The actual WAF rule set (live, sorted by priority)

```
prio=100         action=allow            "Allow Cloudflare IPs (1/3)"          10 IPv4 CIDRs
prio=101         action=allow            "Allow Cloudflare IPs (2/3)"          5 IPv4 CIDRs
prio=102         action=allow            "Allow Cloudflare IPv6 (3/3)"         7 IPv6 CIDRs
prio=900         action=rate_based_ban   "Rate limit scan creation"            match=request.path.matches('/api/v1/scans') && method=='POST'
prio=1000        action=deny(403)        "XSS protection"                      preconfigured xss-v33-stable
prio=1001        action=deny(403)        "SQL injection protection"            preconfigured sqli-v33-stable
prio=1002..1006  action=deny(403)        LFI/RFI/RCE/scanner/protocolattack    preconfigured
prio=2000        action=rate_based_ban   "Rate limiting: 30 req/min per IP"    srcIpRanges=["*"], conform_action=allow
prio=2147483647  action=deny(403)        "Default deny - only Cloudflare IPs"  srcIpRanges=["*"]
```

(Pulled live via `gcloud compute security-policies describe apogee-production-waf-policy --format=json` and post-processed.)

### 4. My source IP coverage

`136.36.116.105` is NOT in any allow CIDR (verified by Python `ipaddress` check against all CIDRs in rules 100/101/102). So the request SHOULD fall to priority 2147483647 default deny → 403. Empirically it falls to 200.

### 5. HTTPRoute is unambiguous — `admin.0xapogee.com` → `admin-portal` Service in `admin-portal-prod`, port 3000. No misrouting.

## Root Cause: Rule-Ordering Bug — `rate_based_ban` at priority 2000 short-circuits the default-deny at 2147483647

Cloud Armor evaluates rules in **priority order, lowest first**, and the **first matching rule wins** (per [cloud.google.com/armor/docs/security-policy-overview](https://cloud.google.com/armor/docs/security-policy-overview): "Typically, the highest priority rule that matches the request is applied").

For a plain `GET /` request from `136.36.116.105`:

| Priority | Match? | Action |
|----------|--------|--------|
| 100/101/102 (allow CF IPs) | No (IP not in CIDR) | skip |
| 900 (rate-ban /api/v1/scans POST) | No (different path) | skip |
| 1000–1006 (OWASP CRS) | No (clean payload) | skip |
| **2000 (rate_based_ban, srcIpRanges=`*`)** | **Yes (matches any IP)** | **conform_action=allow** ← **STOPS HERE** |
| 2147483647 (default deny) | (never evaluated) | (never applied) |

The general rate-based ban rule at priority 2000 has `srcIpRanges = ["*"]` and `conform_action = "allow"`. Every request matches this rule. As long as the source IP is under 30 req/min, the conform action `allow` is applied and **the default-deny rule at priority 2147483647 is never reached**.

Effectively, the platform's IP-allowlist enforcement has been silently disabled since the rate-limit rule was added. The OWASP CRS rules at 1000–1006 still fire because they have a lower priority (evaluated first), but the IP allowlist at 2147483647 is permanently shadowed by priority 2000.

This is consistent with the original BSO-SEC-027 evidence and with the new burst-testing observation: 50 sequential requests at ~1 req/sec all returned 200 (well under 30/min in a single curl-then-sleep loop, so even the rate exceed_action never triggered).

## Source-Code Location of the Bug

**File:** `/home/pwner/Git/blocksecops-gcp-infrastructure/terraform/modules/load-balancer/main.tf`
**Lines:** 277–298 — the "General rate limiting" rule at priority `2000` with `src_ip_ranges = ["*"]` and `conform_action = "allow"`.

This rule was added as a defense-in-depth rate cap, but its priority is numerically lower than the default-deny (`2147483647`), so it wins.

## Recommended Fix (do NOT apply yet)

**Two clean options. I recommend Option A.**

### Option A (preferred) — Scope the rate-based ban to Cloudflare IPs only, and accept it as ordering-compatible with default-deny

The intent of the general rate cap is to throttle abusive Cloudflare-proxied clients. Non-Cloudflare clients should be denied by IP, not rate-limited. Restrict the rule's `src_ip_ranges` to the same Cloudflare CIDRs used in priorities 100/101/102.

```diff
--- a/terraform/modules/load-balancer/main.tf
+++ b/terraform/modules/load-balancer/main.tf
@@ -277,11 +277,21 @@ resource "google_compute_security_policy" "waf" {
   # General rate limiting
   rule {
     action   = "rate_based_ban"
     priority = "2000"
     match {
       versioned_expr = "SRC_IPS_V1"
       config {
-        src_ip_ranges = ["*"]
+        # Only rate-limit Cloudflare-originated traffic; non-Cloudflare IPs
+        # are denied by the default-deny rule at priority 2147483647.
+        # Without this scoping, conform_action=allow shadows the default-deny.
+        src_ip_ranges = [
+          "173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22",
+          "103.31.4.0/22",   "141.101.64.0/18", "108.162.192.0/18",
+          "190.93.240.0/20", "188.114.96.0/20", "197.234.240.0/22",
+          "198.41.128.0/17", "162.158.0.0/15",  "104.16.0.0/13",
+          "104.24.0.0/14",   "172.64.0.0/13",   "131.0.72.0/22",
+        ]
       }
     }
     rate_limit_options {
       conform_action = "allow"
       exceed_action  = "deny(429)"
       enforce_on_key = "IP"
       rate_limit_threshold {
         count        = var.rate_limit_threshold
         interval_sec = 60
       }
       ban_duration_sec = 300
     }
-    description = "Rate limiting: ${var.rate_limit_threshold} req/min per IP"
+    description = "Rate limiting (Cloudflare IPs only): ${var.rate_limit_threshold} req/min per IP"
   }
 }
```

Cloud Armor's 10-CIDRs-per-rule limit may bite here — the existing IPv4 list is 15 entries split into two rules (100/101). If `src_ip_ranges` on this single rule rejects >10 CIDRs, split this rule into two parallel rate-ban rules (priority 2000 / 2001) covering the same CIDR slices as priorities 100/101 respectively, and drop IPv6 (or add a third at 2002).

After this change, the priority chain becomes:
1. priorities 100/101/102 → allow Cloudflare IPs (terminal allow)
2. priorities 900/1000–1006 → preconfigured OWASP / scan-endpoint rate ban
3. priority 2000 (now scoped) → matches only Cloudflare IPs; for non-CF requests this is a non-match and evaluation falls through
4. priority 2147483647 → default deny(403) for everything else (non-CF requests)

### Option B (alternative) — Move the rate-ban rule below the default-deny

Bump the rate-ban rule's priority to e.g. `2147483646` (one below default). This works but is fragile: if anyone ever adds another `["*"]` rule between 2147483646 and 2147483647, the same shadowing recurs. Option A is structurally robust.

### Operational corollary (separate, recommended)

`logConfig.enable = false` on all four backend services. Enable LB request logging so future WAF enforcement decisions show up in Cloud Logging with `jsonPayload.enforcedSecurityPolicy.{name,outcome,priority}` — this would have made the diagnosis instant. Not in the Terraform module today; add an `enableLogging = true` setting on the Gateway / backend services via the GKE Gateway annotations or update the LB module.

## Severity Re-rating

Original BSO-SEC-027 was filed MEDIUM (admin portal SPA exposure). With confirmed full-platform impact (`app.0xapogee.com` dashboard + `/api/v1/*` API also bypassable), **re-rate to HIGH**. The API surface is exposed to direct internet IPs without Cloudflare's rate-limiting, bot management, or WAF Phase-2 rules. Any authn/authz weakness in the api-service is now exploitable from any IP without Cloudflare telemetry.

Note: the GCP-side OWASP CRS rules (priorities 1000–1006) DO fire and provide partial protection; this is not "no defense", just "Cloudflare layer entirely bypassable."

## Verification Plan (post-fix)

After Option A is applied:
1. From a non-Cloudflare IP: `curl -k --resolve admin.0xapogee.com:443:34.149.16.104 https://admin.0xapogee.com/` → expect `HTTP 403`.
2. From a Cloudflare-proxied client (DNS-resolved normally): `curl https://admin.0xapogee.com/` (when the A record is added) → expect `HTTP 200`.
3. Verify rate cap still works for legitimate clients by sending >30 req/min from a Cloudflare-fronted client and confirming HTTP 429 after threshold.
4. Inspect `gcloud logging read 'jsonPayload.enforcedSecurityPolicy.name="apogee-production-waf-policy"'` to confirm policy decisions are visible (after enabling backend-service logging).

## Updated Follow-up Tasks

- [ ] Owner: approve Option A fix to `blocksecops-gcp-infrastructure/terraform/modules/load-balancer/main.tf:277–298`, `terraform apply`, then re-test from non-Cloudflare IP.
- [ ] Owner: enable backend-service request logging (sampleRate=1.0 in non-prod, ~0.1 in prod) for `apogee-production-waf-policy`-protected backends so WAF decisions are observable.
- [ ] Owner: when the platform is opened to customers, schedule a quarterly Cloud Armor rule-ordering audit (Option A would prevent this regression, but the audit catches new ones).
- [ ] Owner: independently re-evaluate the 7-CIDR IPv6 list and the 15-CIDR IPv4 list against the current published Cloudflare ranges at https://www.cloudflare.com/ips/ (not part of this fix; tracked separately).

**No source files were modified during this investigation.** Read-only inspection only.
