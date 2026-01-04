# Vault Initialization for Local Development

> **Last Updated**: December 20, 2025

## Overview

This guide explains how to initialize HashiCorp Vault with secrets required for local development. Vault is used in conjunction with External Secrets Operator to synchronize secrets into Kubernetes.

## Vault Storage Architecture

For local development, Vault uses **persistent file-based storage** with **auto-unseal**, which means:

1. **Data persists** - Secrets survive pod restarts and cluster reboots (stored on PVC)
2. **Auto-unsealing** - Vault automatically unseals on startup using stored key
3. **One-time initialization** - Run `init-vault-local.sh` only on first setup or after PVC deletion

| Component | Location | Purpose |
|-----------|----------|---------|
| Vault data | `/vault/data` (PVC) | Secrets, policies, auth configuration |
| Init file | `/vault/data/.vault-init.json` | Unseal key and root token |
| Config | `/vault/config/vault.hcl` | Server configuration (file storage) |

External Secrets Operator continuously syncs secrets from Vault to Kubernetes Secrets. Without populated Vault secrets, External Secrets will fail to sync.

## Prerequisites

Before running the Vault initialization script, ensure:

1. **Minikube is running** with all infrastructure deployed
2. **Vault is deployed and ready** in the `vault-local` namespace
3. **External Secrets Operator is installed** and running

Verify Vault status:
```bash
kubectl get pod vault-0 -n vault-local
kubectl exec -n vault-local vault-0 -- vault status
# Should show: Sealed = false, Storage Type = file
```

## Running the Initialization Script

### Location

The Vault initialization script is located at:
```
/Users/pwner/Git/ABS/scripts/init-vault-local.sh
```

### Usage

```bash
# Run from anywhere
/Users/pwner/Git/ABS/scripts/init-vault-local.sh
```

The script will:
1. Verify Vault pod is running and unsealed
2. Populate all required secrets for local services
3. Verify secrets were created successfully
4. Provide next steps for verification

**Note:** The script requires a Vault token to write secrets. For first-time setup, the init container creates the token automatically. For subsequent runs, the script will need the root token from the init file.

### What Gets Populated

The script populates secrets for the following services:

#### Infrastructure Services
- **PostgreSQL** (`secret/postgresql`)
  - Database credentials
  - Replication user credentials

- **Redis** (`secret/redis`)
  - Redis password

#### Application Services
- **API Service** (`secret/local/api-service/*`)
  - JWT secret key
  - Session secret
  - OAuth credentials

- **Data Service** (`secret/local/data-service/*`)
  - Database credentials
  - Redis credentials
  - Encryption key

- **Tool Integration** (`secret/local/tool-integration/*`)
  - Tool credentials
  - Database credentials
  - Redis credentials

- **Notification Service** (`secret/local/notification/*`)
  - Database credentials
  - Redis credentials
  - SMTP configuration
  - Webhook URLs (Slack, Teams)

- **Orchestration Service** (`secret/local/orchestration/*`)
  - Database credentials
  - Redis credentials

- **Intelligence Engine** (`secret/local/intelligence-engine/*`)
  - Database credentials
  - Redis credentials

## Verification

### 1. Check External Secrets Status

After running the initialization script, External Secrets will automatically sync within 15-30 seconds:

```bash
# Check all External Secrets
kubectl get externalsecrets -A

# Expected output - all should show "SecretSynced" and "True"
NAMESPACE                NAME                       STATUS           READY
api-service-local        api-service-secret         SecretSynced     True
orchestration-local      orchestration-secrets      SecretSynced     True
tool-integration-local   tool-integration-secrets   SecretSynced     True
notification-local       notification-secrets       SecretSynced     True
```

### 2. Check Created Kubernetes Secrets

Verify that secrets were created by External Secrets:

```bash
# Check api-service secrets
kubectl get secret api-service-secret -n api-service-local

# Check orchestration secrets
kubectl get secret orchestration-secrets -n orchestration-local

# View secret keys (not values)
kubectl get secret orchestration-secrets -n orchestration-local -o jsonpath='{.data}' | jq 'keys'
```

### 3. Check for Sync Errors

If any External Secrets show errors:

