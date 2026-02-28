# Secrets Management

**Part of:** [Platform Development Standards](./INDEX.md)
**Version:** 3.0.0
**Last Updated:** February 27, 2026
**Status:** Active

## Overview

This document defines mandatory standards for managing secrets in the Apogee Platform using the External Secrets Operator (ESO) with environment-specific secret backends.

---

## Rule: Centralized Secret Store with External Secrets Operator

**MANDATORY:** All secrets MUST be stored in a centralized secret backend and synchronized to Kubernetes using the External Secrets Operator (ESO).

| Environment | Secret Backend | SecretStore Type |
|-------------|----------------|------------------|
| Local (kubeadm) | HashiCorp Vault | SecretStore (`vault-backend`) |
| GCP (alpha/production) | GCP Secret Manager | ClusterSecretStore (`gcp-secret-manager`) |

**Why this matters:**
- **Security:** Centralized secret storage with encryption at rest and in transit
- **Auditability:** Complete audit trail of secret access and modifications
- **Rotation:** Automated secret rotation capabilities
- **Separation of Concerns:** Secrets managed separately from application code and Kubernetes manifests
- **Multi-Environment:** Single source of truth for secrets across all environments

## GCP Secret Manager (GCP Environments)

### Architecture

```
GCP Secret Manager (prefix: blocksecops-gcp-*)
    │
    │  Workload Identity (GCP SA → K8s SA)
    ▼
ExternalSecrets Operator (Helm-installed)
    │
    │  ClusterSecretStore (gcp-secret-manager)
    ▼
ExternalSecret (per service namespace) → creates K8s Secret
    │
    │  envFrom.secretRef
    ▼
Service Pod (env vars injected automatically)
```

### GCP Secret Manager Key Naming

All secrets use the prefix `blocksecops-gcp-`:

| GCP SM Key | Used By |
|---|---|
| `blocksecops-gcp-database-url` | api-service, data-service, orchestration, intelligence-engine |
| `blocksecops-gcp-redis-url` | All backend services |
| `blocksecops-gcp-jwt-secret` | api-service |
| `blocksecops-gcp-supabase-url` | api-service |
| `blocksecops-gcp-supabase-key` | api-service |
| `blocksecops-gcp-stripe-api-key` | api-service |
| `blocksecops-gcp-stripe-webhook-secret` | api-service |
| `blocksecops-gcp-openai-api-key` | intelligence-engine |
| `blocksecops-gcp-api-service-url` | orchestration, admin-portal, tool-integration |
| `blocksecops-gcp-smtp-host` | notification |
| `blocksecops-gcp-smtp-password` | notification |

### GCP ExternalSecret Example

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-service-secrets
  namespace: api-service-gcp
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-secret-manager
  target:
    name: api-service-secrets
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: blocksecops-gcp-database-url
    - secretKey: REDIS_URL
      remoteRef:
        key: blocksecops-gcp-redis-url
```

### Populating GCP Secrets

```bash
# Use the populate-secrets.sh script
cd blocksecops-gcp-infrastructure/scripts/
./populate-secrets.sh --interactive   # Interactive prompts
./populate-secrets.sh --verify        # Verify all secrets exist
./populate-secrets.sh --list          # List status of all secrets
```

### GCP Workload Identity for ESO

ESO authenticates to GCP Secret Manager via Workload Identity — no API keys needed:

```yaml
# ClusterSecretStore (k8s/overlays/gcp/external-secrets/clustersecretstore.yaml)
spec:
  provider:
    gcpsm:
      projectID: "project-8a2657b9-d96c-4c0a-a69"
      auth:
        workloadIdentity:
          clusterLocation: us-west1
          clusterName: blocksecops-gcp-gke
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets-gcp
```

The Terraform `secret-manager` module creates the GCP service account and Workload Identity binding automatically.

## HashiCorp Vault (Local Environment)

## What Must Be in Vault

**ALL of the following MUST be stored in Vault:**

1. **Database Credentials**
   - PostgreSQL passwords
   - Redis passwords
   - Database connection strings

2. **API Keys and Tokens**
   - Third-party service API keys
   - OAuth client secrets
   - JWT signing keys
   - Service-to-service authentication tokens

3. **TLS/SSL Certificates**
   - Private keys for TLS certificates
   - Certificate authority keys

4. **Application Secrets**
   - Encryption keys
   - Session secrets
   - Password hashing salts

## What Must NOT Be in Git

**NEVER commit the following to Git:**

❌ Actual secret values in Kubernetes Secret manifests
❌ Passwords or API keys in ConfigMaps
❌ Credentials in `.env` files (use `.env.example` instead)
❌ Private keys or certificates
❌ Database connection strings with passwords

## External Secrets Operator Configuration

**Kubernetes manifests MUST reference secrets via ExternalSecret resources:**

### Vault Path Structure (KV v2)

For Vault KV v2 with External Secrets Operator configured with `version: v2`:

| Environment | Path Pattern | Example |
|-------------|--------------|---------|
| Local | `secret/local/<service>/<secret-type>` | `secret/local/api-service/jwt` |
| Staging | `secret/staging/<service>/<secret-type>` | `secret/staging/api-service/jwt` |
| Production | `secret/production/<service>/<secret-type>` | `secret/production/api-service/jwt` |
| Shared | `secret/<resource>` | `secret/postgresql`, `secret/redis` |

**IMPORTANT:** Do NOT include `/data/` in ExternalSecret paths. The External Secrets Operator with `version: v2` handles this automatically.

```yaml
# ✅ CORRECT: ExternalSecret resource referencing Vault (KV v2)
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: api-service-secret
  namespace: api-service-local
