# Password Reset — Customer Support Playbook

For ops + customer support when a user reports a password issue. Also doubles as the **owner setup playbook** for the one-time Resend + Supabase configuration (Section 0).

**Audience**: ops, customer support, founder/owner
**Linked workflow**: [`docs/workflows/password-management-workflow.md`](../workflows/password-management-workflow.md)
**Feature tests**: [`docs/feature-tests/96-password-reset-and-change.md`](../feature-tests/96-password-reset-and-change.md)

---

## Section 0 — One-time setup (owner, before any customer can use the feature)

These are dashboard clicks + DNS — no code. Do them in this order; do NOT skip any.

### 0.1 Provision Resend (free tier, ~5 min)

1. Sign up at <https://resend.com> with your owner email
2. Settings → **API Keys** → Create API Key
   - Name: `apogee-supabase-smtp`
   - Permission: **Sending access** only (NOT full access)
   - Copy the `re_xxxxx` key — you'll paste it into Supabase in step 0.3
3. Settings → **Domains** → Add Domain
   - Use the production sender domain (e.g. `app.0xapogee.com` — match the dashboard's Site URL)
4. Resend will display 3 DNS records:
   - 1× `MX` (Resend mail handler)
   - 1× `TXT` for SPF
   - 1× `TXT` for DKIM
   - (DMARC is optional but recommended — Resend will offer the value)

### 0.2 Add DNS records (Cloudflare, ~5 min + propagation)

In the Cloudflare dashboard for `0xapogee.com`:

1. DNS → Records → Add each of the 3 (or 4 with DMARC) values from Resend verbatim
2. Set proxy status to **DNS only** (gray cloud) for the MX record — proxying would break mail
3. Wait 5–10 min for propagation, then click **Verify** in Resend → status should turn `Verified`

### 0.3 Configure Supabase SMTP

Supabase Dashboard → Authentication → SMTP Settings:

| Field | Value |
|---|---|
| Enable Custom SMTP | ✓ |
| Sender email | `noreply@app.0xapogee.com` (must be on verified domain) |
| Sender name | `Apogee Security` |
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` (literal string — Resend's SMTP uses this as username) |
| Password | the `re_xxxxx` API key from step 0.1 |
| Minimum interval between emails | `60` (seconds) |

Save → click "Send Test Email" → confirm it arrives in your inbox from the Apogee sender.

### 0.4 Configure URL Configuration

Supabase Dashboard → Authentication → URL Configuration:

| Field | Value |
|---|---|
| Site URL | `https://app.0xapogee.com` |
| Redirect URLs | One per line:<br>`https://app.0xapogee.com/**`<br>`http://127.0.0.1:5173/**`<br>`http://localhost:5173/**` |

### 0.5 Customize the "Reset Password" email template

Supabase Dashboard → Authentication → Email Templates → **Reset Password**:

- **Subject**: `Reset your Apogee password`
- **Body** (suggested HTML — keep simple for max email-client compatibility):

```html
<table width="100%" cellpadding="0" cellspacing="0" style="font-family: -apple-system, system-ui, sans-serif; color: #1a1a1a; max-width: 560px; margin: 0 auto;">
  <tr><td style="padding: 32px 24px 16px;">
    <h1 style="margin: 0 0 16px; font-size: 24px;">Reset your Apogee password</h1>
    <p style="margin: 0 0 16px; line-height: 1.5;">
      We received a request to reset the password for your Apogee account.
      Click the button below to choose a new password — the link expires in 1 hour.
    </p>
    <p style="margin: 24px 0;">
      <a href="{{ .ConfirmationURL }}"
         style="display: inline-block; padding: 12px 24px; background: #2563eb; color: #fff; text-decoration: none; border-radius: 8px; font-weight: 600;">
        Reset password
      </a>
    </p>
    <p style="margin: 16px 0 0; font-size: 13px; color: #666;">
      If you didn't request this, you can safely ignore this email — your password won't change.
    </p>
    <hr style="border: 0; border-top: 1px solid #eee; margin: 32px 0;" />
    <p style="margin: 0; font-size: 12px; color: #888;">
      Apogee — smart-contract security at <a href="https://app.0xapogee.com" style="color: #2563eb;">app.0xapogee.com</a>
    </p>
  </td></tr>
</table>
```

### 0.6 (Optional) Enable Turnstile captcha on recovery

Supabase Dashboard → Authentication → Captcha → enable Turnstile with the existing Apogee Turnstile sitekey. If enabled, also add the `<Turnstile />` widget to `ForgotPassword.tsx` and pass the resolved token via `captchaToken`. Skip if you'd rather not add the extra UX step now — Supabase rate-limiting alone is acceptable for pre-customer launch.

### 0.7 Smoke-test before customer use

Run the FP-01 through FP-04 scenarios from [`docs/feature-tests/96-password-reset-and-change.md`](../feature-tests/96-password-reset-and-change.md) against your own owner account. If they pass, the feature is live.

---

## Section 1 — Customer support workflows

### Symptom: "I never got the reset email"

**Step 1 — confirm the user exists and is active**

- Supabase Dashboard → Authentication → Users → search by email
- Check:
  - User record exists
  - `email_confirmed_at` is set (if not, the user signed up but never verified — they need a fresh signup confirmation, not a password reset)
  - User is not `banned`

**Step 2 — check delivery in Resend**

- Resend Dashboard → Logs → search by recipient email
- Find the most recent send. Status will be one of:
  - `Delivered` — message reached recipient's mail server. Walk customer through spam check (see Step 4).
  - `Bounced` — recipient address is invalid or full. Contact customer for an alternate email (see Step 3).
  - `Complained` — recipient flagged the message as spam. Stop sending. Reset via admin override (see Step 5).
  - `Sent` (no terminal status) — in flight, wait 1–2 min.

**Step 3 — bounced address**

If permanently bounced (`5xx`), the email account no longer exists or is mistyped. Verify the address with the customer through a secondary channel (LinkedIn, Twitter DM, support ticket reply chain) and update the email on file via Supabase Dashboard → Authentication → Users → user record → Edit. Then re-trigger reset.

**Step 4 — delivered but customer says they didn't see it**

Walk customer through:

1. Check spam / promotions folder
2. Search inbox for `noreply@app.0xapogee.com` or subject `Reset your Apogee password`
3. Add the sender to safe-senders / whitelist
4. Confirm they're checking the SAME email that's on file (typos, corporate vs personal address, etc.)
5. If still nothing, re-trigger from the dashboard (they may need to wait out the per-address rate limit — default 4/hour)

**Step 5 — escalation: admin password override**

Last resort, when none of the above resolves it. Audit-logged.

- Supabase Dashboard → Authentication → Users → user → "Send password recovery" button (alternate path)
- OR Supabase Dashboard → user → "Update user" → set a temporary password manually
  - Communicate the temporary password OUT OF BAND (not over the same channel the user reported the issue on)
  - Instruct customer to change it immediately via `/settings → Security`
- Log the override action in the security incident log with: support ticket ID, customer email, override timestamp, the support person who performed it, and reason

### Symptom: "The reset link says 'expired' immediately"

Most common causes (in rank order):

1. The link was opened more than 1 hour after the email arrived — TTL is 3600s. Have the customer request a new reset.
2. The customer clicked the link in a different browser than the one they have the dashboard open in — Supabase's recovery token sets a session in the browser that opens the link; if the customer copies the URL into a different browser, the token can still be consumed but the page needs to load it fresh. Tell them to use the same browser, OR open the link in a private/incognito window.
3. Some corporate email proxies (e.g. Microsoft Safe Links) pre-fetch URLs and consume the recovery token before the user clicks. If you see this pattern repeating for users on Outlook/Exchange domains, escalate to engineering — workaround is to enable Supabase Auth → URL Configuration → "Use external link wrapping" if available, or instruct the user to forward the email to a personal address.

### Symptom: "I keep getting 'current password is incorrect' in Settings"

- Confirm they're not caps-locked or using autofill from a stale password manager entry.
- After 3 failed attempts the form locks for 5 min — they may need to wait.
- If they genuinely don't remember the current password, point them to `/forgot-password` instead.

### Symptom: "I changed my password and now nothing on my phone works"

Expected — that's the global session invalidation (`signOut({scope:'others'})`). Tell them to log in fresh on the phone with the new password. This is by design and explained on the change-password card.

---

## Section 2 — Notes for engineering

- The "session invalidation on password change" behavior is a defensive default; if a customer complains it's too aggressive (e.g. they have many devices and find re-login painful), it's NOT user-configurable today. Adding a "keep other sessions" opt-in would be a future feature, not a bug fix.
- If Resend ever becomes a bottleneck (3k emails/month free tier exhausted), the next-cheapest path is AWS SES (~$0.10 per 1k emails) using the same SMTP plumbing — just swap the host/credentials in Supabase SMTP Settings; no code change.
- The "1 hour" expiry copy in `ForgotPassword.tsx` is hard-coded; if you change `OTP expiry` in Supabase Email Settings, also update the line in the page so the message doesn't lie.
