# Playbook: GCP Secret Management

**Version:** 1.0.0
**Last Updated:** March 9, 2026
**Audience:** Platform Operator | Developer

## Overview

Manage secrets in GCP Secret Manager for the Apogee production platform. Secrets are synchronized to Kubernetes via the External Secrets Operator (ESO) using Workload Identity authentication.

---

## Prerequisites

- [ ] `gcloud` CLI authenticated with project access
- [ ] `kubectl` access to GKE cluster
- [ ] IAM role: `roles/secretmanager.secretVersionManager` (or higher)

---

## Reading Secrets

```bash
# List all Apogee secrets
gcloud secrets list --filter="name:apogee-gcp" --format='table(name,createTime)'

# Read a secret value
gcloud secrets versions access latest --secret=apogee-gcp-database-url
```

---

## Writing/Updating Secrets

```bash
# Create a new secret
echo -n "secret-value" | gcloud secrets create apogee-gcp-new-secret --data-file=-

# Update an existing secret (creates a new version)
echo -n "new-value" | gcloud secrets versions add apogee-gcp-database-url --data-file=-

# Force ESO to re-sync
kubectl annotate externalsecret <name> -n <namespace> \
  force-sync=$(date +%s) --overwrite
```

---

## Secret Naming Convention

All secrets use the prefix `apogee-gcp-`:

| Secret | Used By |
|--------|---------|
| `apogee-gcp-database-url` | api-service, data-service, orchestration, intelligence-engine, tool-integration |
| `apogee-gcp-redis-url` | All backend services |
| `apogee-gcp-jwt-secret` | api-service |
| `apogee-gcp-session-secret` | api-service |
| `apogee-gcp-integration-encryption-key` | api-service, tool-integration |
| `apogee-gcp-internal-service-token` | api-service, tool-integration |
| `apogee-gcp-supabase-key` | api-service |
| `apogee-gcp-stripe-api-key` | api-service |
| `apogee-gcp-anthropic-api-key` | intelligence-engine |

---

## Verifying Secret Sync

```bash
# Check ExternalSecret status across all namespaces
kubectl get externalsecret -A

# Check a specific secret was synced
kubectl get externalsecret -n api-service-prod api-service-secret -o jsonpath='{.status.conditions}'

# Verify the Kubernetes Secret was created
kubectl get secret api-service-secret -n api-service-prod
```

---

## Troubleshooting

### ExternalSecret shows SecretSyncedError

1. Check which key is failing:
   ```bash
   kubectl describe externalsecret -n <namespace> <name>
   ```

2. Verify the GCP secret exists:
   ```bash
   gcloud secrets describe apogee-gcp-<secret-name>
   ```

3. If the secret is missing, create it and wait for ESO to retry (default: 1h refresh interval).

### Workload Identity Issues

```bash
# Verify the K8s service account annotation
kubectl get sa external-secrets-sa -n external-secrets-prod -o yaml | grep iam.gke.io

# Test Workload Identity from the ESO pod
kubectl exec -n external-secrets-prod deployment/external-secrets -- \
  curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
```

---

## Related

- [Secrets Management Standards](../standards/secrets-management.md)
- [Vault Secret Management](vault-secret-management.md) (local development)
