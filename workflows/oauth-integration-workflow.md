# OAuth Integration Workflow

**Last Updated:** 2026-04-17
**Status:** Active for GitLab / Bitbucket / JIRA / Jenkins
**API Version:** 0.29.22+

> **GitHub note (2026-04-17):** New GitHub integrations should use the **BYO GitHub App manifest flow** (`docs/workflows/github-app-byo-install-workflow.md`), not OAuth. The OAuth path described below is retained for GitLab / Bitbucket / JIRA / Jenkins and for pre-existing GitHub OAuth integrations. Retirement of the GitHub OAuth path is a separate follow-up once no customers depend on it.

---

## Overview

The OAuth integration system connects Apogee to third-party services (GitHub, GitLab, Bitbucket, JIRA, Jenkins) using OAuth 2.0 Authorization Code flow. Tokens are encrypted at rest with Fernet (AES-128-CBC + HMAC-SHA256).

```
┌──────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Dashboard UI    │     │   API Service     │     │  OAuth Provider  │
│                   │     │                   │     │  (GitHub, etc.)  │
│  1. User clicks   │     │                   │     │                  │
│     "Connect"     │────►│  2. Create        │     │                  │
│                   │     │     integration    │     │                  │
│                   │     │     (status:       │     │                  │
│                   │     │      pending)      │     │                  │
│                   │     │                   │     │                  │
│                   │     │  3. Generate state │     │                  │
│                   │     │     JWT (15-min    │     │                  │
│                   │     │      expiry)       │     │                  │
│                   │     │                   │     │                  │
│  4. Redirect to   │◄────│  Return OAuth URL  │     │                  │
│     provider      │     │                   │     │                  │
│                   │────────────────────────────►│                  │
│                   │     │                   │     │  5. User         │
│                   │     │                   │     │     authorizes   │
│                   │     │                   │     │                  │
│                   │     │  6. Callback with  │◄────│  Redirect with   │
│                   │     │     code + state   │     │  code + state    │
│                   │     │                   │     │                  │
│                   │     │  7. Verify state   │     │                  │
│                   │     │     JWT            │     │                  │
│                   │     │                   │     │                  │
│                   │     │  8. Exchange code  │────►│                  │
│                   │     │     for tokens     │◄────│  access_token    │
│                   │     │                   │     │  refresh_token   │
│                   │     │                   │     │                  │
│                   │     │  9. Get user info  │────►│                  │
│                   │     │                   │◄────│  username, id    │
│                   │     │                   │     │                  │
│                   │     │ 10. Encrypt tokens │     │                  │
│                   │     │     with Fernet    │     │                  │
│                   │     │                   │     │                  │
│                   │     │ 11. Store creds,   │     │                  │
│                   │     │     update status  │     │                  │
│                   │     │     to "connected" │     │                  │
│                   │     │                   │     │                  │
│ 12. Redirect to   │◄────│  Redirect with     │     │                  │
│     dashboard     │     │  success params    │     │                  │
│     /integrations │     │                   │     │                  │
│     ?success=true │     │                   │     │                  │
└──────────────────┘     └──────────────────┘     └─────────────────┘
                                  │
                                  ▼
                          ┌──────────────┐
                          │  PostgreSQL   │
                          │              │
                          │ integrations │
                          │ integration_ │
                          │  credentials │
                          └──────────────┘
```

---

## Services Involved

| Service | Role | Port |
|---------|------|------|
| Dashboard | Integration UI, initiates OAuth flows | 3000 (via Traefik) |
| API Service | OAuth flow orchestration, token storage | 8000 |
| PostgreSQL | Stores integrations and encrypted credentials | 5432 |
| Vault / GCP Secret Manager | Stores OAuth client credentials and encryption key | 8200 |

---

## Detailed Flow

### Phase 1: Initiation (Dashboard + API)

1. **User clicks "Connect"** on the Integrations page
   - Dashboard: `POST /api/v1/organizations/{org_id}/integrations`
   - Body: `{ "provider": "github", "name": "GitHub" }`

2. **API creates integration record** (status: `pending`)
   - Validates user has org admin role
   - Creates `IntegrationModel` row

3. **API generates state JWT** containing:
   ```json
   {
     "org_id": "uuid",
     "user_id": "uuid",
     "integration_id": "uuid",
     "provider": "github",
     "nonce": "random-16-bytes",
     "exp": "now + 15 minutes",
     "iat": "now"
   }
   ```
   - Signed with `JWT_SECRET_KEY` using configured algorithm
   - Nonce prevents replay attacks

4. **API returns OAuth authorization URL**
   - `https://github.com/login/oauth/authorize?client_id=...&redirect_uri=...&state=<jwt>&scope=repo+read:org+read:user`

