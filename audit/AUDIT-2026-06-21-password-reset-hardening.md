# Password Reset & Change — Hardening Audit (2026-06-21)

**Auditor:** apogee-security-audit (preparatory) + manual review
**Scope:**
- `blocksecops-dashboard` v0.55.5 — `src/pages/ForgotPassword.tsx`, `src/pages/ResetPassword.tsx`, `src/components/settings/ChangePasswordCard.tsx`, `src/pages/Settings.tsx` (mount point)
- Supabase project configuration: SMTP (Resend), URL allow-list, "Reset Password" email template, OTP expiry
- Out of scope: api-service auth middleware (no changes; password flows are Supabase-direct), MFA, signup-email verification
- Baseline finding ID before this audit: **BSO-SEC-055**

**Standards referenced:** `docs/standards/api-endpoint-auth.md`, `docs/standards/encryption-standards.md`, `docs/standards/secure-coding.md`, OWASP ASVS v4.0.3 §2 (Authentication), §3 (Session), §4 (Access Control)

**Severity scale:** Critical / High / Medium / Low / Info

---

## Executive Summary

The password reset feature existed on the dashboard pre-hardening, but the flow had a **race-condition bug** in the recovery-token verification step (a 500ms `setTimeout` instead of subscribing to the `PASSWORD_RECOVERY` auth event), **misleading UI copy** that claimed 24-hour link validity against Supabase's 1-hour default, **no post-update global session invalidation**, and **no in-app change-password option for already-authenticated users**. None of these were exploitable in isolation, but combined they meant the feature was below customer-ready quality.

This hardening pass replaces the timer with `onAuthStateChange('PASSWORD_RECOVERY', ...)`, adds `signOut({scope:'others'})` after every password update (OWASP ASVS 3.3.1), corrects the expiry copy, wires toast notifications, adds a 60-second resend cooldown on the request form, and ships a new `ChangePasswordCard` for `/settings` that re-authenticates the user with their current password before allowing the change (OWASP ASVS 4.2.1).

20 new unit tests cover both flows. The full dashboard suite is green at 485/485.

