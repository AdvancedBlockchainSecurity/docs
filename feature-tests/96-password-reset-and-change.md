# Password reset (email-link flow) + password change (in-app) — feature tests

**Priority**: P1 — Launch-blocking customer auth surface
**Last tested**: 2026-06-21 (initial)
**Endpoints (Supabase-direct, not api-service):**
- `POST {SUPABASE_URL}/auth/v1/recover` — request a password-reset email (`supabase.auth.resetPasswordForEmail`)
- `PUT {SUPABASE_URL}/auth/v1/user` — set a new password (`supabase.auth.updateUser`)
- `POST {SUPABASE_URL}/auth/v1/token?grant_type=password` — re-authenticate before in-app change (`supabase.auth.signInWithPassword`)
- `POST {SUPABASE_URL}/auth/v1/logout?scope=others` — invalidate other sessions (`supabase.auth.signOut({scope:'others'})`)

**Scope:**
- Frontend pages: `/forgot-password`, `/reset-password`, `/settings` (Security card)
- Dashboard version: 0.55.5 (UX hardening + ChangePasswordCard)
- Supabase project configuration: custom SMTP via Resend, branded "Reset Password" email template, allow-listed redirect URLs

**Cross-links:**
- Workflow: [`docs/workflows/password-management-workflow.md`](../workflows/password-management-workflow.md)
- Playbook: [`docs/playbooks/password-reset-customer-support.md`](../playbooks/password-reset-customer-support.md)
- Audit: [`docs/audit/AUDIT-2026-06-21-password-reset-hardening.md`](../audit/AUDIT-2026-06-21-password-reset-hardening.md)
- Standards: `docs/standards/api-endpoint-auth.md` (Supabase-direct auth flows note), `docs/standards/encryption-standards.md` (bcrypt cost ≥12 — Supabase default), `docs/standards/secure-coding.md` (rate limit + enumeration resistance)

---

## What these features do

**Forgot Password (`/forgot-password`)** — unauthenticated user can request a one-time recovery link to their registered email. Clicking the link lands them on `/reset-password` with a Supabase recovery token in the URL hash; once Supabase emits `PASSWORD_RECOVERY`, the form unlocks. After they pick a new password, all other sessions on the account are invalidated.

**Change Password (`/settings` → Security)** — already-authenticated users rotate their password without leaving the app or waiting on email. Requires re-entering the current password (OWASP ASVS 4.2.1 verify-before-sensitive-operation). On success, all other sessions are invalidated.

Both flows share the same password complexity rule: 8+ chars, at least one upper, one lower, one digit.

---

## Versions that shipped together

| Component | Version | Notes |
|---|---|---|
| `blocksecops-dashboard` | 0.55.5 | Hardened reset pages + ChangePasswordCard + new unit tests |
| Supabase project | (config) | **Section 0a (today)**: Site URL + redirect allow-list + branded body template, built-in SMTP (Supabase-controlled sender, 2 emails/hour cap). **Section 0b (before first customer)**: custom SMTP via Resend, sender `noreply@0xapogee.com`, no rate cap. |
| api-service | 0.46.5 | Unchanged — no backend coupling |
| ai-scanner | 0.2.8 | Unchanged |

---

## Preconditions

| Check | How to verify | Expected |
|---|---|---|
| Resend domain verified (Section 0b only) | Resend dashboard → Domains → `0xapogee.com` (apex) | `Verified` status, DKIM/SPF/DMARC green. Skip if still on Section 0a abbreviated path — Supabase built-in SMTP doesn't use Resend. |
| Supabase SMTP wired to Resend | Supabase Dashboard → Authentication → SMTP Settings | Custom SMTP enabled, host `smtp.resend.com`, sender on the verified domain |
| Site URL set | Supabase Dashboard → Authentication → URL Configuration | `https://app.0xapogee.com` |
| Redirect URLs allow-listed | Same panel | `https://app.0xapogee.com/**` + the local dev origin |
| Email template customized | Supabase Dashboard → Authentication → Email Templates → Reset Password | Apogee branding, `{{ .ConfirmationURL }}` CTA, "1 hour" copy matches dashboard. Note: template controls the BODY, not the `From:` — the sender is Supabase-controlled on the abbreviated path and `noreply@0xapogee.com` on the full path. |
| Token expiry matches UI | Supabase Dashboard → Authentication → Email Settings → OTP expiry | 3600s (1h) — matches the "1 hour" copy in `ForgotPassword.tsx` |

If any precondition fails, fix it before running the matrix below — otherwise tests will fail for the wrong reason.

---

## Test matrix — Forgot Password (email flow)

