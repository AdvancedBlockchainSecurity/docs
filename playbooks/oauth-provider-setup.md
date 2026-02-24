# Playbook: OAuth Provider Setup

**Version:** 1.0.0
**Last Updated:** February 24, 2026
**Audience:** Platform Administrator | DevOps

## Overview

This playbook guides you through configuring OAuth providers for BlockSecOps third-party integrations. Each provider requires creating an OAuth application, storing credentials in Vault/GCP Secret Manager, and verifying the connection.

---

## Prerequisites

- [ ] BlockSecOps API service v0.29.19+ deployed
- [ ] BlockSecOps dashboard v0.46.2+ deployed
- [ ] Public domain with valid TLS (e.g., `app.blocksecops.com`)
- [ ] Access to Vault or GCP Secret Manager
- [ ] ExternalSecret Operator configured
- [ ] `INTEGRATION_ENCRYPTION_KEY` generated and stored (see Step 0)

---

## Step 0: Generate Encryption Key

Before any provider setup, ensure the encryption key exists. This is **mandatory in production** — the API service will refuse to start without it.

```bash
# Generate a Fernet key
python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'
# Output: something like dGhpcyBpcyBhIHRlc3Qga2V5IGZvcg==...

# Store in Vault
vault kv put secret/blocksecops/api-service/encryption \
  integration_encryption_key="<generated-key>"
```

**Verify:** After deploying, check API service logs for `"Encryption service initialized successfully"`.

---

## GitHub OAuth App Setup

### Create the OAuth App

1. Navigate to **GitHub > Settings > Developer settings > OAuth Apps**
   - URL: `https://github.com/settings/developers`
   - For organization apps: `https://github.com/organizations/{org}/settings/applications`

2. Click **New OAuth App**

3. Fill in the form:
   | Field | Value |
   |-------|-------|
   | Application name | `BlockSecOps` |
   | Homepage URL | `https://app.blocksecops.com` |
   | Application description | `Smart contract security platform` |
   | Authorization callback URL | `https://app.blocksecops.com/api/v1/oauth/github/callback` |

4. Click **Register application**

5. Copy the **Client ID** (displayed immediately)

6. Click **Generate a new client secret** and copy it immediately (shown once)

### Store Credentials

```bash
# Vault
vault kv put secret/blocksecops/api-service/github \
  client_id="Iv1.abc123def456" \
  client_secret="ghsecret_xxxxxxxxxxxx"

# GCP Secret Manager
echo -n "Iv1.abc123def456" | gcloud secrets create github-client-id --data-file=-
echo -n "ghsecret_xxxxxxxxxxxx" | gcloud secrets create github-client-secret --data-file=-
```

### Scopes Requested

| Scope | Purpose |
|-------|---------|
| `repo` | Access private repositories for scanning |
| `read:org` | Read organization membership |
| `read:user` | Read user profile information |

### Verify

1. Log into BlockSecOps as an org admin
2. Go to **Settings > Integrations > Source Control**
3. Click **Connect GitHub**
4. Authorize at GitHub
5. Verify dashboard shows "Connected as @username" with avatar

---

## GitLab Application Setup

### Create the Application

1. Navigate to **GitLab > Preferences > Applications**
   - URL: `https://gitlab.com/-/user_settings/applications`
   - For group apps: **Group > Settings > Applications**

2. Click **New application**

3. Fill in the form:
   | Field | Value |
   |-------|-------|
   | Name | `BlockSecOps` |
   | Redirect URI | `https://app.blocksecops.com/api/v1/oauth/gitlab/callback` |
   | Confidential | Yes (checked) |
   | Scopes | `api`, `read_user`, `read_repository` |

4. Click **Save application**

5. Copy the **Application ID** and **Secret**

### Store Credentials

```bash
# Vault
vault kv put secret/blocksecops/api-service/gitlab \
  client_id="app-id-xxxx" \
  client_secret="gl-secret-xxxx"
```

### Scopes Requested

| Scope | Purpose |
|-------|---------|
| `api` | Full API access for repository operations |
| `read_user` | Read user profile |
| `read_repository` | Read repository contents for scanning |

### Self-Hosted GitLab

For self-hosted GitLab instances, the OAuth URLs change:

| Setting | Value |
|---------|-------|
| Authorize URL | `https://gitlab.example.com/oauth/authorize` |
| Token URL | `https://gitlab.example.com/oauth/token` |
| API Base | `https://gitlab.example.com/api/v4` |

Currently, the API service hardcodes `gitlab.com` URLs. Self-hosted GitLab support requires configuration changes.

---

## Bitbucket OAuth Consumer Setup

### Create the OAuth Consumer

1. Navigate to **Bitbucket > Workspace settings > OAuth consumers**
   - URL: `https://bitbucket.org/{workspace}/workspace/settings/api`

2. Click **Add consumer**

3. Fill in the form:
   | Field | Value |
   |-------|-------|
   | Name | `BlockSecOps` |
   | Callback URL | `https://app.blocksecops.com/api/v1/oauth/bitbucket/callback` |
   | This is a private consumer | Yes (checked) |
   | Permissions | Repository: Read, Pull requests: Read, Webhooks: Read and Write |

4. Click **Save**

5. Copy the **Key** (client_id) and **Secret** (client_secret)

### Store Credentials

```bash
# Vault
vault kv put secret/blocksecops/api-service/bitbucket \
  client_id="consumer-key-xxxx" \
  client_secret="consumer-secret-xxxx"
```

### Auth Note

Bitbucket uses HTTP Basic Authentication for the token exchange (client_id:client_secret as username:password), unlike GitHub/GitLab which use POST body parameters. The API service handles this automatically.

### Scopes Requested

| Scope | Purpose |
|-------|---------|
| `repository` | Read repository contents for scanning |
| `pullrequest` | Read/create pull requests for findings |
| `webhook` | Manage webhooks for CI/CD triggers |

---

## JIRA (Atlassian) OAuth 2.0 Setup

### Create the OAuth 2.0 Integration

1. Navigate to **Atlassian Developer Console**
   - URL: `https://developer.atlassian.com/console/myapps/`

2. Click **Create** > **OAuth 2.0 integration**

3. Fill in the form:
   | Field | Value |
   |-------|-------|
   | Name | `BlockSecOps` |

4. Go to **Permissions** tab and add:
   - **Jira API**: `read:jira-work`, `write:jira-work`, `read:jira-user`

5. Go to **Authorization** tab:
   - Click **Add** next to **OAuth 2.0 (3LO)**
   - Callback URL: `https://app.blocksecops.com/api/v1/oauth/jira/callback`

6. Go to **Settings** tab:
   - Copy the **Client ID** and **Secret**

### Store Credentials

```bash
# Vault
vault kv put secret/blocksecops/api-service/jira \
  client_id="jira-client-id-xxxx" \
  client_secret="jira-secret-xxxx"
```

### Scopes Requested

| Scope | Purpose |
|-------|---------|
| `read:jira-work` | Read issues and projects |
| `write:jira-work` | Create/update issues from findings |
| `read:jira-user` | Read user profile |
| `offline_access` | Obtain refresh token for long-lived access |

### JIRA-Specific Flow

JIRA has additional steps compared to other providers:

1. **Authorization** requires `audience=api.atlassian.com` and `prompt=consent`
2. After token exchange, the API fetches **accessible resources** to get `cloud_id` and `site_url`
3. `cloud_id` is stored on the integration record for scoping API calls to the correct JIRA instance
4. Users with multiple JIRA sites will be connected to the first accessible site

---

## Jenkins API Token Setup

Jenkins does not use OAuth. Instead, users provide their Jenkins URL and API token directly in the BlockSecOps UI.

### User-Side Setup

1. Log into Jenkins as the user who will connect
2. Navigate to **User > Configure** (or `/me/configure`)
3. Under **API Token**, click **Add new Token**
4. Name it `BlockSecOps` and click **Generate**
5. Copy the token immediately (shown once)

### In BlockSecOps

1. Go to **Settings > Integrations > CI/CD**
2. Click **Connect Jenkins**
3. Enter:
   | Field | Value |
   |-------|-------|
   | Jenkins URL | `https://jenkins.example.com` |
   | Username | Jenkins username |
   | API Token | Token from step above |

4. Click **Connect**

### URL Validation

The Jenkins URL is validated to:
- Use HTTPS protocol (HTTP rejected)
- Be a valid URL format

### No Vault Credentials Needed