```bash
# Describe the failing ExternalSecret
kubectl describe externalsecret orchestration-secrets -n orchestration-local

# Check SecretStore status
kubectl describe secretstore vault-backend -n orchestration-local

# Check recent events
kubectl get events -n orchestration-local --sort-by='.lastTimestamp' | grep -i external
```

Common sync errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| `invalid role name` | Vault role doesn't exist | Create Kubernetes auth role for the service |
| `could not get secret data from provider` | Vault sealed or secret missing | Check Vault status, re-run init script |
| `SecretStore is not ready` | SecretStore can't authenticate | Check Kubernetes auth configuration |

## When to Re-run the Script

You need to re-run the Vault initialization script:

1. **First-time cluster setup** - Initial secret population
2. **After PVC deletion** - Vault data was wiped
3. **When adding new services** - New services may require additional secrets

**You do NOT need to re-run after:**
- Minikube restart (secrets persist on PVC)
- Vault pod restart (auto-unseals and data persists)
- Daily development (secrets remain in Vault)

## Troubleshooting

### Vault Pod Not Ready

```bash
# Check pod status
kubectl get pod vault-0 -n vault-local

# Check pod logs (init container and main container)
kubectl logs vault-0 -n vault-local -c vault-init
kubectl logs vault-0 -n vault-local -c vault

# If pod doesn't exist, deploy Vault
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/vault/
```

### Vault is Sealed

With the new auto-unseal, Vault should not remain sealed. If it is:

```bash
# Check seal status
kubectl exec -n vault-local vault-0 -- vault status

# If sealed, the init file may be missing or corrupted
# Check if init file exists
kubectl exec -n vault-local vault-0 -- cat /vault/data/.vault-init.json

# If file exists, manually unseal
UNSEAL_KEY=$(kubectl exec -n vault-local vault-0 -- cat /vault/data/.vault-init.json | awk -F'"' '/"unseal_keys_b64"/{getline; print $2}')
kubectl exec -n vault-local vault-0 -- vault operator unseal "$UNSEAL_KEY"

# If init file is missing, delete PVC and restart Vault
kubectl delete pvc vault-data-vault-0 -n vault-local
kubectl delete pod vault-0 -n vault-local
# Wait for Vault to reinitialize
```

### External Secrets Not Syncing

```bash
# Check External Secrets Operator is running
kubectl get pods -n external-secrets-local

# Check SecretStore configuration and status
kubectl get secretstore -A
kubectl describe secretstore vault-backend -n orchestration-local

# Check if Vault Kubernetes auth role exists
ROOT_TOKEN=$(kubectl exec -n vault-local vault-0 -- cat /vault/data/.vault-init.json | awk -F'"' '/"root_token"/{print $4}')
kubectl exec -n vault-local vault-0 -- env VAULT_TOKEN="$ROOT_TOKEN" vault list auth/kubernetes/role/
```

### Missing Vault Kubernetes Role

Each service namespace needs a corresponding Vault role:

```bash
# Get root token
ROOT_TOKEN=$(kubectl exec -n vault-local vault-0 -- cat /vault/data/.vault-init.json | awk -F'"' '/"root_token"/{print $4}')

# Create role for service (example: orchestration)
kubectl exec -n vault-local vault-0 -- env VAULT_TOKEN="$ROOT_TOKEN" vault write auth/kubernetes/role/orchestration \
  bound_service_account_names="orchestration" \
  bound_service_account_namespaces="orchestration-local" \
  policies=external-secrets \
  ttl=1h
```

## Path Structure Reference

All secrets follow a standardized path structure. Understanding this is crucial for debugging:

### Vault KV v2 Path Handling

**IMPORTANT:** Vault KV v2 uses `/data/` internally, but External Secrets Operator with `version: v2` handles this automatically.

| Action | Path Format |
|--------|-------------|
| **CLI write** | `vault kv put secret/local/api-service/jwt ...` |
| **CLI read** | `vault kv get secret/local/api-service/jwt` |
| **ExternalSecret key** | `secret/local/api-service/jwt` (NO `/data/`!) |
| **Internal Vault path** | `secret/data/local/api-service/jwt` |

### Standard Path Structure