| # | Test | Steps | Expected |
|---|---|---|---|
| FP-01 | Happy path | `/forgot-password` → enter registered email → "Send Reset Link" | Success screen "Check your email"; reset email arrives in inbox within 60s. **Section 0a**: sender is Supabase-controlled (e.g. `noreply@mail.app.supabase.io`). **Section 0b**: sender is `noreply@0xapogee.com`. Subject either way: "Reset your Apogee password" |
| FP-02 | Click link → form unlocks | Open reset email → click CTA | Lands on `/reset-password`; "Verifying link" shows briefly then transitions to "Set new password" form |
| FP-03 | New password set | Enter strong password (8+, upper, lower, digit) + matching confirm → submit | Success screen "Password updated"; redirected to `/login` within 3s |
| FP-04 | Login with new password | `/login` with the new password | Sign-in succeeds |
| FP-05 | Login with old password | `/login` with the old password | Sign-in rejected |
| FP-06 | Session invalidation | Have a second browser tab logged in BEFORE the reset → reload after reset | Second tab kicked to `/login` |
| FP-07 | Expired link | Wait > 1 hour after FP-01 → click email link | `/reset-password` shows "Link expired" state with "Request New Reset Link" CTA |
| FP-08 | Tampered token | Edit the URL hash recovery token manually → load `/reset-password` | "Link expired" state; no form |
| FP-09 | Weak password rejected | FP-02 → enter `weak` + matching confirm → submit | Inline error "Password must be at least 8 characters"; no Supabase call |
| FP-10 | Mismatched confirm | FP-02 → password `StrongPass123` + confirm `Different456` → submit | Inline error "Passwords do not match"; no Supabase call |
| FP-11 | Enumeration resistance | `/forgot-password` with a non-registered email | Same "Check your email" success screen (Supabase default — does not leak whether the address exists) |
| FP-12 | Rate limit | Submit FP-01 6 times in 1 hour with the same email | 5th or later submission: Supabase error toast "For security purposes, you can only request this once every X seconds"; UI cooldown counter visible |
| FP-13 | Send-to-different cooldown | FP-01 success → immediately click "Send to a different email" | Button disabled, label shows `(NN s)` counting down from 60 |

---

## Test matrix — Change Password (in-app flow)

| # | Test | Steps | Expected |
|---|---|---|---|
| CP-01 | Happy path | Logged in → `/settings` → Security card → current + new + matching confirm → "Update password" | Success toast "Password updated. Other devices have been signed out."; form fields cleared |
| CP-02 | Other-device signout | Have second browser tab logged in BEFORE → reload after CP-01 | Second tab kicked to `/login` |
| CP-03 | Login with new password | Log out + `/login` with the new password | Sign-in succeeds |
| CP-04 | Login with old password | `/login` with the old password | Sign-in rejected |
| CP-05 | Wrong current password | Current = wrong value, new + confirm = strong | Inline error "Current password is incorrect"; `updateUser` NOT called; `signOut` NOT called |
| CP-06 | New equals current | Current + new + confirm all the same valid password | Inline error "New password must be different from current password"; no Supabase call |
| CP-07 | Weak new password | Current correct, new = `weak`, confirm = `weak` | Inline error "Password must be at least 8 characters"; no Supabase call |
| CP-08 | Missing uppercase/digit | Current correct, new = `lowercaseonly`, confirm = `lowercaseonly` | Inline error "Password must contain uppercase, lowercase, and number" |
| CP-09 | Mismatched confirm | Current correct, new = `StrongPass123`, confirm = `Different456` | Inline error "Passwords do not match"; no Supabase call |
| CP-10 | Re-auth rate limit | Submit CP-05 three times in under 5 min | After 3rd failure: yellow lock banner "Too many failed attempts. Try again in NNs."; submit button disabled |
| CP-11 | Lock self-clears | Wait 5 min after CP-10 | Banner disappears; form re-enables |
| CP-12 | Show-password toggle | Click eye icon on any field | Field type toggles between `password` and `text` |
| CP-13 | API still works after change | After CP-01: re-issue access token via login + call `/api/v1/scans` or other protected endpoint | 200 OK with the new JWT (proves Supabase issued a valid session post-rotation) |

---

## Results

| Date | Tester | FP results | CP results | Notes |
|---|---|---|---|---|
| 2026-06-21 | _(pending)_ | _(pending owner Gate 3a)_ | _(pending owner Gate 3b)_ | Initial verification by owner using own test account `jasonbrailowbizop@mail.com`. Both flows must pass before the deferred BSO-SEC-056 sanitization unblocks (Task #64). |

---

## Notes

- The api-service is intentionally NOT in this flow. Supabase Auth handles the whole credential lifecycle; api-service only verifies JWTs it receives from authenticated requests.
- If a customer reports "I never got the reset email" — see the customer-support playbook for the Resend Logs lookup path.
- A future enhancement could add backend audit-logging by subscribing api-service to Supabase webhooks (`auth.user.updated`) — out of scope for v0.55.5.