Jenkins does not need OAuth client credentials in Vault. The user's API token is encrypted and stored directly via the standard integration credential flow.

---

## Vault Secret Paths Reference

| Secret | Vault Path | ExternalSecret Key |
|--------|------------|--------------------|
| GitHub Client ID | `secret/blocksecops/api-service/github:client_id` | `github_client_id` |
| GitHub Client Secret | `secret/blocksecops/api-service/github:client_secret` | `github_client_secret` |
| GitLab Client ID | `secret/blocksecops/api-service/gitlab:client_id` | `gitlab_client_id` |
| GitLab Client Secret | `secret/blocksecops/api-service/gitlab:client_secret` | `gitlab_client_secret` |
| Bitbucket Client ID | `secret/blocksecops/api-service/bitbucket:client_id` | `bitbucket_client_id` |
| Bitbucket Client Secret | `secret/blocksecops/api-service/bitbucket:client_secret` | `bitbucket_client_secret` |
| JIRA Client ID | `secret/blocksecops/api-service/jira:client_id` | `jira_client_id` |
| JIRA Client Secret | `secret/blocksecops/api-service/jira:client_secret` | `jira_client_secret` |
| Encryption Key | `secret/blocksecops/api-service/encryption:integration_encryption_key` | `integration_encryption_key` |

---

## Environment-Specific Callback URLs

| Environment | Base URL | Example Callback |
|-------------|----------|-----------------|
| Server (local) | `https://app.blocksecops.local` | `https://app.blocksecops.local/api/v1/oauth/github/callback` |
| Production (GCP) | `https://app.blocksecops.com` | `https://app.blocksecops.com/api/v1/oauth/github/callback` |

**Important:** OAuth providers must be able to reach the callback URL. This means:
- **Server environment** only works if the domain is publicly accessible (e.g., via tunnel)
- **GCP production** works natively with public DNS

When switching environments, update the callback URL at each provider.

---

## Troubleshooting

### "Failed to initiate GitHub Connection"

**Cause:** OAuth client credentials are missing or empty.

**Fix:**
1. Check if credentials exist in Vault:
   ```bash
   vault kv get secret/blocksecops/api-service/github
   ```
2. Check if ExternalSecret synced:
   ```bash
   kubectl get externalsecret -n api-service-local
   kubectl get secret api-service-secret -n api-service-local -o json | jq '.data | keys'
   ```
3. Check API service logs:
   ```bash
   kubectl logs -n api-service-local -l app.kubernetes.io/name=api-service | grep -i oauth
   ```

### "OAuth state has expired"

**Cause:** User took more than 15 minutes between clicking Connect and completing authorization.

**Fix:** Click Connect again to start a new flow.

### "Provider mismatch"

**Cause:** The state JWT was generated for a different provider than the callback endpoint received.

**Fix:** This indicates a configuration error or manipulation attempt. Check that provider-specific callback URLs are correctly registered.

### Redirect loop or blank page after authorization

**Cause:** `dashboard_base_url` doesn't match the domain the user is accessing.

**Fix:**
```bash
# Check current value
kubectl get configmap -n api-service-local api-service-config -o jsonpath='{.data.dashboard_base_url}'

# Must match the domain in the browser URL bar
```

### "Failed to securely store credentials"

**Cause:** `INTEGRATION_ENCRYPTION_KEY` is missing or invalid.

**Fix:**
```bash
# Check if key is set
kubectl exec -n api-service-local deployment/api-service -- env | grep INTEGRATION_ENCRYPTION_KEY

# Generate and store if missing
python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'
vault kv put secret/blocksecops/api-service/encryption integration_encryption_key="<key>"

# Restart to pick up new secret
kubectl rollout restart deployment/api-service -n api-service-local
```

### Token expired / integration stopped working

**Cause:** Access token expired and no automatic refresh is configured.

**Fix:** Disconnect and reconnect the integration to obtain fresh tokens. A future release will add automatic token refresh.

---

## Related Documentation

- [OAuth Integration Pipeline](../pipelines/oauth-integration-pipeline.md) — Full GCP setup checklist
- [OAuth Integration Workflow](../workflows/oauth-integration-workflow.md) — End-to-end architecture
- [Secrets Management Standards](../standards/secrets-management.md) — Vault and ExternalSecret patterns