spec:
  refreshInterval: 30s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore  # or ClusterSecretStore
  target:
    name: api-service-secret
    creationPolicy: Owner
  data:
    # Service-specific secrets
    - secretKey: jwt_secret
      remoteRef:
        key: secret/local/api-service/jwt    # ✅ No /data/ prefix
        property: secret_key
    # Shared infrastructure secrets
    - secretKey: database_password
      remoteRef:
        key: secret/postgresql               # ✅ Shared secret path
        property: POSTGRES_PASSWORD
```

```yaml
# ❌ INCORRECT: Using /data/ in path (ESO handles this automatically)
  data:
    - secretKey: jwt_secret
      remoteRef:
        key: secret/data/local/api-service/jwt  # ❌ Don't include /data/
        property: secret_key
```

```yaml
# ❌ INCORRECT: Hardcoded secrets in manifest
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
type: Opaque
stringData:
  password: "my-secret-password"  # NEVER DO THIS
  username: "postgres"
```

## Workflow for Managing Secrets

### Adding a New Secret

```bash
# 1. Store secret in Vault (use environment-specific path)
# For local development:
kubectl exec -n vault-local vault-0 -- vault kv put secret/local/api-service/new-api-key \
  api_key="your-secret-value"

# 2. Create ExternalSecret manifest in the service's overlay
cd /Users/pwner/Git/ABS/blocksecops-api-service/k8s/overlays/local/api-service
cat > externalsecret-new-api-key.yaml <<EOF
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: new-api-key
  namespace: api-service-local
spec:
  refreshInterval: 30s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: new-api-key
    creationPolicy: Owner
  data:
    - secretKey: api_key
      remoteRef:
        key: secret/local/api-service/new-api-key  # No /data/ prefix!
        property: api_key
EOF

# 3. Update kustomization.yaml to include the new resource
# Add to resources: section: - externalsecret-new-api-key.yaml

# 4. Commit the ExternalSecret manifest
git add externalsecret-new-api-key.yaml kustomization.yaml
git commit -m "Add ExternalSecret for new API key

- References Vault path: secret/local/api-service/new-api-key
- Auto-syncs every 30 seconds
- Creates Kubernetes Secret: new-api-key

Refs: #789"

# 5. Apply the kustomization
kubectl apply -k .

# 6. Verify secret was created
kubectl get secret new-api-key -n api-service-local
kubectl get externalsecret new-api-key -n api-service-local
```

### Rotating a Secret

```bash
# 1. Update secret in Vault (use environment-specific path)
kubectl exec -n vault-local vault-0 -- vault kv put secret/local/api-service/database \
  password="new-rotated-password"

# 2. Wait for External Secrets Operator to sync (or force sync)
kubectl annotate externalsecret api-service-secrets \
  force-sync=$(date +%s) -n api-service-local --overwrite

# 3. Restart pods to pick up new secret
kubectl rollout restart deployment api-service -n api-service-local

# 4. Verify new secret is in use
kubectl logs -n api-service-local deployment/api-service | grep "Database connected"
```

### Emergency Secret Revocation

```bash
# 1. Delete secret from Vault immediately
vault kv delete secret/api-service/compromised-key

# 2. Delete ExternalSecret to stop sync attempts
kubectl delete externalsecret compromised-key -n api-service-local

# 3. Delete resulting Kubernetes Secret
kubectl delete secret compromised-key -n api-service-local

# 4. Restart affected pods
kubectl rollout restart deployment api-service -n api-service-local

# 5. Document the incident
echo "SECURITY INCIDENT: Revoked compromised-key at $(date)" >> SECURITY.log

# 6. Update codebase to remove references
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/api-service
git rm externalsecret-compromised-key.yaml
git commit -m "SECURITY: Revoke compromised API key

