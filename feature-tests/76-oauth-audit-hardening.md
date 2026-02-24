# OAuth Audit Hardening

**Priority**: P1 - High
**Last Tested**: 2026-02-24
**Scope**: OAuth credential encryption enforcement, error message sanitization, URL validation
**API Version**: 0.29.20
**Dashboard Version**: 0.46.3

---

## 1. Encryption Key Enforcement (Production)

### 1.1 API Service Fails Without Key

- [ ] API service refuses to start in production without `INTEGRATION_ENCRYPTION_KEY`
- [ ] Error message: `INTEGRATION_ENCRYPTION_KEY is required in production`
- [ ] Non-production environments still start with a warning

```bash
# Verify production enforcement
kubectl exec -n api-service deployment/api-service -- env | grep INTEGRATION_ENCRYPTION_KEY
# Should show a value starting with base64 characters

# In production: missing key causes startup failure via errors.append() in model_post_init
```

### 1.2 Encryption Service Initializes

- [ ] API service logs: `"Encryption service initialized successfully"`
- [ ] `encryption_service.is_configured` returns `True`
- [ ] Fernet key is valid base64-encoded 32-byte value

---

## 2. Error Message Sanitization

### 2.1 OAuth Credential Error (No Env Var Leak)

- [ ] When OAuth credentials missing, error message says "Contact your administrator"
- [ ] Error message does NOT contain `CLIENT_ID` or `CLIENT_SECRET`
- [ ] Internal log contains env var names (for debugging)

```bash
# Check error message doesn't leak env vars
# Attempt OAuth connection without credentials configured
# Dashboard should show: "GitHub OAuth is not configured. Contact your administrator..."
# NOT: "Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET environment variables"
```

### 2.2 Token Exchange Error (Safe Detail)

- [ ] Token exchange failures stored with `get_safe_error_detail()`
- [ ] `integration.last_error` does not contain raw exception messages
- [ ] Safe error detail shows sanitized message for "token exchange" context

### 2.3 User Info Error (Safe Detail)

- [ ] User info fetch failures stored with `get_safe_error_detail()`
- [ ] `integration.last_error` does not contain raw exception messages
- [ ] Safe error detail shows sanitized message for "user info retrieval" context

---

## 3. Jenkins URL Validation

### 3.1 HTTPS Required

- [ ] Jenkins URL `http://jenkins.example.com` is rejected
- [ ] Jenkins URL `https://jenkins.example.com` is accepted
- [ ] Known OAuth providers (github.com, gitlab.com) still validate against allowed hosts

### 3.2 No Unconditional Bypass

- [ ] `isValidOAuthUrl()` does NOT always return `true`
- [ ] Function validates protocol is `https:`
- [ ] Invalid URLs (empty, malformed) are rejected

---

## 4. Full OAuth Flow (GCP Only)

> These tests require a public domain with valid TLS and OAuth app credentials configured.

### 4.1 GitHub OAuth

- [ ] Click "Connect GitHub" → redirects to github.com/login/oauth/authorize
- [ ] Authorize → redirects back to `/api/v1/oauth/github/callback`
- [ ] Integration status changes to "connected"
- [ ] External username and avatar displayed
- [ ] Access token encrypted in `integration_credentials` (starts with `gAAAAA`)

### 4.2 GitLab OAuth

- [ ] Click "Connect GitLab" → redirects to gitlab.com/oauth/authorize
- [ ] Authorize → callback → status "connected"
- [ ] Encrypted token stored

### 4.3 Bitbucket OAuth

- [ ] Click "Connect Bitbucket" → redirects to bitbucket.org/site/oauth2/authorize
- [ ] Authorize → callback → status "connected"
- [ ] Uses HTTP Basic Auth for token exchange (verified in logs)

### 4.4 JIRA OAuth

- [ ] Click "Connect JIRA" → redirects to auth.atlassian.com/authorize
- [ ] Authorize → callback → status "connected"
- [ ] `jira_cloud_id` and `jira_site_url` populated
- [ ] Refresh token stored (offline_access scope)

### 4.5 Jenkins API Token

- [ ] Enter HTTPS Jenkins URL + username + API token
- [ ] Connection validated → status "connected"
- [ ] HTTP Jenkins URL rejected by frontend validation

---

## 5. Security Verification

### 5.1 Rate Limiting

- [ ] Callback endpoints rate-limited to 10/minute
- [ ] 11th request within 1 minute returns 429

### 5.2 State JWT

- [ ] State JWT expires after 15 minutes
- [ ] Expired state returns redirect to `/integrations?error=auth_failed`
- [ ] Provider mismatch (GitHub state on GitLab callback) is rejected

### 5.3 Open Redirect Protection

- [ ] `get_dashboard_url()` rejects paths with schemes (e.g., `https://evil.com`)
- [ ] `get_dashboard_url()` rejects paths with netloc
- [ ] Only relative paths starting with `/` are allowed

---

## Files Changed

| File | Change | Version |
|------|--------|---------|
| `src/infrastructure/config.py` | Enforce encryption key in production | 0.29.20 |
| `src/application/services/oauth_service.py` | Sanitize error messages | 0.29.20 |
| `src/presentation/api/v1/endpoints/oauth_callbacks.py` | Safe error detail | 0.29.20 |
| `src/components/integrations/hub/CICDTab.tsx` | Fix URL validation | 0.46.3 |
