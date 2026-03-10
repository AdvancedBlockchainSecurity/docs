# Playbook: Vault Secret Management

**Version:** 1.0.0
**Last Updated:** February 24, 2026
**Audience:** Platform Operator | Developer

## Overview

Manage secrets in HashiCorp Vault for the Apogee local development cluster. Vault stores all sensitive configuration consumed by services via the External Secrets Operator (ESO).

> **Environment Note:** This playbook covers **local development** (HashiCorp Vault). For **GCP production**, secrets are managed via GCP Secret Manager with ExternalSecrets Operator. See the [GCP Secrets Playbook](gcp-secret-management.md).

---

## Prerequisites

- [ ] `kubectl` access to `vault-local` namespace
- [ ] Vault pod running and unsealed
- [ ] Vault root token available (see below)

---

## Getting the Vault Root Token

The root token is stored inside the Vault pod at `/vault/data/.vault-init.json`, written by the init container during `vault operator init`:

```bash
# Extract root token
kubectl exec -n vault-local vault-0 -- \
  awk -F'"' '/root_token/{print $4}' /vault/data/.vault-init.json
```

Store the token for the session:

```bash
export VAULT_TOKEN=$(kubectl exec -n vault-local vault-0 -- \
  awk -F'"' '/root_token/{print $4}' /vault/data/.vault-init.json)
```

---

## Reading Secrets

```bash
# Read a secret
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv get secret/local/api-service/jwt

# Read a specific field
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv get -field=secret_key secret/local/api-service/jwt
```

---

## Writing Secrets

```bash
# Write a new secret
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv put secret/local/api-service/example \
  key1="value1" key2="value2"
```

After writing, ExternalSecret will auto-sync within 15s (the configured `refreshInterval`).

---

## Bulk Initialization

Use the init script for fresh clusters or to reseed all secrets:

```bash
./docs/scripts/init-vault-local.sh
```

The script seeds all required vault paths for all services and verifies each path exists.

---

## Adding a New Secret Path

When adding a new secret that a service needs:

1. **Add the vault path to `init-vault-local.sh`** — Include it in the appropriate service section with placeholder values
2. **Add it to the verification list** — Update the `SECRET_PATHS` array at the end of the script
3. **Update the ExternalSecret spec** — Add a `data` entry mapping the vault path to a template variable
4. **Update the ExternalSecret template** — Add the environment variable that uses the template variable
5. **Seed the secret in Vault** — Run the `vault kv put` command or rerun the init script
6. **Verify sync** — Check ExternalSecret status:
   ```bash
   kubectl get externalsecret -n <namespace>
   ```

---

## API Service Vault Paths

All paths under `secret/local/api-service/`:

| Path | Keys | Purpose |
|------|------|---------|
| `jwt` | secret_key | JWT signing key |
| `session` | secret | Session encryption |
| `oauth/github` | client_id, client_secret | GitHub OAuth |
| `oauth/gitlab` | client_id, client_secret | GitLab OAuth |
| `oauth/bitbucket` | client_id, client_secret | Bitbucket OAuth |
| `oauth/jira` | client_id, client_secret | JIRA OAuth |
| `encryption` | key | MFA secrets, OAuth token encryption |
| `internal` | service_key | Service-to-service auth (X-Internal-Service-Key) |
| `supabase` | anon_key, service_key | Supabase credentials |
| `stripe` | api_key, webhook_secret | Stripe billing |
| `jira` | base_url, api_email, api_token, project_key | JIRA support integration |
| `anthropic` | api_key | Claude AI features |

Shared infrastructure paths:

| Path | Keys | Purpose |
|------|------|---------|
| `secret/postgresql` | POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD | Database credentials |
| `secret/redis` | password | Redis password |

---

## Troubleshooting

### ExternalSecret shows SecretSyncedError

1. Check which key is failing:
   ```bash
   kubectl describe externalsecret -n <namespace> <name> | grep "error processing"
   ```

2. Verify the vault path exists:
   ```bash
   kubectl exec -n vault-local vault-0 -- \
     env VAULT_TOKEN="$VAULT_TOKEN" vault kv get <path>
   ```

3. If the path is missing, seed it and wait 15s for ESO to retry.

4. If ESO is stuck, delete and recreate the ExternalSecret to force a fresh sync:
   ```bash
   kubectl delete externalsecret -n <namespace> <name>
   kubectl apply -k k8s/overlays/local/<service>/
   ```

### Permission denied

Ensure you're using the root token, not an empty or expired token:

```bash
# Verify token works
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault token lookup
```

### Vault is sealed

```bash
# Check seal status
kubectl exec -n vault-local vault-0 -- vault status -format=json | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('sealed' if d['sealed'] else 'unsealed')"

# If sealed, the init container should auto-unseal on pod restart
kubectl delete pod -n vault-local vault-0
```

---

## Related

- [Secrets Management Standards](../standards/secrets-management.md)
- [Deduplication Maintenance](deduplication-maintenance.md) — uses CELERY_BROKER_URL from Vault
- Init script: `docs/scripts/init-vault-local.sh`
