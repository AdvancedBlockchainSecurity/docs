# OAuth Integration Pipeline

**Last Updated:** February 24, 2026
**API Version:** 0.29.22+

Pipeline for setting up OAuth third-party integrations (GitHub, GitLab, Bitbucket, JIRA, Jenkins) in a new environment. Primarily for GCP deployment but applicable to any environment.

## Overview

```
Environment Setup Pipeline:

1. Create OAuth Apps at each provider
   └─ GitHub, GitLab, Bitbucket, JIRA, Jenkins

2. Store credentials in secret manager
   └─ Vault (local) or GCP Secret Manager (production)

3. Configure ExternalSecret resources
   └─ Map secret paths to Kubernetes secrets

4. Generate + store INTEGRATION_ENCRYPTION_KEY
   └─ Fernet key for AES-128-CBC + HMAC-SHA256 token encryption

5. Set dashboard_base_url
   └─ https://app.blocksecops.com (GCP) or https://app.blocksecops.local (server)

6. Deploy and verify callback endpoints
   └─ /api/v1/oauth/{provider}/callback must be reachable from provider

7. Test full OAuth flow per provider
   └─ Connect, verify tokens stored encrypted, disconnect

8. Verify encrypted token storage
   └─ Confirm tokens are not plaintext in database
```

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Public domain | `app.blocksecops.com` with valid TLS (OAuth providers must reach callback URLs) |
| DNS configured | Domain resolves to GCP Load Balancer |
| API service deployed | v0.29.22+ with OAuth endpoints and security hardening |
| Dashboard deployed | v0.46.4+ with integration UI and frontend security hardening |
| Vault or GCP Secret Manager | For storing OAuth credentials |
| ExternalSecret Operator | For syncing secrets to Kubernetes |

## Step 1: Create OAuth Apps at Each Provider

### GitHub

