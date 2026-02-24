# Feature Test: Integration Security Hardening

**Feature:** Pre-GCP Integration Security Audit Fixes
**Version:** api-service 0.29.22, dashboard 0.46.4
**Date:** February 24, 2026
**Status:** Deployed and smoke-tested

## Smoke Test Results (February 24, 2026)

All platform services healthy after deployment:

| Check | Result |
|-------|--------|
| API health/live | PASS (v0.29.22) |
| API health/ready | PASS (database connected) |
| Dashboard HTTPS | PASS (HTTP 200) |
| All 6 internal services | PASS |
| Version drift | 0 drift across 9 services |
| Authenticated endpoints | 17/17 PASS |
| Unauthenticated rejection | 401 confirmed |
| Webhook GET endpoints | PASS (rate limit fix applied) |

## Backend Tests

### Webhook Secret Encryption
- [ ] Create webhook -> secret stored encrypted in DB (not plaintext)
- [ ] Rotate webhook secret -> new secret encrypted, old secret replaced
- [ ] Webhook HMAC verification still works with encrypted secret

### SSRF Protection
- [ ] Monitoring webhook_url rejects private IPs (e.g., `http://127.0.0.1`, `http://10.0.0.1`)
- [ ] Integration repo_url rejects private IPs
- [ ] JIRA base_url rejects private IPs
- [ ] Slack/Teams/Discord notifiers reject private IP webhook URLs
- [ ] Valid public URLs still accepted

### Error Sanitization
- [ ] OAuth code exchange failure returns generic message (no stack trace)
- [ ] OAuth token refresh failure returns generic message
- [ ] OAuth user info failure returns generic message
- [ ] JIRA API errors don't include `response.text`
- [ ] Notification delivery errors don't include `str(e)`

### Input Validation
- [ ] OAuth error_description truncated at 500 chars
- [ ] Integration settings rejects unknown keys
- [ ] Integration settings rejects nested objects
- [ ] JIRA project key rejects lowercase (`abc` -> error)
- [ ] JIRA project key rejects >10 chars
- [ ] Notification filters rejects unknown keys

### Access Control
- [ ] `verify_org_admin` rejects user with null role
- [ ] Webhook list endpoint rate-limited at 30/minute

### API Responses
- [ ] Notification channel response shows `masked_webhook_url` (not full URL)
- [ ] Stripe webhook health response has no `supported_events` field

### Kubernetes Configuration
- [ ] ExternalSecret syncs without `| default ""` (missing secret = sync error)
- [ ] SUPABASE_SERVICE_KEY comes from ExternalSecret, not ConfigMap
- [ ] INTERNAL_SERVICE_KEY available from ExternalSecret

## Frontend Tests

### URL Validation
- [ ] `isValidOAuthUrl('https://evil.com')` returns `false`
- [ ] `isValidOAuthUrl('https://github.com/login/oauth')` returns `true`
- [ ] Avatar URL with `javascript:` protocol not rendered as `<img src>`
- [ ] JIRA site URL with `data:` protocol not rendered as `<a href>`
- [ ] IDE marketplace URL with non-https protocol not rendered

### Error Handling
- [ ] Integration connect failure shows user-friendly error toast
- [ ] Integration reconnect failure shows user-friendly error toast
- [ ] No raw API error details visible in toast messages

### Webhook Domain Validation
- [ ] Slack webhook URL must contain `hooks.slack.com`
- [ ] Teams webhook URL must contain `webhook.office.com`
- [ ] Discord webhook URL must contain `discord.com`
- [ ] Invalid domain shows validation error in modal

### IDE Token Update
- [ ] Token name/expiry update sends data in body (check network tab)
- [ ] No sensitive data in URL query parameters