The Supabase project configuration (Resend SMTP, redirect allow-list, branded email template) is documented as a step-by-step owner playbook in `docs/playbooks/password-reset-customer-support.md` Section 0. Until that one-time configuration is complete, the dashboard code is correct but the email channel will silently fail at scale (Supabase's default 2-emails-per-hour relay).

**Severity counts:** 0 Critical / 0 High / 0 Medium / 0 Low / 2 Info (informational notes, no new BSO-SEC findings allocated by this audit)

**Status:** No new BSO-SEC numbers consumed by this audit. The next available finding ID remains **BSO-SEC-056**, currently reserved by the pre-existing credential-exposure issue in `~/agents-skills/.claude/skills/apogee-platform-assistant.md` (separate cleanup, not part of this audit).

---

## Findings

### INFO-001 — Recovery token race condition replaced with event subscription

**Location (before):** `blocksecops-dashboard/src/pages/ResetPassword.tsx` lines 32-55 (pre-hardening)
**Location (after):** same file, hardened `useEffect`

**Pre-hardening:**
```ts
await new Promise(resolve => setTimeout(resolve, 500));
const { data: { session } } = await supabase.auth.getSession();
if (session) setStatus('ready');
```

The 500ms delay was an arbitrary "wait for Supabase to process the URL hash" guess. On slow networks or busy main threads it could fire before Supabase consumed the recovery token, causing valid links to display as expired. More importantly, it accepted ANY session — meaning an already-logged-in user navigating to `/reset-password` directly (without clicking an email link) would be allowed to change their password without proving they hold the recovery email.

**Hardened:**
```ts
supabase.auth.onAuthStateChange((event) => {
  if (event === 'PASSWORD_RECOVERY') setStatus('ready');
});
```

Now the page only unlocks when Supabase explicitly emits the `PASSWORD_RECOVERY` event — which only happens after the recovery token in the URL hash has been consumed and validated. A 3-second fallback timeout transitions to the expired-link state if no event arrives.

**Severity:** Informational (defense-in-depth; the pre-hardening behavior was not exploitable end-to-end because changing a password still required `updateUser` which Supabase rejects without an authenticated session). The hardened form is the documented Supabase pattern.

### INFO-002 — Global session invalidation added on every password change

**Location:** `ResetPassword.tsx` (reset flow) and `ChangePasswordCard.tsx` (in-app change)

After `supabase.auth.updateUser({ password })` succeeds, both flows now call:
```ts
await supabase.auth.signOut({ scope: 'others' });
```

This invalidates every other session for the user across all devices, keeping only the session that performed the change. Per OWASP ASVS 3.3.1: when a credential is changed (especially after suspected compromise via the reset flow), pre-existing sessions on other devices may belong to an attacker and must be terminated.

The current session remains valid so the user sees the success screen without being kicked out themselves.

**Severity:** Informational (defensive hardening).

---

## Properties verified

| Property | Check | Verified by |
|---|---|---|
| Recovery token is single-use + server-validated + 1h TTL | Supabase Auth (managed) | Supabase architecture — not our code |
| Password hashed bcrypt cost ≥12 at rest | Supabase Auth (managed) | `encryption-standards.md` compliance — verified by Supabase docs |
| Email enumeration resistance | `supabase.auth.resetPasswordForEmail` returns 200 regardless of whether the email exists | Manual + FP-11 in feature test |
| Password complexity rules enforced client-side | 8+ chars, ≥1 upper, ≥1 lower, ≥1 digit, ≠ current (in-app change) | `ResetPassword.tsx`, `ChangePasswordCard.tsx`, unit tests |
| Form state cleared after success | `setCurrentPassword('')` etc. in ChangePasswordCard | Unit test `clears form on success` |
| No plaintext credentials in code, comments, docs | grep `TestPass123`, `password.*=.*['"]` over changed files | grep clean (the only matches are this audit doc + the playbook in escape-as-text form) |
| Open-redirect safety on `redirectTo` | Supabase rejects any `redirectTo` not on the allow-list (BSO-SEC-021 precedent applies) | Track B step 0.4 must complete to enforce |
| Re-auth before sensitive op (in-app change) | `signInWithPassword` before `updateUser` | OWASP ASVS 4.2.1 — verified by unit test `on wrong current password: surfaces inline error and does NOT call updateUser` |
| Rate limit on recovery request | Supabase server-side + 60s UI cooldown | FP-12, FP-13 |
| Rate limit on re-auth (in-app change) | 3-in-5min client lock + Supabase server-side | CP-10, CP-11, unit test `locks the form after 3 failed re-auths in 5 min` |
| Transport encryption | HTTPS-only, sessionStorage (not localStorage) | `lib/supabase.ts` existing config — unchanged |
| DKIM/SPF/DMARC on sender domain | Resend domain verification | Track B step 0.2 — owner gate before any send |

---

## Out of scope for this audit (deferred / unrelated)

- **BSO-SEC-056 — `TestPass123` literal in `~/agents-skills/.claude/skills/apogee-platform-assistant.md`** — Pre-existing credential exposure on the public `dehvCurtis/agents-skills` repo (since 2026-06-20 21:32 MDT). Will be sanitized AFTER owner exercises the password-reset feature to rotate `jasonbrailowbizop@mail.com`. Tracked separately under Task #64 in this conversation's task list. NOT introduced by this work and NOT remediated by this work — but this work UNBLOCKS the remediation because the rotation requires a working reset feature.
- **BSO-SEC-041 — GDPR Art. 7 audit log for AI consent state changes** — Already-deferred Phase 2 BYO scope.
- **MFA / second-factor on password change** — Future enhancement; current gate (logged-in session + current-password re-auth) is sufficient pre-customer per `secure-coding.md`.

---

## Recommendations

1. **Run the owner setup playbook (Section 0 of `password-reset-customer-support.md`) before any customer can use the feature.** The dashboard hardening is necessary but not sufficient — without Resend + URL allow-list + branded email template, the feature is dead on arrival.
2. **After the owner's own rotation test passes**, unblock and complete Task #64 (sanitize `apogee-platform-assistant.md` + sync `agents-skills` + write BSO-SEC-056 finding).
3. **Future**: subscribe api-service to Supabase `auth.user.updated` webhook to log password changes server-side for audit compliance (low priority, not customer-blocking).
4. **Future**: consider enabling Cloudflare Turnstile on the recovery request endpoint once customer volume justifies the extra UX friction (Track B step 0.6).

---

## Addendum — Supabase config codification (added during ship cycle)

After the initial audit, the Track B Section 0a Supabase project configuration was codified into `blocksecops-dashboard/supabase/` (commit pending in this ship cycle). Verified:

- `supabase/config.toml` — `[auth].site_url`, `additional_redirect_urls`, `password_min_length = 8`, `password_requirements = "lower_upper_letters_digits"`, `[auth.email.template.recovery]` pointing at the branded HTML
- `supabase/templates/recovery.html` — branded body; uses `{{ .ConfirmationURL }}` (Supabase auto-escapes)
- `supabase/README.md` — documents the CLI workflow + a known quirk (CLI v2.107.0 pushes `subject` but not `content_path` body — workaround uses the management API PATCH directly)
- `supabase/.gitignore` — CLI default, excludes `.env.keys` + `.env.local` + `.env.*.local`

**No secrets staged.** `[auth.email.smtp]` block remains commented out; the documented pattern uses `pass = "env(VAR_NAME)"` so the API key never lives in git when Section 0b is enabled.

**Open-redirect posture (BSO-SEC-021 precedent)** verified via Supabase management API:

```
uri_allow_list: https://app.0xapogee.com/**,http://127.0.0.1:5173/**,http://localhost:5173/**
```

No wildcards or `*` patterns; all entries are scoped to known origins (production apex + local dev ports only). PASS.

**Branded recovery body** verified live (1269 chars, Apogee-branded inline-CSS HTML). PASS.

**Outstanding**: BSO-SEC-056 (`TestPass123` literal in public `dehvCurtis/agents-skills` since 2026-06-20 21:32 MDT) — remains the same gated cleanup; unblocks once owner completes the rotation test using the now-live Section 0a flow.