```
secret/
├── postgresql              # Shared PostgreSQL credentials
├── redis                   # Shared Redis credentials
└── local/                  # Environment-specific (local)
    ├── api-service/
    │   ├── jwt/
    │   ├── session/
    │   └── oauth/
    ├── orchestration/
    │   ├── database/
    │   └── redis/
    ├── intelligence-engine/
    │   ├── database/
    │   ├── redis/
    │   ├── ml/
    │   └── api/
    ├── data-service/
    │   ├── database/
    │   ├── database-read/
    │   ├── redis/
    │   └── encryption/
    ├── notification/
    │   ├── database/
    │   ├── redis/
    │   ├── smtp/
    │   └── webhooks/
    └── tool-integration/
        ├── credentials/
        ├── database/
        └── redis/
```

### Common Mistakes

```yaml
# WRONG: Including /data/ in ExternalSecret path
remoteRef:
  key: secret/data/local/api-service/jwt  # Don't do this!

# CORRECT: Let ESO handle the /data/ prefix
remoteRef:
  key: secret/local/api-service/jwt

# WRONG: Using ?ssl=disable in DATABASE_URL
DATABASE_URL: "postgresql+asyncpg://...?ssl=disable"  # Invalid for asyncpg/psycopg2

# CORRECT: No SSL parameter for local development
DATABASE_URL: "postgresql+asyncpg://postgres:postgres@postgresql.postgresql-local.svc.cluster.local:5432/solidity_security"
```

## Security Notes

### Development vs Production

**IMPORTANT**: The secrets populated by this script are for **LOCAL DEVELOPMENT ONLY**.

| Aspect | Local Development | Production |
|--------|------------------|------------|
| **Vault Storage** | File (PVC) | Raft with HA |
| **Secrets** | Hardcoded in script | Managed via CI/CD or Vault UI |
| **Auto-unseal** | Init file on PVC | Cloud KMS auto-unseal |
| **TLS** | Disabled | Required |
| **Authentication** | Kubernetes auth | AppRole, Kubernetes auth, etc. |
| **Persistence** | PVC (survives restarts) | Raft replication |

### Local Development Secrets

All secrets in the initialization script use predictable values like:
- PostgreSQL password: `postgres`
- Redis password: `redis123`
- JWT secret: `local-dev-jwt-secret-key-change-in-production`

**These should NEVER be used in production environments.**

## Integration with Development Workflow

### Initial Setup (First Time Only)

```bash
# 1. Start Minikube
minikube start

# 2. Deploy all infrastructure (including Vault)
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/vault/

# 3. Wait for Vault to initialize and unseal automatically
kubectl wait --for=condition=ready pod/vault-0 -n vault-local --timeout=120s

# 4. Initialize Vault secrets
/Users/pwner/Git/ABS/scripts/init-vault-local.sh

# 5. Verify External Secrets synced
kubectl get externalsecrets -A
```

### After Minikube Restart

```bash
# 1. Start Minikube (all pods restart automatically)
minikube start

# 2. Wait for Vault to auto-unseal
kubectl wait --for=condition=ready pod/vault-0 -n vault-local --timeout=120s

# 3. Verify Vault is unsealed
kubectl exec -n vault-local vault-0 -- vault status
# Should show: Sealed = false

# 4. Secrets are already present - no init script needed!
kubectl get externalsecrets -A
```

### Daily Development

External Secrets will continuously sync as long as:
1. Vault pod is running and unsealed
2. Secrets exist in Vault (persisted on PVC)
3. External Secrets Operator is running

**You typically don't need to re-run the initialization script after the initial setup.**

## Related Documentation

- [Secrets Management Standards](/Users/pwner/Git/ABS/docs/standards/secrets-management.md) - Vault and ESO standards
- [Vault Setup Quickstart](/Users/pwner/Git/ABS/docs/VAULT-SETUP-QUICKSTART.md) - Quick reference
- [Production vs Local Differences](./production-differences.md) - Security and configuration differences
- [Deployment Verification](./deployment-verification.md) - Verifying service health

## Script Source

The initialization script source code is available at:
```
/Users/pwner/Git/ABS/scripts/init-vault-local.sh
```

The script is idempotent - it can be run multiple times safely and will overwrite existing secrets with the same values.