5. **Dashboard redirects user** to provider authorization page

### Phase 2: Provider Authorization

6. **User authorizes** the application at the provider
7. **Provider redirects** to callback URL with `code` and `state` parameters
   - `GET /api/v1/oauth/github/callback?code=abc123&state=<jwt>`

### Phase 3: Token Exchange (API)

8. **API verifies state JWT**
   - Checks signature, expiry, and nonce
   - Extracts `org_id`, `integration_id`, `provider`
   - Verifies provider matches callback endpoint

9. **API exchanges code for tokens**
   - `POST https://github.com/login/oauth/access_token`
   - Body: `grant_type=authorization_code&code=abc123&redirect_uri=...&client_id=...&client_secret=...`
   - Returns: `access_token`, `refresh_token` (optional), `expires_in`, `scope`

10. **API fetches user info**
    - `GET https://api.github.com/user` with Bearer token
    - Returns: `id`, `login`, `email`, `avatar_url`

### Phase 4: Credential Storage (API + Database)

11. **Encrypt tokens** with Fernet (AES-128-CBC + HMAC-SHA256)
    - Key: `INTEGRATION_ENCRYPTION_KEY` (base64-encoded 32-byte key)
    - Encrypted tokens stored in `integration_credentials` table

12. **Update integration record**
    - Status: `connected`
    - External account ID, username, avatar URL
    - JIRA-specific: `cloud_id`, `site_url`

13. **Redirect to dashboard** with success parameters
    - `https://app.0xapogee.com/integrations?success=true&integration_id=...&provider=github`

---

## Provider-Specific Details

### GitHub

| Setting | Value |
|---------|-------|
| Authorize URL | `https://github.com/login/oauth/authorize` |
| Token URL | `https://github.com/login/oauth/access_token` |
| API Base | `https://api.github.com` |
| User Endpoint | `/user` |
| Scopes | `repo`, `read:org`, `read:user` |
| Auth Method | Client ID/Secret in POST body |
| Scope Delimiter | Comma (normalized to space) |

### GitLab

| Setting | Value |
|---------|-------|
| Authorize URL | `https://gitlab.com/oauth/authorize` |
| Token URL | `https://gitlab.com/oauth/token` |
| API Base | `https://gitlab.com/api/v4` |
| User Endpoint | `/user` |
| Scopes | `api`, `read_user`, `read_repository` |
| Auth Method | Client ID/Secret in POST body |

### Bitbucket

| Setting | Value |
|---------|-------|
| Authorize URL | `https://bitbucket.org/site/oauth2/authorize` |
| Token URL | `https://bitbucket.org/site/oauth2/access_token` |
| API Base | `https://api.bitbucket.org/2.0` |
| User Endpoint | `/user` |
| Scopes | `repository`, `pullrequest`, `webhook` |
| Auth Method | HTTP Basic Auth (client_id:client_secret) |

### JIRA (Atlassian)

| Setting | Value |
|---------|-------|
| Authorize URL | `https://auth.atlassian.com/authorize` |
| Token URL | `https://auth.atlassian.com/oauth/token` |
| API Base | `https://api.atlassian.com` |
| User Endpoint | `/me` |
| Resources Endpoint | `/oauth/token/accessible-resources` |
| Scopes | `read:jira-work`, `write:jira-work`, `read:jira-user`, `offline_access` |
| Auth Method | Client ID/Secret in POST body |
| Extra Params | `audience=api.atlassian.com`, `prompt=consent` |

JIRA requires an additional step: fetching accessible resources to get the `cloud_id` and `site_url` before user info.

### Jenkins

| Setting | Value |
|---------|-------|
| Auth Type | API Token (not OAuth) |
| User Endpoint | `/me/api/json` |
| Scopes | `Overall/Read`, `Job/Build`, `Job/Read` |

Jenkins does not use OAuth. Users provide their Jenkins URL and API token directly. The callback endpoint handles the token-based authentication flow.

---

## Token Lifecycle

### Storage

- Access tokens and refresh tokens encrypted with Fernet before storage
- Stored in `integration_credentials` table
- `token_type`, `scopes`, `expires_at` stored as metadata

### Expiry Tracking

- `expires_at` calculated from `expires_in` at token creation time
- GitHub tokens do not expire (no `expires_in`)
- GitLab and JIRA tokens expire and provide refresh tokens

### Token Refresh (Future)

Currently, token refresh must be triggered manually. A future enhancement will add a periodic background job to:
1. Check for tokens expiring within 1 hour
2. Use refresh tokens to obtain new access tokens
3. Re-encrypt and store updated tokens
4. Update `expires_at` timestamp

### Token Revocation (Future)

