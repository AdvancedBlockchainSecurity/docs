# Playbook: Secret Rotation

**Version:** 1.0.0
**Last Updated:** February 25, 2026
**Audience:** Platform Operator
**Priority:** Medium (within 30 days of launch)

## Overview

Procedures for rotating secrets in production (GCP Secret Manager) and local development (HashiCorp Vault). All rotations follow the same pattern: create new secret, deploy, verify, retire old secret.

---

## Rotation Schedule

| Secret | Frequency | Downtime | Impact |
|--------|-----------|----------|--------|
| JWT secret | 90 days | Yes (invalidates all tokens) | All users must re-authenticate |
| Session secret | 90 days | Yes (invalidates all sessions) | All users must re-login |
| Database password | 180 days | Brief (connection pool reset) | Momentary 503s |
| Stripe API key | On compromise only | No | Seamless with Stripe key rolling |
| Encryption key | On compromise only | Complex | Requires data re-encryption |
| Internal service key | 90 days | Brief | Service-to-service auth reset |
| OAuth client secrets | On compromise only | No | Per-provider, no user impact |

---

## JWT Secret Rotation

**Impact:** All active JWT tokens become invalid. All users must re-authenticate.

### Local (Vault)

```bash
# 1. Generate new secret
NEW_SECRET=$(openssl rand -base64 48)

# 2. Update Vault
export VAULT_TOKEN=$(kubectl exec -n vault-local vault-0 -- \
  awk -F'"' '/root_token/{print $4}' /vault/data/.vault-init.json)

kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv put secret/local/api-service/jwt \
  secret_key="$NEW_SECRET"

# 3. Wait for ESO sync (15s refresh interval)
sleep 20

# 4. Restart API service to pick up new secret
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 5. Verify
curl -sk https://app.blocksecops.local/api/v1/health/ready
```

### GCP (Secret Manager)

```bash
PROJECT="blocksecops-prod"
NEW_SECRET=$(openssl rand -base64 48)

# 1. Add new version
echo -n "$NEW_SECRET" | gcloud secrets versions add jwt-secret \
  --project=$PROJECT --data-file=-

# 2. Verify new version
gcloud secrets versions list jwt-secret --project=$PROJECT --limit=2

# 3. Restart pods (ESO auto-syncs, but restart ensures immediate pickup)
kubectl rollout restart deployment/api-service -n api-service

# 4. Verify health
kubectl rollout status deployment/api-service -n api-service

# 5. Disable old version (after confirming new version works)
gcloud secrets versions disable OLD_VERSION_NUMBER \
  --secret=jwt-secret --project=$PROJECT
```

### User Communication

After JWT rotation, all existing tokens are invalid:
- Users see 401 errors on next API call
- Dashboard auto-redirects to login page
- API key users must re-authenticate (API keys are tied to user sessions)

---

## Session Secret Rotation

Same procedure as JWT rotation. Impacts:
- All active browser sessions invalidated
- Users must re-login
- No data loss

```bash
# Generate and update (same as JWT, different vault path)
NEW_SECRET=$(openssl rand -base64 48)

# Local:
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv put secret/local/api-service/session \
  secret="$NEW_SECRET"

# GCP:
echo -n "$NEW_SECRET" | gcloud secrets versions add session-secret \
  --project=$PROJECT --data-file=-
```

---

## Database Password Rotation

**Impact:** Brief connection errors during pool reset (~5-10 seconds).

### Local

```bash
NEW_PASSWORD=$(openssl rand -base64 32)

# 1. Update PostgreSQL password
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -c "ALTER USER blocksecops PASSWORD '${NEW_PASSWORD}';"

# 2. Update Vault
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv put secret/postgresql \
  POSTGRES_DB="solidity_security" \
  POSTGRES_USER="blocksecops" \
  POSTGRES_PASSWORD="$NEW_PASSWORD"

# 3. Wait for ESO sync
sleep 20

# 4. Restart all services that connect to PostgreSQL
for svc in api-service data-service intelligence-engine orchestration; do
  kubectl rollout restart deployment/$svc -n ${svc}-local
done

# 5. Verify database connectivity
curl -sk https://app.blocksecops.local/api/v1/health/ready | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('DB:', d['checks']['database'])"
```

