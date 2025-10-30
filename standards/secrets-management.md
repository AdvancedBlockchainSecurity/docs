# Secrets Management

**Part of:** [Platform Development Standards](./INDEX.md)
**Version:** 1.8.0
**Last Updated:** October 20, 2025
**Status:** Active

## Overview

This document defines mandatory standards for managing secrets in the BlockSecOps Platform using HashiCorp Vault and the External Secrets Operator.

---

## Rule: Vault with External Secrets Operator

**MANDATORY:** All secrets MUST be stored in HashiCorp Vault and synchronized to Kubernetes using the External Secrets Operator (ESO).

**Why this matters:**
- **Security:** Centralized secret storage with encryption at rest and in transit
- **Auditability:** Complete audit trail of secret access and modifications
- **Rotation:** Automated secret rotation capabilities
- **Separation of Concerns:** Secrets managed separately from application code and Kubernetes manifests
- **Multi-Environment:** Single source of truth for secrets across all environments

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

```yaml
# ✅ CORRECT: ExternalSecret resource referencing Vault
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-credentials
  namespace: api-service-local
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: postgres-credentials
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: secret/data/api-service/postgres
        property: password
    - secretKey: username
      remoteRef:
        key: secret/data/api-service/postgres
        property: username
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
# 1. Store secret in Vault
vault kv put secret/api-service/new-api-key \
  api_key="your-secret-value"

# 2. Create ExternalSecret manifest
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/api-service
cat > externalsecret-new-api-key.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: new-api-key
  namespace: api-service-local
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: new-api-key
    creationPolicy: Owner
  data:
    - secretKey: api_key
      remoteRef:
        key: secret/data/api-service/new-api-key
        property: api_key
EOF

# 3. Commit the ExternalSecret manifest
git add externalsecret-new-api-key.yaml
git commit -m "Add ExternalSecret for new API key

- References Vault path: secret/api-service/new-api-key
- Auto-syncs every 1 hour
- Creates Kubernetes Secret: new-api-key

Refs: #789"

# 4. Apply the ExternalSecret
kubectl apply -f externalsecret-new-api-key.yaml

# 5. Verify secret was created
kubectl get secret new-api-key -n api-service-local
kubectl get externalsecret new-api-key -n api-service-local -o yaml
```

### Rotating a Secret

```bash
# 1. Update secret in Vault
vault kv put secret/api-service/database \
  password="new-rotated-password"

# 2. Wait for External Secrets Operator to sync (or force sync)
kubectl annotate externalsecret postgres-credentials \
  force-sync=$(date +%s) -n api-service-local

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
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/api-service
git rm externalsecret-compromised-key.yaml
git commit -m "SECURITY: Revoke compromised API key

Incident: [Brief description]
Date: $(date)
Action: Secret revoked and removed from all environments"
```

## Local Development Considerations

**For local development environments:**

1. **Use Vault dev mode** or a dedicated local Vault instance
2. **Never use production secrets** in local development
3. **Document local secret requirements** in `.env.example`
4. **Provide setup scripts** to initialize local Vault with development secrets

**Example local Vault setup:**

```bash
# scripts/setup-local-vault.sh
#!/bin/bash
# Initialize local Vault with development secrets

vault kv put secret/api-service/postgres \
  username="postgres" \
  password="local-dev-password"

vault kv put secret/api-service/redis \
  password="local-dev-redis-password"

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