Incident: [Brief description]
Date: $(date)
Action: Secret revoked and removed from all environments"
```

## Local Development Considerations

**For local development environments:**

1. **Vault uses persistent file storage** with auto-unseal - secrets persist across cluster restarts
2. **Never use production secrets** in local development
3. **Document local secret requirements** in `.env.example`
4. **Provide setup scripts** to initialize local Vault with development secrets
5. **Initial setup required once** - after first initialization, secrets persist on the PVC

### Vault Storage Configuration

| Environment | Storage Backend | Persistence | Auto-Unseal |
|-------------|-----------------|-------------|-------------|
| Local | File (PVC) | ✅ Persists across restarts | ✅ Automatic |
| Staging | Raft | ✅ Persists | Manual |
| Production | Raft with HA | ✅ Persists | Auto-unseal via KMS |

**Local Vault Behavior:**
- Vault data stored on PVC at `/vault/data`
- Unseal key and root token stored in `/vault/data/.vault-init.json`
- Auto-unseals on pod restart using stored key
- Run `init-vault-local.sh` only for initial setup or after PVC deletion

### Standard Local Secret Structure

All local development secrets follow this standardized structure:

```
secret/
├── postgresql                    # Shared PostgreSQL credentials
│   ├── POSTGRES_DB
│   ├── POSTGRES_USER
│   └── POSTGRES_PASSWORD
├── redis                         # Shared Redis credentials
│   └── password
├── harbor                        # Harbor registry
│   ├── secretKey
│   └── HARBOR_ADMIN_PASSWORD
└── local/                        # Environment-specific secrets
    ├── api-service/
    │   ├── jwt/                  # JWT configuration
    │   │   └── secret_key
    │   ├── session/              # Session configuration
    │   │   └── secret
    │   ├── oauth/                # OAuth configuration
    │   │   ├── client_id
    │   │   └── client_secret
    │   ├── stripe/               # Stripe Billing (Phase 8a)
    │   │   ├── api_key           # sk_test_... or sk_live_...
    │   │   └── webhook_secret    # whsec_...
    │   ├── supabase/             # Supabase Auth
    │   │   └── anon_key
    │   ├── encryption/           # MFA/OAuth token encryption
    │   │   └── key
    │   └── database/             # Database URL
    │       └── url
    ├── orchestration/
    │   ├── database/             # Database credentials
    │   │   ├── host, port, name
    │   │   ├── username, password
    │   └── redis/                # Redis credentials
    │       ├── host, port
    │       └── password
    ├── intelligence-engine/
    │   ├── database/             # Database URL
    │   │   └── url
    │   ├── redis/                # Redis URL
    │   │   └── url
    │   ├── ml/                   # ML model API
    │   │   └── api_key
    │   └── api/                  # API service URL
    │       └── url
    ├── data-service/
    │   ├── database/             # Primary database
    │   ├── database-read/        # Read replica
    │   ├── redis/
    │   └── encryption/
    │       └── key
    ├── notification/
    │   ├── database/
    │   ├── redis/
    │   ├── smtp/                 # SMTP configuration
    │   │   ├── host, port
    │   │   ├── user, password
    │   └── webhooks/             # Webhook URLs
    │       ├── slack_url, teams_url, discord_url
    │       └── webhook_secret
    └── tool-integration/
        ├── credentials/          # Tool credentials
        │   └── credentials
        ├── database/
        └── redis/
```

### Standard Passwords (Local Development Only)

| Secret | Value | Notes |
|--------|-------|-------|
| PostgreSQL | `postgres` | All services use same credentials |
| Redis | `blocksecops-redis-password` | Standardized across all services |
| JWT Secret | `local-dev-jwt-secret-key-change-in-production` | |
| Session Secret | `local-dev-session-secret-change-in-production` | |

**⚠️ NEVER use these values in production!**

**Example local Vault setup:**

```bash
# Initialize Vault secrets for local development
# Run: kubectl exec -n vault-local vault-0 -- sh -c '<commands>'

# Shared secrets
vault kv put secret/postgresql \
  POSTGRES_DB="solidity_security" \
  POSTGRES_USER="postgres" \
  POSTGRES_PASSWORD="postgres"

vault kv put secret/redis \
  password="redis123"

# Service-specific secrets
vault kv put secret/local/api-service/jwt \
  secret_key="local-dev-jwt-secret-key-change-in-production"

vault kv put secret/local/api-service/session \
  secret="local-dev-session-secret-change-in-production"

echo "✅ Local Vault initialized with development secrets"
```

## Compliance Checklist

Before deploying any service with secrets:

- [ ] All secrets stored in Vault
- [ ] ExternalSecret resources created and committed to Git
- [ ] No hardcoded secrets in code or manifests
- [ ] `.env.example` documented with required secret keys (not values)
- [ ] SecretStore configured for environment
- [ ] ExternalSecret sync verified
- [ ] Pod restart tested after secret rotation
- [ ] Secret access audited in Vault logs

## Common Pitfalls

**❌ DO NOT:**
- Store secrets directly in Kubernetes Secret manifests in Git
- Commit `.env` files with actual values
- Share secrets via Slack, email, or other communication channels
- Use the same secrets across all environments (dev, staging, prod)
- Hardcode secrets in application code

**✅ DO:**
- Use ExternalSecret resources for all secrets
- Commit only `.env.example` templates
- Share secrets via Vault (with appropriate ACLs)
- Use environment-specific secrets
- Reference secrets via environment variables injected from Kubernetes Secrets

---

## Related Standards

- [Core Development Rules](./core-development-rules.md) - Codebase-first development workflow
- [Local Development Setup](./local-development-setup.md) - Local environment configuration
- [Compliance Checklist](./compliance-checklist.md) - Security compliance requirements