### GCP (Cloud SQL)

```bash
# 1. Update Cloud SQL user password
gcloud sql users set-password blocksecops \
  --instance=blocksecops-db \
  --password="$NEW_PASSWORD"

# 2. Update Secret Manager
echo -n "postgresql+asyncpg://blocksecops:${NEW_PASSWORD}@/solidity_security?host=/cloudsql/project:region:instance" | \
  gcloud secrets versions add database-url --project=$PROJECT --data-file=-

# 3. Restart services
kubectl rollout restart deployment/api-service -n api-service
```

---

## Stripe API Key Rotation

**Impact:** None if using Stripe's key rolling feature.

```bash
# 1. Generate new key in Stripe Dashboard
# Dashboard → Developers → API Keys → Roll key

# 2. Stripe provides 24-hour overlap period
# Both old and new keys work during this window

# 3. Update secret
# Local:
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv put secret/local/api-service/stripe \
  api_key="sk_live_NEW_KEY" \
  webhook_secret="whsec_EXISTING"

# GCP:
echo -n "sk_live_NEW_KEY" | gcloud secrets versions add stripe-api-key \
  --project=$PROJECT --data-file=-

# 4. Restart API service
kubectl rollout restart deployment/api-service -n api-service-local

# 5. Test Stripe connectivity
curl -sk -H "Authorization: Bearer TOKEN" \
  https://app.blocksecops.local/api/v1/billing/plans

# 6. Expire old key in Stripe Dashboard after confirming new key works
```

---

## Encryption Key Rotation

**Impact:** Complex — requires data re-encryption for MFA secrets and OAuth tokens.

**WARNING:** Do not rotate the encryption key without a migration plan. Existing encrypted data (MFA TOTP secrets, OAuth refresh tokens) will become unreadable.

```bash
# 1. Generate new key
NEW_KEY=$(openssl rand -hex 32)

# 2. Create migration script that:
#    a. Reads all encrypted fields with old key
#    b. Decrypts with old key
#    c. Re-encrypts with new key
#    d. Updates database

# 3. Run migration in maintenance window

# 4. Update secret with new key
# 5. Restart services
# 6. Verify MFA and OAuth still work
```

---

## Emergency Rotation (Compromised Secret)

If a secret is believed compromised:

```bash
# 1. IMMEDIATELY rotate the secret (don't wait for scheduled rotation)
# Follow the relevant procedure above

# 2. Check audit logs for unauthorized access
kubectl logs -n api-service-local deploy/api-service --since=24h | \
  grep -i "unauthorized\|forbidden\|invalid token"

# 3. If JWT/session compromised: force all users to re-authenticate
# Rotating the JWT secret automatically invalidates all tokens

# 4. If database password compromised:
#    a. Rotate password immediately
#    b. Review pg_stat_activity for suspicious connections
#    c. Check audit_logs table for unauthorized data access

# 5. Document incident
# See: playbooks/incident-response.md
```

---

## Quick Reference: GCP Secret Manager Commands

```bash
# List all secrets
gcloud secrets list --project=$PROJECT

# View current version
gcloud secrets versions access latest --secret=SECRET_NAME --project=$PROJECT

# Add new version
echo -n "new_value" | gcloud secrets versions add SECRET_NAME \
  --project=$PROJECT --data-file=-

# Disable old version
gcloud secrets versions disable VERSION_NUM --secret=SECRET_NAME --project=$PROJECT

# Destroy old version (irreversible)
gcloud secrets versions destroy VERSION_NUM --secret=SECRET_NAME --project=$PROJECT
```

---

## Related

- [Vault Secret Management](vault-secret-management.md) — Local Vault operations
- [Secrets Management Standards](../standards/secrets-management.md)
- [Incident Response](incident-response.md)