Currently, disconnecting an integration deletes the credential record but does not revoke the token at the provider. A future enhancement will call provider revocation endpoints:
- GitHub: `DELETE /applications/{client_id}/grant`
- GitLab: `POST /oauth/revoke`
- Bitbucket: No revocation endpoint
- JIRA: No revocation endpoint

---

## Security

### State JWT

- Signed with `JWT_SECRET_KEY` (same key used for user auth)
- 15-minute expiry prevents stale authorization flows
- Random nonce prevents replay attacks
- Provider verified against callback endpoint (prevents cross-provider attacks)

### Token Encryption

- Algorithm: Fernet (AES-128-CBC + HMAC-SHA256)
- Key: 32-byte base64-encoded key from `INTEGRATION_ENCRYPTION_KEY`
- Encryption is **mandatory in production** (API service fails to start without key)
- Encrypted tokens prefixed with `gAAAAA` (Fernet format)

### Error Handling (v0.29.22)

- Error messages sanitized to prevent internal detail leaks
- OAuth error details from providers logged but not exposed to users
- `OAuthServiceError` messages use static safe strings (no `str(e)` leaks)
- `error_description` callback parameter capped at 500 characters
- `last_error` stored truncated: `(error_description or error or "unknown")[:500]`

### SSRF Protection (v0.29.22)

- `repo_url` validated with `validate_webhook_url()` on creation
- JIRA `base_url` validated before HTTP requests
- Blocks private IP ranges (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)

### Input Validation (v0.29.22)

- Integration `settings` dict restricted to allowlisted keys, no nested objects
- JIRA project key: `max_length=10`, pattern `^[A-Z][A-Z0-9_]+$`
- JIRA project name: `max_length=255`

### Rate Limiting

- All callback endpoints rate-limited to 10 requests per minute
- Webhook GET endpoints rate-limited to 30 requests per minute (v0.29.22)
- Prevents brute-force attacks on callback and data endpoints

### Access Control (v0.29.22)

- Only org admins can create/delete integrations
- Org membership verified on all integration endpoints
- `verify_org_admin` null role bypass fixed (`if not role or` instead of `if role and`)
- Open redirect protection on dashboard redirect URLs

### Frontend Security (v0.46.4)

- `isValidOAuthUrl()` rejects non-allowlisted hosts (was returning true for all HTTPS)
- External avatar URLs validated for `https://` protocol before rendering
- JIRA site URLs validated for `https://` protocol before href
- Error toasts use `getErrorMessage()` instead of raw `err?.response?.data?.detail`

---

## Database Tables

### `integrations`

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| organization_id | UUID | FK to organizations |
| provider | VARCHAR | `github`, `gitlab`, `bitbucket`, `jira`, `jenkins` |
| name | VARCHAR | Display name |
| status | VARCHAR | `pending`, `connected`, `error`, `disconnected` |
| external_account_id | VARCHAR | Provider user/account ID |
| external_username | VARCHAR | Provider username |
| external_avatar_url | VARCHAR | Provider avatar URL |
| last_error | TEXT | Last error message (sanitized) |
| jira_cloud_id | VARCHAR | JIRA cloud instance ID |
| jira_site_url | VARCHAR | JIRA site URL |

### `integration_credentials`

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| integration_id | UUID | FK to integrations |
| access_token_encrypted | TEXT | Fernet-encrypted access token |
| refresh_token_encrypted | TEXT | Fernet-encrypted refresh token |
| token_type | VARCHAR | `Bearer` |
| scopes | JSONB | List of granted scopes |
| expires_at | TIMESTAMP | Token expiry time (UTC) |

---

## Error States

| Status | Trigger | User Message | Recovery |
|--------|---------|-------------|----------|
| `pending` | Integration created, awaiting OAuth | "Connecting..." | Complete OAuth flow |
| `connected` | OAuth completed successfully | "Connected as @username" | N/A |
| `error` | OAuth failed (provider error, token exchange, etc.) | "Connection failed" | Retry connection |
| `disconnected` | User disconnected integration | "Not connected" | Reconnect |

---

## Tier Requirements

| Integration Type | Minimum Tier |
|-----------------|-------------|
| Source Control (GitHub, GitLab, Bitbucket) | Growth |
| Issue Tracking (JIRA) | Growth |
| CI/CD (Jenkins) | Growth |

Free tier users see integration options but are prompted to upgrade.

---

## Related Documentation

- [OAuth Integration Pipeline](../pipelines/oauth-integration-pipeline.md) — GCP setup checklist
- [OAuth Provider Setup Playbook](../playbooks/oauth-provider-setup.md) — Step-by-step provider configuration
- [Secrets Management Standards](../standards/secrets-management.md) — Vault and ExternalSecret patterns
- [Domain Management Standards](../standards/domain-management.md) — Callback URL domain configuration