1. Go to [GitHub Developer Settings > OAuth Apps](https://github.com/settings/developers)
2. Click **New OAuth App**
3. Configure:
   - **Application name:** `BlockSecOps`
   - **Homepage URL:** `https://app.blocksecops.com`
   - **Authorization callback URL:** `https://app.blocksecops.com/api/v1/oauth/github/callback`
4. Save the **Client ID** and generate a **Client Secret**

### GitLab

1. Go to [GitLab Applications](https://gitlab.com/-/user_settings/applications)
2. Click **New application**
3. Configure:
   - **Name:** `BlockSecOps`
   - **Redirect URI:** `https://app.blocksecops.com/api/v1/oauth/gitlab/callback`
   - **Scopes:** `api`, `read_user`, `read_repository`
4. Save the **Application ID** and **Secret**

### Bitbucket

1. Go to [Bitbucket Workspace Settings > OAuth consumers](https://bitbucket.org/workspace/settings/api)
2. Click **Add consumer**
3. Configure:
   - **Name:** `BlockSecOps`
   - **Callback URL:** `https://app.blocksecops.com/api/v1/oauth/bitbucket/callback`
   - **Permissions:** Repository (Read), Pull requests (Read), Webhooks (Read & Write)
4. Save the **Key** (client_id) and **Secret** (client_secret)

### JIRA (Atlassian)

1. Go to [Atlassian Developer Console](https://developer.atlassian.com/console/myapps/)
2. Click **Create** > **OAuth 2.0 integration**
3. Configure:
   - **Name:** `BlockSecOps`
   - **Callback URL:** `https://app.blocksecops.com/api/v1/oauth/jira/callback`
   - **Scopes:** `read:jira-work`, `write:jira-work`, `read:jira-user`, `offline_access`
4. Enable **Authorization code grants** with the callback URL
5. Save the **Client ID** and **Secret**

### Jenkins

Jenkins uses API tokens instead of OAuth. No provider-side app creation is needed. Users configure their Jenkins URL and API token directly in the BlockSecOps UI.

## Step 2: Store Credentials in Secret Manager

### Vault (Server/Local)

```bash
# GitHub
vault kv put secret/blocksecops/api-service/github \
  client_id="gh-XXXX" \
  client_secret="gh-secret-XXXX"

# GitLab
vault kv put secret/blocksecops/api-service/gitlab \
  client_id="gl-XXXX" \
  client_secret="gl-secret-XXXX"

# Bitbucket
vault kv put secret/blocksecops/api-service/bitbucket \
  client_id="bb-XXXX" \
  client_secret="bb-secret-XXXX"

# JIRA
vault kv put secret/blocksecops/api-service/jira \
  client_id="jira-XXXX" \
  client_secret="jira-secret-XXXX"
```

### GCP Secret Manager (Production)

```bash
# Create secrets
echo -n "gh-XXXX" | gcloud secrets create github-client-id --data-file=-
echo -n "gh-secret-XXXX" | gcloud secrets create github-client-secret --data-file=-
# Repeat for each provider...
```

## Step 3: Generate and Store Encryption Key

The `INTEGRATION_ENCRYPTION_KEY` is **required in production**. The API service will fail to start without it.

```bash
# Generate a Fernet key
python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'

# Store in Vault
vault kv put secret/blocksecops/api-service/encryption \
  integration_encryption_key="<generated-key>"

# Or GCP Secret Manager
echo -n "<generated-key>" | gcloud secrets create integration-encryption-key --data-file=-
```

**Verification:** The key must be a valid base64-encoded 32-byte value. Fernet.generate_key() produces this automatically.

## Step 4: Configure ExternalSecret

The ExternalSecret resource maps Vault/GCP Secret Manager paths to Kubernetes secrets. Reference the existing template:

```yaml
# k8s/overlays/local/api-service/externalsecret.yaml (already configured)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  data:
    - secretKey: github_client_id
      remoteRef:
        key: secret/blocksecops/api-service/github
        property: client_id
    - secretKey: github_client_secret
      remoteRef:
        key: secret/blocksecops/api-service/github
        property: client_secret
    # ... similar for gitlab, bitbucket, jira
    - secretKey: integration_encryption_key
      remoteRef:
        key: secret/blocksecops/api-service/encryption
        property: integration_encryption_key
```

**GCP overlay:** Update `k8s/overlays/gcp-production/api-service/externalsecret.yaml` with GCP Secret Manager paths.

## Step 5: Set Dashboard Base URL

The `dashboard_base_url` config determines:
- OAuth callback URLs sent to providers
- Redirect URLs after OAuth completion

```yaml
# k8s/overlays/gcp-production/api-service/configmap-patch.yaml
data:
  dashboard_base_url: "https://app.blocksecops.com"
```

**Critical:** This URL must match the callback URLs registered with each OAuth provider.

## Step 6: Deploy and Verify

```bash
# Apply secrets
kubectl apply -k k8s/overlays/gcp-production/api-service/

# Verify secrets are synced
kubectl get secret api-service-secret -n api-service -o json | \
  jq '.data | keys'
# Should include: github_client_id, github_client_secret, etc.

# Verify API service started (encryption key enforced in production)
kubectl logs -n api-service -l app.kubernetes.io/name=api-service --tail=20

# Test callback endpoint is reachable
curl -s https://app.blocksecops.com/api/v1/oauth/github/callback?code=test&state=test
# Should return redirect (not 404)
```

## Step 7: Test OAuth Flow

For each provider:

1. Log into BlockSecOps dashboard as an org admin
2. Navigate to **Settings > Integrations**
3. Click **Connect** for the provider
4. Complete OAuth authorization at provider
5. Verify redirect back to dashboard with success
6. Check integration shows as "Connected" with username/avatar

## Step 8: Verify Encrypted Storage

```sql
-- Check that tokens are encrypted (not plaintext)
SELECT
  i.provider,
  ic.access_token_encrypted IS NOT NULL AS has_token,
  LEFT(ic.access_token_encrypted, 20) AS token_prefix
FROM integration_credentials ic
JOIN integrations i ON i.id = ic.integration_id;
-- Token prefix should start with 'gAAAAA' (Fernet format)
```

## Callback URL Reference

| Provider | Callback URL |
|----------|-------------|
| GitHub | `https://app.blocksecops.com/api/v1/oauth/github/callback` |
| GitLab | `https://app.blocksecops.com/api/v1/oauth/gitlab/callback` |
| Bitbucket | `https://app.blocksecops.com/api/v1/oauth/bitbucket/callback` |
| JIRA | `https://app.blocksecops.com/api/v1/oauth/jira/callback` |
| Jenkins | `https://app.blocksecops.com/api/v1/oauth/jenkins/callback` |

**Note:** Replace `app.blocksecops.com` with `app.blocksecops.local` for server environment. OAuth will only work on server environment if the providers can reach the callback URL (requires public DNS or tunneling).

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "OAuth is not configured" | Client credentials missing in Vault/secret | Add credentials to secret store, sync ExternalSecret |
| "Failed to securely store credentials" | `INTEGRATION_ENCRYPTION_KEY` missing or invalid | Generate and store a valid Fernet key |
| API service fails to start | Missing encryption key in production | Set `INTEGRATION_ENCRYPTION_KEY` (mandatory in production) |
| Redirect to error page after auth | Callback URL mismatch | Ensure provider callback URL matches `dashboard_base_url` + path |
| "OAuth state has expired" | User took >15 minutes to complete flow | Retry the connection (state JWT has 15-min expiry) |
| Provider returns error | Incorrect scopes or permissions | Verify OAuth app scopes match required scopes |

## Security Checklist

- [ ] All OAuth client secrets stored in Vault/GCP Secret Manager (never in code or ConfigMaps)
- [ ] `INTEGRATION_ENCRYPTION_KEY` generated and stored securely
- [ ] Callback URLs use HTTPS only
- [ ] Rate limiting enabled on callback endpoints (10/minute)
- [ ] Rate limiting enabled on webhook GET endpoints (30/minute) (v0.29.22)
- [ ] State JWT uses HMAC-SHA256 with 15-minute expiry
- [ ] Error messages do not leak internal details or env var names
- [ ] Open redirect protection on dashboard redirect URLs
- [ ] SSRF validation on `repo_url`, JIRA `base_url`, monitoring `webhook_url` (v0.29.22)
- [ ] `error_description` callback parameter capped at 500 chars (v0.29.22)
- [ ] Webhook secrets encrypted at rest with Fernet (v0.29.22)
- [ ] Notification channel webhook URLs masked in API responses (v0.29.22)
- [ ] ExternalSecret entries have no `| default ""` fallbacks (v0.29.22)
- [ ] `SUPABASE_SERVICE_KEY` in ExternalSecret, not ConfigMap (v0.29.22)
- [ ] Frontend `isValidOAuthUrl()` rejects non-allowlisted hosts (v0.46.4)
- [ ] Frontend validates `https://` protocol on avatar/JIRA/marketplace URLs (v0.46.4)

## Files

| File | Description |
|------|-------------|
| `blocksecops-api-service/src/application/services/oauth_service.py` | OAuth flow implementation |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/oauth_callbacks.py` | Callback endpoint handlers |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/integrations.py` | Integration CRUD + OAuth initiation |
| `blocksecops-api-service/src/infrastructure/security/encryption.py` | Fernet encryption service |
| `blocksecops-api-service/src/infrastructure/config.py` | OAuth settings + production validation |
| `k8s/overlays/local/api-service/externalsecret.yaml` | Secret mapping (Vault paths) |
| `k8s/overlays/local/api-service/deployment-patch.yaml` | OAuth env var mapping |

## Related Documentation

- [OAuth Integration Workflow](../workflows/oauth-integration-workflow.md) — End-to-end flow architecture
- [OAuth Provider Setup Playbook](../playbooks/oauth-provider-setup.md) — Step-by-step provider configuration
- [Secrets Management Standards](../standards/secrets-management.md) — Vault and ExternalSecret patterns
